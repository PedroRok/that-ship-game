extends Node

var failures : int = 0

func check(ok : bool, label : String) -> void:
	print("PASS  " if ok else "FAIL  ", label)
	if (!ok):
		failures += 1

func _ready() -> void:
	SaveManager.use_test_directory()
	Global.run = null
	Global.player_stats = Global.player_stats.duplicate()
	Global.player_stats.upgrade_levels = {}
	Global.player_stats.add_entity(Global.CATALOG.find_unit("mini"))
	Global.player_stats.add_entity(Global.CATALOG.find_unit("small"))
	var saved_loadout : Array[String] = Global.player_stats.loadout.duplicate()
	Global.player_stats.loadout = ["", "small", "", "", "mini"]
	var slots : Array[EntityStats] = Global.player_stats.loadout_slots(10)
	check(slots.size() == 10 and slots[0] == null and slots[1].name == "small" and slots[4].name == "mini" and slots[9] == null, "loadout slots keep the menu positions")
	var game : GameRound = (load("res://scenes/ui/naval_hud/naval_round.tscn") as PackedScene).instantiate() as GameRound
	add_child(game)
	await get_tree().create_timer(0.5, true, false, true).timeout
	var hud_roster : Array[EntityStats] = (game.get("hud") as Control).get("roster")
	check(hud_roster[0] == null and hud_roster[1] != null and hud_roster[1].name == "small", "battle HUD keeps the loadout positions")
	var ui : GameUI = game.get_node("CanvasLayer/GameUI") as GameUI
	var base : Base = game.ally_base
	var dock : BaseDock.Type = BaseDock.Type.NAVAL
	var mini : BoatStats = Global.CATALOG.find_unit("mini")
	ui.screw_label.change_value(1000 - ui.screw_label.total_value)
	check(base.queue_capacity(dock) == 3, "queue starts with 3 slots")
	for i : int in range(3):
		ui.spawn_entity(mini)
	var after_three : int = ui.screw_label.total_value
	check(after_three == 1000 - 3 * mini.price, "screws are charged when queued")
	ui.spawn_entity(mini)
	check(ui.screw_label.total_value == after_three, "full queue refuses the purchase and charges nothing")
	check(!base.queue_has_room(dock), "queue reports no room")
	await get_tree().process_frame
	await get_tree().process_frame
	var constructor : ShipConstructor = base.constructors[dock]
	check(constructor.is_building(), "first queued unit starts building")
	check((base.queues[dock] as Array).size() == 2, "two units keep waiting")
	var waiting : BoatStats = base.cancel_slot(dock, 1)
	check(waiting != null and (base.queues[dock] as Array).size() == 1, "waiting slot can be cancelled")
	ui.refund_entity(waiting)
	check(ui.screw_label.total_value == after_three + mini.price, "cancelled waiting unit is refunded")
	var building : BoatStats = base.cancel_slot(dock, 0)
	check(building != null, "unit under construction can be cancelled")
	check(!constructor.is_building() and constructor.texture == null, "cancelled construction stops and clears the dock")
	ui.refund_entity(building)
	await get_tree().process_frame
	await get_tree().process_frame
	check(constructor.is_building() and (base.queues[dock] as Array).is_empty(), "next queued unit starts after cancelling")
	check(base.cancel_slot(dock, 2) == null, "empty slot cancels nothing")
	var upgrade : UpgradeStats = null
	for item : Variant in Global.CATALOG.research:
		if ((item as UpgradeStats).stat == &"queue_naval"):
			upgrade = item
	check(upgrade != null, "research for naval queue exists")
	Global.player_stats.upgrade_levels[upgrade.id] = 2
	check(base.queue_capacity(dock) == 5, "research adds queue slots")
	Global.player_stats.upgrade_levels[upgrade.id] = 3
	check(base.queue_capacity(dock) == 5 and Global.player_stats.get_upgrade_level(upgrade) == 2, "queue never passes 5 slots")
	var plane : AirEntity = (load("res://scenes/entities/troops/air_entity.tscn") as PackedScene).instantiate() as AirEntity
	plane.entity_stats = Global.CATALOG.find_unit("interceptor")
	plane.team_stats = base.team_stats
	Global.player_stats.upgrade_levels = {}
	check(plane.flare_capacity() == 0, "aircraft start without flares")
	Global.player_stats.upgrade_levels = {&"r_flares": 4}
	check(plane.flare_capacity() == 4, "research gives up to 4 flares")
	plane.entity_stats = Global.CATALOG.find_unit("plane")
	check(plane.flare_capacity() == 0, "common plane never has flares")
	for bomber_name : String in ["bomber", "twin_bomber"]:
		plane.entity_stats = Global.CATALOG.find_unit(bomber_name)
		check(plane.flare_capacity() == 0, "%s never has flares" % bomber_name)
	plane.free()
	var elite : Dictionary = {"col": 3, "type": RunData.NodeType.ELITE}
	var boss : Dictionary = {"col": 4, "type": RunData.NodeType.BOSS}
	check(RunData.enemy_flares(elite) == 4 and RunData.enemy_flares(boss) == 3, "enemy flares grow with the column")
	Global.player_stats.upgrade_levels = {}
	var items : ItemManager = ui.get_parent().get_parent().find_child("ItemManager", true, false) as ItemManager
	if (items == null):
		items = game.find_child("ItemManager", true, false) as ItemManager
	check(items != null, "item manager found")
	if (items != null):
		Global.player_stats.loadout = ["destroyer"]
		Global.player_stats.add_entity(Global.CATALOG.find_unit("destroyer"))
		Global.player_stats.loadout = ["destroyer"]
		var destroyer : BoatStats = Global.CATALOG.find_unit("destroyer")
		for i : int in range(5):
			base.cancel_slot(dock, 1)
		base.cancel_slot(dock, 0)
		ui.screw_label.change_value(-ui.screw_label.total_value)
		check(items.kill_screw_amount(destroyer) == int(floor(destroyer.price / 3.0)), "no screws and empty queue: full kill reward")
		ui.screw_label.change_value(destroyer.price)
		check(items.kill_screw_amount(destroyer) == 0, "enough screws for the priciest unit: no kill reward")
		ui.screw_label.change_value(-ui.screw_label.total_value)
		var full : BoatStats = Global.CATALOG.find_unit("mini")
		for i : int in range(base.queue_capacity(dock)):
			base.queues[dock].append(full)
		check(items.kill_screw_amount(destroyer) == 0, "full queue: no kill reward")
		check(items.kill_screw_amount(Global.CATALOG.find_unit("mini")) == 0, "rounds down to zero")
	Global.player_stats.loadout = saved_loadout
	get_tree().quit(0 if failures == 0 else 1)
