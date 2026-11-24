extends Node

var failures : int = 0

func check(ok : bool, label : String) -> void:
	print("PASS  " if ok else "FAIL  ", label)
	if (!ok):
		failures += 1

func _ready() -> void:
	Global.run = null
	Global.player_stats = Global.player_stats.duplicate()
	Global.player_stats.upgrade_levels = {}
	Global.player_stats.add_entity(Global.CATALOG.find_unit("small"))
	Global.player_stats.loadout = ["small", "skill_bomb", "skill_boost"]
	check(Global.player_stats.loadout_entities().size() == 1, "skills are not spawnable units")
	var slots : Array[EntityStats] = Global.player_stats.loadout_slots(10)
	check(slots[1] is SkillStats and slots[2] is SkillStats, "loadout slots resolve skills")
	Global.player_stats.sanitize_loadout()
	check(Global.player_stats.loadout.has("skill_bomb"), "sanitize keeps skills")
	var shop : ShopMenu = ShopMenu.new()
	add_child(shop)
	await get_tree().process_frame
	shop._set_filter("shop.skills")
	check(shop.grid.get_child_count() == 2, "skills filter lists the two skills")
	shop._toggle_loadout(SkillCatalog.find("skill_bomb"))
	check(!Global.player_stats.in_loadout("skill_bomb"), "shop card toggles a skill out of the loadout")
	shop._toggle_loadout(SkillCatalog.find("skill_bomb"))
	check(Global.player_stats.in_loadout("skill_bomb"), "shop card toggles a skill into the loadout")
	check(shop._unit_drag_data("skill_boost", 2, shop.grid.get_child(1) as Control) != null, "skill slots can be dragged")
	shop.queue_free()
	var game : GameRound = (load("res://scenes/ui/naval_hud/naval_round.tscn") as PackedScene).instantiate() as GameRound
	add_child(game)
	await get_tree().create_timer(0.5, true, false, true).timeout
	var hud : Control = game.get("hud") as Control
	var manager : SkillManager = game.skill_manager
	var ui : GameUI = game.get_node("CanvasLayer/GameUI") as GameUI
	ui.screw_label.change_value(1000 - ui.screw_label.total_value)
	hud.call("quick_build", 2)
	check(manager.cooldown_left(&"boost") > 0.0, "boost skill activates immediately")
	check(ui.screw_label.total_value == 1000 - SkillManager.BOOST_COST, "boost charges its cost")
	hud.call("quick_build", 1)
	check(manager.is_targeting(&"bomb"), "bomb skill enters targeting")
	check(ui.screw_label.total_value == 1000 - SkillManager.BOOST_COST, "targeting charges nothing")
	hud.call("quick_build", 1)
	check(!manager.is_targeting(), "selecting the bomb again cancels the aim")
	hud.call("quick_build", 1)
	manager._drop_bombs(game.ally_base.global_position)
	check(manager.cooldown_left(&"bomb") > 0.0 and !manager.is_targeting(), "dropping the bomb starts the cooldown")
	print("---- ", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit()
