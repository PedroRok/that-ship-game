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

func _ready() -> void:
	ally_base.show_docks_for(Global.player_stats.loadout_entities())
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

	wave_manager.start()

func _unhandled_input(event : InputEvent) -> void:
	if (event.is_action_pressed("game_pause") and !get_tree().paused):
		get_viewport().set_input_as_handled()
		var pause : PauseMenu = PauseMenu.new()
		pause.name = "PauseMenu"
		get_tree().root.add_child(pause)

func _on_wave_started(number : int, wave : WaveData) -> void:
	var text : String = "Wave %d/%d" % [number, wave_manager.waves_per_run]
	if (number > wave_manager.waves_per_run):
		text = "Wave %d" % number
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
	var raw_screws : int = $CanvasLayer/GameUI.screw_label.total_value
	var leftover_screws : int = int(raw_screws * Global.modify(Enums.UpgradeTarget.BASE, &"leftover_gear_mult", 1.0))
	var waves_reached : int = max(wave_manager.current_wave_number() - 1, 0)
	var wave_gears : int = int(waves_reached * Global.modify(Enums.UpgradeTarget.BASE, &"gears_per_wave", GEARS_PER_WAVE))
	var bonus : int = VICTORY_BONUS if victory else 0

	var win_screen : Node = WIN_SCREEN.instantiate()
	win_screen.title = "VICTORY" if victory else "DEFEAT"
	win_screen.rows = [
		{"label": "Leftover Screws", "value": leftover_screws},
		{"label": "Waves Reached (%d)" % waves_reached, "value": wave_gears},
		{"label": "Gears Collected", "value": gears_collected_in_round},
		{"label": "Victory Bonus", "value": bonus},
		{"label": "Boss Coins", "value": boss_coins_in_round},
	]
	win_screen.total = leftover_screws + wave_gears + bonus + gears_collected_in_round
	Global.player_stats.gear += leftover_screws + wave_gears + bonus
	Global.player_stats.best_wave = max(Global.player_stats.best_wave, waves_reached)
	Global.save_game()
	canvas_layer.call_deferred("add_child", win_screen)
