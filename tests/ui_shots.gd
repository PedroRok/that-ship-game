extends Node

const OUT_DIR : String = "res://extras/art_preview/campaign_run_v01/ingame/"

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Global.player_stats = Global.player_stats.duplicate()
	for starter : String in ["mini", "small"]:
		if (!Global.player_stats.has_boat(starter)):
			Global.player_stats.add_entity(Global.CATALOG.find_unit(starter))
	await _shoot_all()
	get_tree().quit()

func _fresh_run() -> RunState:
	var run : RunState = RunState.create(7)
	Global.run = run
	return run

func _battle_node(run : RunState) -> int:
	for id : int in run.reachable_nodes():
		if (int(run.map.get_node(id)["type"]) == RunData.NodeType.BATTLE):
			return id
	return run.reachable_nodes()[0]

func _capture(menu : Global.Menu, file_name : String) -> void:
	var screen : Control = Global.menus[menu].instantiate() as Control
	add_child(screen)
	for i : int in 6:
		await get_tree().process_frame
	var image : Image = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	screen.queue_free()
	await get_tree().process_frame

func _shoot_all() -> void:
	var run : RunState = _fresh_run()
	run.relics = [&"shield", &"compass", &"hull"] as Array[StringName]
	run.base_hp = 74
	var node : int = _battle_node(run)
	run.set_focus(node)
	run.confirm_focus()
	run.start_battle()
	run.resolve_battle(true, 74, false, false)
	run.continue_after_node()
	run.relic_offer.clear()
	run.stage = RunData.Stage.MAP
	run.pending_node = -1
	var reachable : Array[int] = run.reachable_nodes()
	run.set_focus(reachable[reachable.size() - 1])
	await _capture(Global.Menu.RUN_MAP, "map.png")
	await _capture_map_selected(run, "map_selected_a.png", 0)
	await _capture_map_selected(run, "map_selected_b.png", reachable.size() - 1)
	await _capture(Global.Menu.CAMPAIGN_SELECT, "campaign_select.png")

	var brief : RunState = _fresh_run()
	var fight : int = _battle_node(brief)
	brief.set_focus(fight)
	brief.confirm_focus()
	brief.toggle_risk(&"stronger_enemies")
	brief.toggle_risk(&"less_time")
	await _capture(Global.Menu.RUN_BRIEFING, "briefing.png")
	Global.run = run
	run.stage = RunData.Stage.RELIC
	run.relic_offer = [&"shield", &"compass", &"cursed_item"] as Array[StringName]
	await _capture(Global.Menu.RUN_RELIC, "relic_choice.png")
	run.stage = RunData.Stage.NODE_DONE
	run.node_result = {"node": reachable[0], "success": true, "screws": 162, "damage": 8, "base_hp": 66,
		"relic_offered": true, "risk_bonus": 0.35}
	run.base_hp = 66
	await _capture(Global.Menu.RUN_NODE_DONE, "node_done.png")
	var event_id : int = -1
	var yard_id : int = -1
	for entry : Dictionary in run.map.nodes:
		if (int(entry["type"]) == RunData.NodeType.EVENT and event_id < 0):
			event_id = int(entry["id"])
		if (int(entry["type"]) == RunData.NodeType.SHIPYARD and yard_id < 0):
			yard_id = int(entry["id"])
	run.screws = 162
	run.pending_node = event_id
	run.stage = RunData.Stage.EVENT
	await _capture(Global.Menu.RUN_EVENT, "event.png")
	run.pending_node = yard_id
	run.stage = RunData.Stage.SHIPYARD
	await _capture(Global.Menu.RUN_SHIPYARD, "shipyard.png")
	run.stage = RunData.Stage.ENDED
	run.result = RunData.Result.WON
	run.end_reason = "The sector boss was defeated."
	run.end_summary = {"gears": 120, "boss_coins": 2, "floors": 4, "won": true}
	await _capture(Global.Menu.RUN_END, "run_won.png")
	run.result = RunData.Result.LOST
	run.end_reason = "The base was destroyed during the battle."
	run.end_summary = {"gears": 35, "boss_coins": 0, "floors": 3, "won": false}
	await _capture(Global.Menu.RUN_END, "run_lost.png")

func _capture_map_selected(run : RunState, file_name : String, index : int) -> void:
	var screen : RunMapScreen = Global.menus[Global.Menu.RUN_MAP].instantiate() as RunMapScreen
	add_child(screen)
	await get_tree().process_frame
	var ids : Array[int] = run.reachable_nodes()
	screen._on_node_activated(ids[index])
	for i : int in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	screen.queue_free()
	await get_tree().process_frame
