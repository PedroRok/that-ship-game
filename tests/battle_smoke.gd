extends Node

const OUT_DIR : String = "res://extras/art_preview/campaign_run_v01/ingame/"
const TIME_SCALE : float = 8.0
const MAX_GAME_SECONDS : float = 300.0

var auto_player : bool = false
var _auto_clock : float = 0.0

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	Global.player_stats = Global.player_stats.duplicate()
	for starter : String in ["mini", "small"]:
		if (!Global.player_stats.has_boat(starter)):
			Global.player_stats.add_entity(Global.CATALOG.find_unit(starter))
	if ("auto" in OS.get_cmdline_user_args()):
		auto_player = true
		for unit : Variant in Global.CATALOG.units:
			var stats : BoatStats = unit
			if (!Global.player_stats.has_boat(stats.name)):
				Global.player_stats.add_entity(stats)
	var wanted : Array[int] = []
	for arg : String in OS.get_cmdline_user_args():
		if (arg.is_valid_int()):
			wanted.append(int(arg))
	if (wanted.is_empty()):
		wanted = [0, 1, 2, 3, 4, 5]
	for objective : int in wanted:
		await _play(objective)
	Engine.time_scale = 1.0
	get_tree().quit()

func _play(objective : int) -> void:
	var run : RunState = RunState.create(100 + objective)
	Global.run = run
	var node_id : int = 0
	if (objective == RunData.Objective.DEFEAT_BOSS):
		node_id = RunData.BOSS_ID
	var entry : Dictionary = run.map.get_node(node_id)
	entry["objective"] = objective
	entry["type"] = RunData.NodeType.BOSS if objective == RunData.Objective.DEFEAT_BOSS else RunData.NodeType.BATTLE
	entry["weather"] = RunData.Weather.STORM if objective == RunData.Objective.DEFEND else RunData.Weather.FOG
	run.pending_node = node_id
	run.focus_node = node_id
	run.stage = RunData.Stage.BRIEFING
	run.toggle_risk(&"stronger_enemies")
	run.start_battle()
	var game : Node = load("res://scenes/ui/naval_hud/naval_round.tscn").instantiate()
	add_child(game)
	Engine.time_scale = TIME_SCALE
	var started : float = Time.get_ticks_msec() / 1000.0
	var shot : bool = false
	var last_log : float = 0.0
	while (run.stage == RunData.Stage.BATTLE and (Time.get_ticks_msec() / 1000.0 - started) * TIME_SCALE < MAX_GAME_SECONDS):
		await get_tree().create_timer(0.5, true, false, true).timeout
		if (auto_player):
			_auto_play(game as GameRound)
		var game_time : float = (Time.get_ticks_msec() / 1000.0 - started) * TIME_SCALE
		if (!shot and game_time > 12.0):
			shot = true
			_screenshot("battle_%s.png" % RunData.OBJECTIVES[objective]["icon"])
		if (game_time - last_log > 40.0):
			last_log = game_time
			var campaign : CampaignBattle = (game as GameRound).campaign
			print("  [obj %d] t=%ds %s" % [objective, int(game_time), campaign.hud.title_label.text if campaign else "?"])
	Engine.time_scale = 1.0
	print("OBJECTIVE %d (%s): stage=%d result=%s base_hp=%d screws=%d" % [objective, RunData.OBJECTIVES[objective]["name"],
			run.stage, str(run.node_result.get("success", "-")), run.base_hp, run.screws])
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _auto_play(game : GameRound) -> void:
	var ui : GameUI = game.get_node("CanvasLayer/GameUI") as GameUI
	if (ui == null):
		return
	ui.screw_label.change_value(60)
	var loadout : Array[EntityStats] = Global.player_stats.loadout_entities()
	if (loadout.is_empty()):
		return
	ui.spawn_entity(loadout.pick_random())

func _screenshot(file_name : String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
