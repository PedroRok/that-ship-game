class_name Loc
extends RefCounted

const DIR : String = "res://assets/localization/"
const BASE_CODE : String = "en"

static var _languages : Array[Dictionary] = []
static var _installed : Translation = null

static func languages() -> Array[Dictionary]:
	if (_languages.is_empty()):
		_scan()
	return _languages

static func _scan() -> void:
	var codes : Array[String] = []
	for file : String in ResourceLoader.list_directory(DIR):
		var clean : String = file.trim_suffix(".remap").trim_suffix(".import")
		if (clean.ends_with(".json") and !codes.has(clean.get_basename())):
			codes.append(clean.get_basename())
	codes.sort()
	if (codes.has(BASE_CODE)):
		codes.erase(BASE_CODE)
		codes.push_front(BASE_CODE)
	for code : String in codes:
		var data : Dictionary = _read(code)
		_languages.append({"code": code, "name": str(data.get("name", code)), "entries": data.get("entries", {})})

static func _read(code : String) -> Dictionary:
	var resource : JSON = load(DIR + code + ".json") as JSON
	if (resource == null or !(resource.data is Dictionary)):
		return {}
	return resource.data

static func setup() -> void:
	apply(GameSettings.language)

static func apply(code : String) -> void:
	if (_installed != null):
		TranslationServer.remove_translation(_installed)
	var list : Array[Dictionary] = languages()
	var entry : Dictionary = list[language_index(code)]
	var translation : Translation = Translation.new()
	translation.locale = str(entry["code"])
	for source : Dictionary in list:
		if (source["code"] == BASE_CODE):
			_fill(translation, source["entries"])
	_fill(translation, entry["entries"])
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(translation.locale)
	_installed = translation

static func _fill(translation : Translation, entries : Dictionary) -> void:
	for key : String in entries:
		translation.add_message(key, str(entries[key]))

static func set_language(code : String) -> void:
	GameSettings.language = code
	apply(code)

static func language_index(code : String) -> int:
	var list : Array[Dictionary] = languages()
	for index : int in list.size():
		if (list[index]["code"] == code):
			return index
	return 0

static func t(key : String) -> String:
	return TranslationServer.translate(key)

static func has_key(key : String) -> bool:
	return TranslationServer.translate(key) != key

static func named(prefix : String, id : String) -> String:
	var key : String = prefix + "." + id
	return t(key) if has_key(key) else id
