class_name PixelText
extends RefCounted

const DESCRIPTION_FONT_PATH : String = "res://assets/fonts/pixel_operator_8.ttf"
const DIGIT_FONT_PATH : String = "res://assets/fonts/dogicapixel.ttf"

static var _description_font : FontFile = null

static func describe(control : Control) -> void:
	if (_description_font == null):
		_description_font = load(DESCRIPTION_FONT_PATH) as FontFile
		_description_font.fallbacks = [load(DIGIT_FONT_PATH) as Font] as Array[Font]
	control.add_theme_font_override("font", _description_font)

static func snap(size : int) -> int:
	return maxi(1, roundi((size - 1) / 8.0)) * 8

static func fit(text : String, size : int) -> String:
	var shown : String = Loc.t(text)
	return shown.to_upper() if snap(size) <= 8 else shown
