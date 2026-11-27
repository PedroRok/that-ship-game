class_name BattleLog
extends RefCounted

const FILE_NAME : String = "battle_log.jsonl"

static func path() -> String:
	return SaveManager.directory + FILE_NAME

static func enabled() -> bool:
	return SaveManager.slot >= 1 and SaveManager.slot <= SaveManager.SLOT_COUNT

static func append(entry : Dictionary) -> void:
	if (!enabled()):
		return
	var file : FileAccess = null
	if (FileAccess.file_exists(path())):
		file = FileAccess.open(path(), FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(path(), FileAccess.WRITE)
	if (file == null):
		push_warning("Could not write battle log: %s" % error_string(FileAccess.get_open_error()))
		return
	file.seek_end()
	file.store_line(JSON.stringify(entry))
	file.close()
