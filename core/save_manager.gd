class_name SaveManager
extends RefCounted

const SAVE_PATH : String = "user://save.json"
const VERSION : int = 1

static func save(stats : PlayerStats) -> void:
	var names : Array[String] = []
	for entity : EntityStats in stats.unlocked_entities:
		names.append(entity.name)
	var data : Dictionary = {
		"version": VERSION,
		"gear": stats.gear,
		"boss_coin": stats.boss_coin,
		"best_wave": stats.best_wave,
		"upgrade_levels": stats.upgrade_levels,
		"unlocked_entities": names,
		"loadout": stats.loadout,
		"gun_choices": stats.gun_choices,
	}
	var file : FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if (!file):
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))

static func load_into(stats : PlayerStats, catalog : ShopCatalog) -> bool:
	if (!FileAccess.file_exists(SAVE_PATH)):
		return false
	var parsed : Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if (typeof(parsed) != TYPE_DICTIONARY):
		push_warning("Save corrompido, ignorando.")
		return false
	var data : Dictionary = parsed
	stats.gear = int(data.get("gear", stats.gear))
	stats.boss_coin = int(data.get("boss_coin", 0))
	stats.best_wave = int(data.get("best_wave", 0))
	stats.upgrade_levels = {}
	var levels : Dictionary = data.get("upgrade_levels", {})
	for key : Variant in levels:
		stats.upgrade_levels[StringName(key)] = int(levels[key])
	stats.unlocked_entities = []
	for unit_name : Variant in data.get("unlocked_entities", []):
		var unit : BoatStats = catalog.find_unit(str(unit_name))
		if (unit):
			stats.unlocked_entities.append(unit)
	stats.loadout = []
	for unit_name : Variant in data.get("loadout", []):
		stats.loadout.append(str(unit_name))
	stats.gun_choices = {}
	var choices : Dictionary = data.get("gun_choices", {})
	for unit_name : Variant in choices:
		var picks : Array = []
		for pick : Variant in choices[unit_name]:
			picks.append(int(pick))
		stats.gun_choices[str(unit_name)] = picks
	stats.sanitize_loadout()
	return true

static func delete_save() -> void:
	if (FileAccess.file_exists(SAVE_PATH)):
		DirAccess.remove_absolute(SAVE_PATH)
