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

func slot_limit() -> int:
	return MAX_LOADOUT

func in_loadout(unit_name : String) -> bool:
	return unit_name != "" and loadout.has(unit_name)

func loadout_count() -> int:
	var count : int = 0
	for unit_name : String in loadout:
		if (unit_name != ""):
			count += 1
	return count

func _trim_loadout() -> void:
	while (!loadout.is_empty() and loadout[loadout.size() - 1] == ""):
		loadout.pop_back()

func _pad_loadout() -> void:
	while (loadout.size() < slot_limit()):
		loadout.append("")

func toggle_loadout(unit_name : String) -> bool:
	if (in_loadout(unit_name)):
		loadout[loadout.find(unit_name)] = ""
		_trim_loadout()
		return true
	if (loadout_count() >= slot_limit() or !has_boat(unit_name)):
		return false
	_pad_loadout()
	loadout[loadout.find("")] = unit_name
	_trim_loadout()
	return true

func place_in_loadout(unit_name : String, index : int, limit : int) -> bool:
	if (!has_boat(unit_name) or index < 0 or index >= limit):
		return false
	_pad_loadout()
	var existing : int = loadout.find(unit_name)
	var other : String = loadout[index]
	if (existing >= 0):
		loadout[existing] = other
	loadout[index] = unit_name
	_trim_loadout()
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
		if (unit_name == ""):
			continue
		for stats : EntityStats in unlocked_entities:
			if (stats.name == unit_name):
				result.append(stats)
				break
	return result

func loadout_slots(count : int) -> Array[EntityStats]:
	var result : Array[EntityStats] = []
	for index : int in range(count):
		var unit_name : String = loadout[index] if index < loadout.size() else ""
		result.append(find_entry(unit_name))
	return result

func find_entry(unit_name : String) -> EntityStats:
	if (unit_name == ""):
		return null
	var skill : SkillStats = SkillCatalog.find(unit_name)
	if (skill):
		return skill
	for stats : EntityStats in unlocked_entities:
		if (stats.name == unit_name):
			return stats
	return null

func sanitize_loadout() -> void:
	var clean : Array[String] = []
	for unit_name : String in loadout:
		if (clean.size() >= slot_limit()):
			break
		if (unit_name == "" or (has_boat(unit_name) and !clean.has(unit_name))):
			clean.append(unit_name)
		else:
			clean.append("")
	loadout = clean
	if (loadout_count() == 0):
		loadout = []
		for stats : EntityStats in unlocked_entities:
			if (loadout.size() < slot_limit()):
				loadout.append(stats.name)
	_trim_loadout()

func has_boat(boat_name : String) -> bool:
	if (SkillCatalog.find(boat_name)):
		return true
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
	if (loadout_count() < slot_limit() and !loadout.has(entity.name)):
		toggle_loadout(entity.name)

func buy(gear_needed : int, boat : BoatStats) -> bool:
	if (has_boat(boat.name)):
		return false
	if (!can_buy(gear_needed)):
		return false
	add_entity(boat)
	gear -= gear_needed
	return true
