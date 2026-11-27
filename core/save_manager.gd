class_name SaveManager
extends RefCounted

const LEGACY_SAVE_PATH : String = "user://save.json"
const LEGACY_RUN_PATH : String = "user://run.json"
const VERSION : int = 1
const SLOT_COUNT : int = 3
const TEST_DIRECTORY : String = "user://test_saves/"

static var slot : int = 1
static var directory : String = "user://"

static func use_test_directory() -> void:
	directory = TEST_DIRECTORY
	DirAccess.make_dir_recursive_absolute(directory)

static func save_path(index : int = slot) -> String:
	return directory + "save_%d.json" % index

static func run_path(index : int = slot) -> String:
	return directory + "run_%d.json" % index

static func migrate_legacy() -> void:
	if (FileAccess.file_exists(LEGACY_SAVE_PATH) and !FileAccess.file_exists(save_path(1))):
		DirAccess.rename_absolute(LEGACY_SAVE_PATH, save_path(1))
	if (FileAccess.file_exists(LEGACY_RUN_PATH) and !FileAccess.file_exists(run_path(1))):
		DirAccess.rename_absolute(LEGACY_RUN_PATH, run_path(1))

static func slot_exists(index : int) -> bool:
	return FileAccess.file_exists(save_path(index)) or FileAccess.file_exists(run_path(index))

static func slot_summary(index : int) -> Dictionary:
	var summary : Dictionary = {"exists": slot_exists(index), "gear": 0, "boss_coin": 0, "units": 0, "best_wave": 0, "run": null, "creative": false}
	if (FileAccess.file_exists(save_path(index))):
		var parsed : Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path(index)))
		if (typeof(parsed) == TYPE_DICTIONARY):
			var data : Dictionary = parsed
			summary["gear"] = int(data.get("gear", 0))
			summary["boss_coin"] = int(data.get("boss_coin", 0))
			summary["best_wave"] = int(data.get("best_wave", 0))
			summary["creative"] = bool(data.get("creative", false))
			summary["units"] = (data.get("unlocked_entities", []) as Array).size()
	if (FileAccess.file_exists(run_path(index))):
		var run_data : Variant = JSON.parse_string(FileAccess.get_file_as_string(run_path(index)))
		if (typeof(run_data) == TYPE_DICTIONARY):
			summary["run"] = RunState.from_dict(run_data)
	return summary

static func delete_slot(index : int) -> void:
	for path : String in [save_path(index), run_path(index)]:
		if (FileAccess.file_exists(path)):
			DirAccess.remove_absolute(path)

static func save(stats : PlayerStats) -> void:
	var names : Array[String] = []
	for entity : EntityStats in stats.unlocked_entities:
		names.append(entity.name)
	var data : Dictionary = {
		"version": VERSION,
		"gear": stats.gear,
		"boss_coin": stats.boss_coin,
		"best_wave": stats.best_wave,
		"campaigns_started": stats.campaigns_started,
		"creative": stats.creative,
		"upgrade_levels": stats.upgrade_levels,
		"unlocked_entities": names,
		"loadout": stats.loadout,
		"gun_choices": stats.gun_choices,
	}
	var file : FileAccess = FileAccess.open(save_path(), FileAccess.WRITE)
	if (!file):
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))

static func load_into(stats : PlayerStats, catalog : ShopCatalog) -> bool:
	if (!FileAccess.file_exists(save_path())):
		return false
	var parsed : Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if (typeof(parsed) != TYPE_DICTIONARY):
		push_warning("Save corrompido, ignorando.")
		return false
	var data : Dictionary = parsed
	stats.gear = int(data.get("gear", stats.gear))
	stats.boss_coin = int(data.get("boss_coin", 0))
	stats.best_wave = int(data.get("best_wave", 0))
	stats.campaigns_started = int(data.get("campaigns_started", 0))
	stats.creative = bool(data.get("creative", false))
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
	if (FileAccess.file_exists(save_path())):
		DirAccess.remove_absolute(save_path())

static func has_run() -> bool:
	return FileAccess.file_exists(run_path())

static func save_run(run : RunState) -> void:
	var file : FileAccess = FileAccess.open(run_path(), FileAccess.WRITE)
	if (!file):
		push_error("Could not write run save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(run.to_dict()))

static func load_run() -> RunState:
	if (!FileAccess.file_exists(run_path())):
		return null
	var parsed : Variant = JSON.parse_string(FileAccess.get_file_as_string(run_path()))
	if (typeof(parsed) != TYPE_DICTIONARY):
		push_warning("Run save corrupted, ignoring.")
		return null
	return RunState.from_dict(parsed)

static func delete_run() -> void:
	if (FileAccess.file_exists(run_path())):
		DirAccess.remove_absolute(run_path())
