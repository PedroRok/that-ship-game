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

const GEARS_PER_WAVE : int = 2
const VICTORY_BONUS : int = 10

@onready
var canvas_layer : CanvasLayer = $CanvasLayer

var game_ended : bool = false
var wave_manager : WaveManager
var skill_manager : SkillManager
var wave_label : Label
var boss_coins_in_round : int = 0
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
	var front : ColorRect = get_node("Environment/CloudsFront") as ColorRect
	front.size.x = base_distance + 1.0
	(front.material as ShaderMaterial).set_shader_parameter("rect_size", Vector2(front.size.x, front.size.y))

func _ready() -> void:
	var audio : BattleAudio = BattleAudio.new()
	audio.name = "BattleAudio"
	audio.camera = camera
	add_child(audio)
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
		$ShipsManager.boss_defeated.connect(_on_boss_defeated)

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
	add_child(skill_manager)

	if (campaign_mode):
		campaign = CampaignBattle.new()
		campaign.setup(self, run)
	else:
		wave_manager.start()

func _unhandled_input(event : InputEvent) -> void:
	if (event.is_action_pressed("game_pause") and !get_tree().paused):
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

func _on_boss_defeated(boss_stats : EntityStats) -> void:
	boss_coins_in_round += boss_stats.boss_coin_reward
	Global.player_stats.boss_coin += boss_stats.boss_coin_reward

func base_death_event(team_stats: TeamStats) -> void:
	if (game_ended):
		return
	game_ended = true
	wave_manager.stop()
	skill_manager.stop()
	var victory : bool = team_stats.team_id != 1
	var waves_reached : int = max(wave_manager.current_wave_number() - 1, 0)
	var wave_gears : int = int(waves_reached * Global.modify(Enums.UpgradeTarget.BASE, &"gears_per_wave", GEARS_PER_WAVE))
	var bonus : int = VICTORY_BONUS if victory else 0

	var win_screen : Node = WIN_SCREEN.instantiate()
	win_screen.title = "battle.victory" if victory else "battle.defeat"
	win_screen.rows = [
		{"label": Loc.t("battle.waves_reached") % waves_reached, "value": wave_gears},
		{"label": "battle.gears_collected", "value": gears_collected_in_round},
		{"label": "battle.victory_bonus", "value": bonus},
		{"label": "battle.boss_coins", "value": boss_coins_in_round},
	]
	win_screen.total = wave_gears + bonus + gears_collected_in_round
	Global.player_stats.gear += wave_gears + bonus
	Global.player_stats.best_wave = max(Global.player_stats.best_wave, waves_reached)
	Global.save_game()
	canvas_layer.call_deferred("add_child", win_screen)
