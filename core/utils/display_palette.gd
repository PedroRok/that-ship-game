class_name DisplayPalette
extends RefCounted

var rest : Color
var shadow : Color
var unloaded : Color
var light : Color
var text : Color
var base : Color
var line : Color
var overlay_dark : Color

static var _cache : Dictionary = {}

static func of_dock(kind : BaseDock.Type) -> DisplayPalette:
	if (!_cache.has(kind)):
		_cache[kind] = _make(kind)
	return _cache[kind]

static func of_unit(unit : EntityStats) -> DisplayPalette:
	if (unit == null):
		return of_dock(BaseDock.Type.NAVAL)
	if (unit is SkillStats):
		return of_skill()
	return of_dock(Base.dock_type_of(unit))

static func of_skill() -> DisplayPalette:
	if (!_cache.has(&"skill")):
		var palette : DisplayPalette = DisplayPalette.new()
		palette.rest = Color("#c58ae8")
		palette.shadow = Color("#240a2d")
		palette.unloaded = Color("#43225a")
		palette.light = Color("#ecc4ff")
		palette.text = Color("#c9a6dd")
		palette.base = Color(0.06, 0.02, 0.085, 1.0)
		palette.line = Color(0.65, 0.40, 0.88, 1.0)
		palette.overlay_dark = Color("#13041a")
		_cache[&"skill"] = palette
	return _cache[&"skill"]

static func of_threat() -> DisplayPalette:
	if (!_cache.has(&"threat")):
		var palette : DisplayPalette = DisplayPalette.new()
		palette.rest = Color("#eb6862")
		palette.shadow = Color("#2d0a0a")
		palette.unloaded = Color("#4c1b1b")
		palette.light = Color("#ffc4c0")
		palette.text = Color("#e5a9a6")
		palette.base = Color(0.085, 0.018, 0.015, 1.0)
		palette.line = Color(0.92, 0.41, 0.38, 1.0)
		palette.overlay_dark = Color("#140404")
		_cache[&"threat"] = palette
	return _cache[&"threat"]

static func _make(kind : BaseDock.Type) -> DisplayPalette:
	var palette : DisplayPalette = DisplayPalette.new()
	match kind:
		BaseDock.Type.AIR:
			palette.rest = Color("#e6c24d")
			palette.shadow = Color("#2d260a")
			palette.unloaded = Color("#4c421b")
			palette.light = Color("#fff3b8")
			palette.text = Color("#d5c79a")
			palette.base = Color(0.085, 0.075, 0.015, 1.0)
			palette.line = Color(0.86, 0.74, 0.30, 1.0)
			palette.overlay_dark = Color("#131104")
		BaseDock.Type.SUB:
			palette.rest = Color("#6fdc7a")
			palette.shadow = Color("#0a2d12")
			palette.unloaded = Color("#1b4c25")
			palette.light = Color("#c4ffc9")
			palette.text = Color("#9ad5a1")
			palette.base = Color(0.015, 0.085, 0.03, 1.0)
			palette.line = Color(0.35, 0.86, 0.42, 1.0)
			palette.overlay_dark = Color("#04140a")
		_:
			palette.rest = Color("#5fd9cf")
			palette.shadow = Color("#0a2b2d")
			palette.unloaded = Color("#1b4c4b")
			palette.light = Color("#b8fff6")
			palette.text = Color("#9ad5ce")
			palette.base = Color(0.015, 0.075, 0.085, 1.0)
			palette.line = Color(0.30, 0.86, 0.82, 1.0)
			palette.overlay_dark = Color("#04131a")
	return palette

func apply_screen(material : ShaderMaterial) -> void:
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("line_color", line)

func apply_overlay(material : ShaderMaterial) -> void:
	material.set_shader_parameter("dark_color", overlay_dark)
	material.set_shader_parameter("line_color", rest)
