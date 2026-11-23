extends Node

var center_camera_pos : Vector2

var test_enemy_all_units : bool = true
var test_grant_gears : bool = true

var test_unlock_all_weapons : bool = true

func _ready() -> void:
	GameSettings.load_settings()
	GameSettings.apply(get_window(), true)

func open_options() -> void:
	if (get_tree().root.has_node("OptionsMenu")):
		return
	var menu : OptionsMenu = OptionsMenu.new()
	menu.name = "OptionsMenu"
	get_tree().root.add_child(menu)

var camera_zoom : float

signal change_to_scene(name : Menu)

var player_stats : PlayerStats = preload("res://core/resources/player/player_stats.tres")

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
	return value

func upgraded_entity(stats : EntityStats) -> EntityStats:
	var copy : EntityStats = stats.duplicate()
	copy.health = modify(Enums.UpgradeTarget.ENTITY, &"health", stats.health, stats.name)
	copy.speed = modify(Enums.UpgradeTarget.ENTITY, &"speed", stats.speed, stats.name)
	copy.radar_distance = int(modify(Enums.UpgradeTarget.ENTITY, &"radar_distance", stats.radar_distance, stats.name))
	return copy

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
	SaveManager.save(player_stats)

enum Menu {
	SHOP,
	SELECT,
	GAME,
	RESEARCH
}

const menus : Dictionary = {
	Menu.SHOP : preload("res://scenes/ui/shop/shop_menu.tscn"),
	Menu.SELECT : preload("res://scenes/ui/rounds/rounds_menu.tscn"),
	Menu.GAME : preload("res://scenes/game/game.tscn"),
	Menu.RESEARCH : preload("res://scenes/ui/research/research_menu.tscn")
}

func change_scene(name : Menu) -> void:
	change_to_scene.emit(name)

func gun_type_for(unit_name : String, slot_index : int, slot : GunSlot) -> int:
	return player_stats.gun_for_slot(unit_name, slot_index, slot, CATALOG)
