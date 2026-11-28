class_name GameRound
extends Node2D

var player_stats : PlayerStats

var gears_collected_in_round : int = 0

@export
var camera : GameCam

@export
var ally_base : Base

@export
var enemy_base : Base

const WIN_SCREEN = preload("res://scenes/ui/game/win_screen/win_screen.tscn")
const WAVE_TABLE = preload("res://core/resources/waves/wave_table.tres")

@onready
var canvas_layer : CanvasLayer = $CanvasLayer

var game_ended : bool = false
var wave_manager : WaveManager
var skill_manager : SkillManager
var wave_label : Label
var endless : EndlessDirector
var _warning_label : Label
var campaign : CampaignBattle

var base_distance : float = RunData.CLASSIC_DISTANCE
const WATER_SPRING_GAP : float = 30.0
const WATER_MARGIN : float = 400.0

func _enter_tree() -> void:
	var run : RunState = Global.run
	var weather : int = RunData.Weather.CLEAR
	if (run != null and run.stage == RunData.Stage.BATTLE and run.pending_node >= 0):
		base_distance = run.battle_distance(run.pending_node)
		weather = run.battle_weather()
	else:
		base_distance = RunData.CLASSIC_DISTANCE
	var ally : Node2D = get_node("Base") as Node2D
	var enemy : Node2D = get_node("EnemyBase") as Node2D
	enemy.position.x = ally.position.x + base_distance
	var cam : Camera2D = get_node("GameCam") as Camera2D
	cam.limit_left = int(ally.position.x)
	cam.limit_right = int(enemy.position.x)
	var water : WaterBody = get_node("Environment/Water_Body") as WaterBody
	water.spring_number = int(ceil((base_distance + WATER_MARGIN) / WATER_SPRING_GAP))
	WeatherSky.apply(self, weather)
	if (weather == RunData.Weather.STORM):
		var storm : LightningStorm = LightningStorm.new()
		storm.name = "LightningStorm"
		get_node("Environment").add_child(storm)
	var front : ColorRect = get_node("Environment/CloudsFront") as ColorRect
	front.size.x = base_distance + 1.0
	(front.material as ShaderMaterial).set_shader_parameter("rect_size", Vector2(front.size.x, front.size.y))

func _ready() -> void:
	var audio : BattleAudio = BattleAudio.new()
	audio.name = "BattleAudio"
	audio.camera = camera
	add_child(audio)
	add_child(DebugOverlay.new())
	var legacy_ui : Control = $CanvasLayer/GameUI as Control
	legacy_ui.hide()
	legacy_ui.process_mode = Node.PROCESS_MODE_INHERIT
	if (get_script() == preload("res://scenes/game/scripts/game.gd")):
		push_warning("game.tscn was opened directly and has no HUD. Use naval_round.tscn (Global.Menu.GAME).")
	ally_base.show_docks_for(Global.player_stats.loadout_entities())
	var run : RunState = Global.run
	var campaign_mode : bool = run != null and run.stage == RunData.Stage.BATTLE
	if (!campaign_mode):
		ally_base.death_event.connect(base_death_event)
		enemy_base.death_event.connect(base_death_event)
		$ShipsManager.gear_drops = false

		wave_manager = WaveManager.new()
		wave_manager.table = WAVE_TABLE
		wave_manager.enemy_base = enemy_base as AutoBase
		add_child(wave_manager)
		wave_manager.wave_started.connect(_on_wave_started)

		wave_label = Label.new()
		wave_label.position = Vector2(560, 12)
		wave_label.add_theme_font_override("font", load("res://assets/fonts/dogicabold.ttf"))
		canvas_layer.add_child(wave_label)

	skill_manager = SkillManager.new()
	skill_manager.game_ui = $CanvasLayer/GameUI
	skill_manager.ally_base = ally_base
	skill_manager.enemy_base = enemy_base
	skill_manager.ships_manager = $ShipsManager as ShipManager
	skill_manager.camera = camera
	add_child(skill_manager)

	if (campaign_mode):
		campaign = CampaignBattle.new()
		campaign.setup(self, run)
	else:
		endless = EndlessDirector.new()
		endless.name = "EndlessDirector"
		endless.setup(self, randi())
		endless.unit_unlocked.connect(_on_unit_unlocked)
		add_child(endless)
		wave_manager.wave_started.connect(func(_number : int, wave : WaveData) -> void: endless.on_wave(wave))
		wave_manager.start()

func _unhandled_input(event : InputEvent) -> void:
	if (event.is_action_pressed("game_pause") and !get_tree().paused and !game_ended):
		get_viewport().set_input_as_handled()
		var pause : PauseMenu = PauseMenu.new()
		pause.name = "PauseMenu"
		get_tree().root.add_child(pause)

func _on_wave_started(number : int, wave : WaveData) -> void:
	if (wave_label == null):
		return
	var text : String = Loc.t("battle.wave") % [number, wave_manager.waves_per_run]
	if (number > wave_manager.waves_per_run):
		text = Loc.t("battle.wave_2") % number
	if (wave.boss):
		text += "  - BOSS"
	wave_label.text = text

func _on_unit_unlocked(unit : BoatStats) -> void:
	if (_warning_label == null):
		_warning_label = Label.new()
		_warning_label.name = "ThreatWarning"
		_warning_label.add_theme_font_override("font", load("res://assets/fonts/dogicabold.ttf") as Font)
		_warning_label.add_theme_font_size_override("font_size", 16)
		_warning_label.add_theme_color_override("font_color", Color("#ffb4a8"))
		_warning_label.add_theme_color_override("font_outline_color", Color("#090f15"))
		_warning_label.add_theme_constant_override("outline_size", 8)
		_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_warning_label.position = Vector2(240, 150)
		_warning_label.size = Vector2(800, 24)
		canvas_layer.add_child(_warning_label)
	_warning_label.text = (Loc.t("battle.enemy_new_unit") % Loc.named("unit", unit.name)).to_upper()
	_warning_label.modulate.a = 1.0
	var tween : Tween = _warning_label.create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_warning_label, "modulate:a", 0.0, 0.5)

func base_death_event(team_stats: TeamStats) -> void:
	if (game_ended):
		return
	game_ended = true
	wave_manager.stop()
	skill_manager.stop()
	var victory : bool = team_stats.team_id != 1
	if (!victory):
		BattleAudio.play_ui(self, &"result_defeat")
	var waves_reached : int = max(wave_manager.current_wave_number() - 1, 0)
	var win_screen : Node = WIN_SCREEN.instantiate()
	win_screen.title = "battle.victory" if victory else "battle.defeat"
	win_screen.rewards = false
	win_screen.rows = [
		{"label": "battle.waves_survived", "value": waves_reached},
		{"label": "battle.threat_level", "value": endless.level},
	]
	Global.player_stats.best_wave = max(Global.player_stats.best_wave, waves_reached)
	Global.save_game()
	canvas_layer.call_deferred("add_child", win_screen)
