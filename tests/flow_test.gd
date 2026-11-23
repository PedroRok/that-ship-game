extends Node
var failures : int = 0
var manager : Node

func check(ok : bool, message : String) -> void:
	print("PASS  " if ok else "FAIL  ", message)
	if (!ok):
		failures += 1

func frames(count : int = 6) -> void:
	for i : int in count:
		await get_tree().process_frame

func current_screen() -> Node:
	return manager.menu_scene

func _ready() -> void:
	SaveManager.delete_run()
	manager = (load("res://scenes/ui/rounds_scene_manager/rounds_scene_manager.tscn") as PackedScene).instantiate()
	add_child(manager)
	await frames()
	check(current_screen() is CampaignSelectScreen, "the game opens on the campaign screen, before the troop menu")
	(current_screen() as CampaignSelectScreen)._on_new()
	await frames(10)
	check(current_screen() is ShopMenu and Global.start_mode == Global.StartMode.CAMPAIGN, "picking a mode opens the troop menu")
	(current_screen() as ShopMenu)._on_start_pressed()
	await frames()
	check(current_screen() is RunMapScreen, "troop menu START -> run map")
	var map_screen : RunMapScreen = current_screen() as RunMapScreen
	var run : RunState = Global.run
	var target : int = run.reachable_nodes()[0]
	for id : int in run.reachable_nodes():
		if (int(run.map.get_node(id)["type"]) == RunData.NodeType.BATTLE):
			target = id
	check(Global.run.focus_node == -1, "map opens with nothing selected")
	(map_screen.chart.buttons[target] as MapNodeButton).mouse_entered.emit()
	await frames(2)
	check(Global.run.focus_node == -1, "hovering a node does not select it")
	map_screen._on_node_activated(target)
	check(Global.run.focus_node == target and !map_screen.confirm_button.disabled, "clicking selects and enables ENTER NODE")
	map_screen._on_confirm()
	await frames()
	check(current_screen() is BriefingScreen, "confirming a battle node -> briefing")
	var briefing : BriefingScreen = current_screen() as BriefingScreen
	briefing._on_risk_toggled(&"fragile_base")
	check(Global.run.risks.size() == 1 and Global.run.risks[0] == &"fragile_base", "risk equipped in the briefing")
	briefing._on_start()
	await frames(20)
	check(current_screen() is GameRound, "start battle -> real naval battle scene")
	var game : GameRound = current_screen() as GameRound
	check(game.campaign != null and game.wave_manager == null, "battle runs under the campaign controller")
	check(is_equal_approx(game.ally_base.health_component.health, float(run.base_hp)), "base starts with the run's HP")
	game.campaign._finish(true)
	game.campaign._finish(false)
	check(run.stage == RunData.Stage.NODE_DONE and bool(run.node_result["success"]), "result is recorded once (second finish ignored)")
	await get_tree().create_timer(2.4).timeout
	await frames()
	check(current_screen() is NodeDoneScreen, "after the banner -> node-complete screen")
	var screws : int = run.screws
	(current_screen() as NodeDoneScreen)._on_continue()
	await frames()
	if (current_screen() is RelicChoiceScreen):
		var relic_screen : RelicChoiceScreen = current_screen() as RelicChoiceScreen
		relic_screen._on_confirm()
		check(relic_screen.selected == &"" and run.stage == RunData.Stage.RELIC, "confirm needs a selection")
		relic_screen._on_card_pressed(run.relic_offer[0])
		relic_screen._on_confirm()
		await frames()
		check(run.relics.size() == 1, "relic chosen")
	check(current_screen() is RunMapScreen and run.screws == screws, "back to the map, nothing paid twice")
	Global.run = null
	check(RunFlow.has_saved_run(), "run was persisted")
	RunFlow.continue_run()
	await frames()
	check(current_screen() is RunMapScreen and Global.run.history.size() == 1, "continue run restores the route")
	RunFlow.abandon()
	await frames()
	check(Global.run == null and !SaveManager.has_run(), "abandon clears the run")
	print("---- ", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)
