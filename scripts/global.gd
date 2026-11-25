extends Node

var center_camera_pos : Vector2

var test_enemy_all_units : bool = true
var dev_mode : bool = false
var test_grant_gears : bool = false

var test_unlock_all_weapons : bool:
	get:
		return dev_mode

var stats_template : PlayerStats

func _ready() -> void:
	GameSettings.load_settings()
	Loc.setup()
	GameSettings.apply(get_window())

func load_slot(index : int) -> void:
	SaveManager.slot = index
	player_stats = stats_template.duplicate()
	SaveManager.load_into(player_stats, CATALOG)
	for starter : String in ["mini", "small"]:
		if (!player_stats.has_boat(starter)):
			player_stats.add_entity(CATALOG.find_unit(starter))
	if (dev_mode):
		player_stats.gear = maxi(player_stats.gear, 99999)
		for item : Variant in CATALOG.units:
			var unit : EntityStats = item
			if (!player_stats.has_boat(unit.name)):
				player_stats.add_entity(unit)

func open_options() -> void:
	if (get_tree().root.has_node("OptionsMenu")):
		return
	var menu : OptionsMenu = OptionsMenu.new()
	menu.name = "OptionsMenu"
	get_tree().root.add_child(menu)

var camera_zoom : float

signal change_to_scene(name : Menu)

var player_stats : PlayerStats = preload("res://core/resources/player/player_stats.tres")

enum StartMode { NONE, CAMPAIGN, CLASSIC }
var start_mode : StartMode = StartMode.NONE
var start_new_campaign : bool = true

var run : RunState

const CATALOG : ShopCatalog = preload("res://core/resources/shop_catalog.tres")

func modify(target : Enums.UpgradeTarget, stat : StringName, base_value : float, entity_name : String = "") -> float:
	var value : float = base_value
	for item : Variant in CATALOG.all_upgrades():
		var upgrade : UpgradeStats = item
		if (upgrade.target != target or upgrade.stat != stat):
			continue
		if (target == Enums.UpgradeTarget.ENTITY and !upgrade.affects(entity_name)):
			continue
		value = upgrade.apply(value, player_stats.get_upgrade_level(upgrade))
	if (run and run.stage == RunData.Stage.BATTLE):
		value = run.modify(target, stat, value, entity_name)
	return value

func upgraded_entity(stats : EntityStats) -> EntityStats:
	var copy : EntityStats = stats.duplicate()
	copy.health = modify(Enums.UpgradeTarget.ENTITY, &"health", stats.health, stats.name)
	copy.speed = modify(Enums.UpgradeTarget.ENTITY, &"speed", stats.speed, stats.name)
	copy.radar_distance = int(modify(Enums.UpgradeTarget.ENTITY, &"radar_distance", stats.radar_distance, stats.name))
	return copy

func screw_cost(stats : EntityStats) -> int:
	if (stats == null):
		return 0
	var total : int = stats.price
	if (stats is SkillStats):
		return total
	for slot_index : int in range(stats.gun_slots.size()):
		var slot : GunSlot = stats.gun_slots[slot_index]
		total += Enums.gun_extra_cost(gun_type_for(stats.name, slot_index, slot))
	return maxi(total, 0)

const COUNTERS : Dictionary = {
	Vector2i(1, 0): 1.5,
	Vector2i(0, 1): 0.75,
	Vector2i(2, 1): 1.5,
	Vector2i(1, 2): 0.5,
	Vector2i(0, 2): 0.75,
	Vector2i(2, 0): 0.75,
	Vector2i(3, 2): 2.0,
	Vector2i(3, 1): 0.75,
	Vector2i(3, 0): 0.75,
	Vector2i(4, 1): 1.5,
	Vector2i(4, 0): 1.25,
	Vector2i(1, 4): 1.25,
}

func counter_multiplier(attacker : Enums.UnitClass, target : Enums.UnitClass) -> float:
	return COUNTERS.get(Vector2i(attacker, target), 1.0)

func save_game() -> void:
	if (dev_mode):
		return
	SaveManager.save(player_stats)

enum Menu {
	SHOP,
	SELECT,
	GAME,
	RESEARCH,
	RUN_MAP,
	RUN_BRIEFING,
	RUN_NODE_DONE,
	RUN_RELIC,
	RUN_EVENT,
	RUN_SHIPYARD,
	RUN_END,
	CAMPAIGN_SELECT,
	MAIN_MENU
}

const menus : Dictionary = {
	Menu.SHOP : preload("res://scenes/ui/shop/shop_menu.tscn"),
	Menu.SELECT : preload("res://scenes/ui/rounds/rounds_menu.tscn"),
	Menu.GAME : preload("res://scenes/ui/naval_hud/naval_round.tscn"),
	Menu.RESEARCH : preload("res://scenes/ui/research/research_menu.tscn"),
	Menu.RUN_MAP : preload("res://scenes/ui/run/run_map_screen.tscn"),
	Menu.RUN_BRIEFING : preload("res://scenes/ui/run/briefing_screen.tscn"),
	Menu.RUN_NODE_DONE : preload("res://scenes/ui/run/node_done_screen.tscn"),
	Menu.RUN_RELIC : preload("res://scenes/ui/run/relic_choice_screen.tscn"),
	Menu.RUN_EVENT : preload("res://scenes/ui/run/event_screen.tscn"),
	Menu.RUN_SHIPYARD : preload("res://scenes/ui/run/shipyard_screen.tscn"),
	Menu.RUN_END : preload("res://scenes/ui/run/run_end_screen.tscn"),
	Menu.CAMPAIGN_SELECT : preload("res://scenes/ui/run/campaign_select_screen.tscn"),
	Menu.MAIN_MENU : preload("res://scenes/ui/run/main_menu.tscn")
}

func change_scene(name : Menu) -> void:
	change_to_scene.emit(name)

func gun_type_for(unit_name : String, slot_index : int, slot : GunSlot) -> int:
	return player_stats.gun_for_slot(unit_name, slot_index, slot, CATALOG)
