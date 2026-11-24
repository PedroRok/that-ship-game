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
	return of_dock(Base.dock_type_of(unit))

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
