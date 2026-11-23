class_name PlayerStats
extends Resource

@export
var start_screw : int = 10
@export
var gear : int = 10

var best_wave : int = 0

var round_num : int = 0

var round_group_num : int = 0

@export
var boss_coin : int = 0

var upgrade_levels : Dictionary = {}

@export
var unlocked_entities : Array[EntityStats]

@export
var gun_upgrades: Array[GunStats]

const MAX_LOADOUT : int = 9
var loadout : Array[String] = []

func in_loadout(unit_name : String) -> bool:
	return loadout.has(unit_name)

func toggle_loadout(unit_name : String) -> bool:
	if (loadout.has(unit_name)):
		loadout.erase(unit_name)
		return true
	if (loadout.size() >= MAX_LOADOUT or !has_boat(unit_name)):
		return false
	loadout.append(unit_name)
	return true

var gun_choices : Dictionary = {}

func is_gun_unlocked(unit_name : String, gun_type : int, catalog : ShopCatalog) -> bool:
	if (Global.test_unlock_all_weapons):
		return true
	for item : Variant in catalog.research:
		var upgrade : UpgradeStats = item
		if (upgrade.target == Enums.UpgradeTarget.WEAPON_UNLOCK and upgrade.unlocks_gun == gun_type 				and upgrade.affects(unit_name) and get_upgrade_level(upgrade) > 0):
			return true
	return false

func gun_options(unit_name : String, slot : GunSlot, catalog : ShopCatalog) -> Array[int]:
	var result : Array[int] = []
	var default_type : int = slot.default_gun_type()
	for gun_type : int in slot.allowed_types:
		if (slot.accepts(gun_type) and (gun_type == default_type or is_gun_unlocked(unit_name, gun_type, catalog))):
			result.append(gun_type)
	return result

func gun_for_slot(unit_name : String, slot_index : int, slot : GunSlot, catalog : ShopCatalog) -> int:
	var picks : Array = gun_choices.get(unit_name, [])
	if (slot_index < picks.size()):
		var picked : int = int(picks[slot_index])
		if (picked >= 0 and gun_options(unit_name, slot, catalog).has(picked)):
			return picked
	return slot.default_gun_type()

func set_gun_choice(unit_name : String, slot_index : int, gun_type : int) -> void:
	var picks : Array = gun_choices.get(unit_name, [])
	while (picks.size() <= slot_index):
		picks.append(-1)
	picks[slot_index] = gun_type
	gun_choices[unit_name] = picks

func loadout_entities() -> Array[EntityStats]:
	var result : Array[EntityStats] = []
	for unit_name : String in loadout:
		for stats : EntityStats in unlocked_entities:
			if (stats.name == unit_name):
				result.append(stats)
				break
	return result

func sanitize_loadout() -> void:
	var clean : Array[String] = []
	for unit_name : String in loadout:
		if (has_boat(unit_name) and !clean.has(unit_name) and clean.size() < MAX_LOADOUT):
			clean.append(unit_name)
	if (clean.is_empty()):
		for stats : EntityStats in unlocked_entities:
			if (clean.size() < MAX_LOADOUT):
				clean.append(stats.name)
	loadout = clean

func has_boat(boat_name : String) -> bool:
	for stats : EntityStats in unlocked_entities:
		if (boat_name == stats.name):
			return true
	return false
	
func can_buy(gears_needed : int) -> bool:
	if (gear >= gears_needed):
		return true
	return false

func get_upgrade_level(upgrade : UpgradeStats) -> int:
	return upgrade_levels.get(upgrade.id, 0)

func can_buy_upgrade(upgrade : UpgradeStats) -> bool:
	var level : int = get_upgrade_level(upgrade)
	if (level >= upgrade.max_level):
		return false
	for req : UpgradeStats in upgrade.requires:
		if (get_upgrade_level(req) < 1):
			return false
	return gear >= upgrade.gears_for_level(level + 1) \
			and boss_coin >= upgrade.boss_coins_for_level(level + 1)

func buy_upgrade(upgrade : UpgradeStats) -> bool:
	if (!can_buy_upgrade(upgrade)):
		return false
	var next_level : int = get_upgrade_level(upgrade) + 1
	gear -= upgrade.gears_for_level(next_level)
	boss_coin -= upgrade.boss_coins_for_level(next_level)
	upgrade_levels[upgrade.id] = next_level
	return true

func add_entity(entity : EntityStats) -> void:
	unlocked_entities.append(entity)
	if (loadout.size() < MAX_LOADOUT and !loadout.has(entity.name)):
		loadout.append(entity.name)

func buy(gear_needed : int, boat : BoatStats) -> bool:
	if (has_boat(boat.name)):
		return false
	if (!can_buy(gear_needed)):
		return false
	add_entity(boat)
	gear -= gear_needed
	return true
