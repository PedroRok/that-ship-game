class_name PixelControls
extends RefCounted

const CHECK_ICON : Texture2D = preload("res://assets/ui/icons/check_ok_v01.png")
const CHECK_DIM_ICON : Texture2D = preload("res://assets/ui/icons/check_ok_dim_v01.png")

const WELL : Color = Color("#090f16")
const FACE : Color = Color("#152027")
const STEEL : Color = Color("#34454f")
const EDGE : Color = Color("#4f6773")
const CYAN : Color = Color("#78dddd")
const BAR_WIDTH : int = 10

static func _box(fill : Color, border : Color, width : int = 1) -> StyleBoxFlat:
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.anti_aliasing = false
	return style

static func _grabber(fill : Color, border : Color) -> StyleBoxFlat:
	var style : StyleBoxFlat = _box(fill, border)
	style.content_margin_left = BAR_WIDTH / 2.0
	style.content_margin_right = BAR_WIDTH / 2.0
	style.content_margin_top = BAR_WIDTH / 2.0
	style.content_margin_bottom = BAR_WIDTH / 2.0
	return style

static func _check_texture(border : Color, fill : Color, mark : Texture2D) -> Texture2D:
	var image : Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x : int in range(1, 15):
		for y : int in range(1, 15):
			var edge : bool = x == 1 or y == 1 or x == 14 or y == 14
			image.set_pixel(x, y, border if edge else fill)
	if (mark):
		var source : Image = mark.get_image()
		source.convert(Image.FORMAT_RGBA8)
		image.blend_rect(source, Rect2i(0, 0, 16, 16), Vector2i.ZERO)
	return ImageTexture.create_from_image(image)

static func apply_theme(theme : Theme) -> void:
	for bar : String in ["VScrollBar", "HScrollBar"]:
		var track : StyleBoxFlat = _box(WELL, STEEL)
		track.content_margin_left = BAR_WIDTH / 2.0
		track.content_margin_right = BAR_WIDTH / 2.0
		track.content_margin_top = BAR_WIDTH / 2.0
		track.content_margin_bottom = BAR_WIDTH / 2.0
		theme.set_stylebox("scroll", bar, track)
		theme.set_stylebox("scroll_focus", bar, track)
		theme.set_stylebox("grabber", bar, _grabber(FACE, EDGE))
		theme.set_stylebox("grabber_highlight", bar, _grabber(STEEL, CYAN))
		theme.set_stylebox("grabber_pressed", bar, _grabber(CYAN.darkened(0.45), CYAN))
	var checked : Texture2D = _check_texture(CYAN, WELL, CHECK_ICON)
	var unchecked : Texture2D = _check_texture(STEEL, WELL, null)
	var checked_dim : Texture2D = _check_texture(STEEL, WELL, CHECK_DIM_ICON)
	for type : String in ["CheckBox", "CheckButton"]:
		theme.set_icon("checked", type, checked)
		theme.set_icon("unchecked", type, unchecked)
		theme.set_icon("checked_disabled", type, checked_dim)
		theme.set_icon("unchecked_disabled", type, unchecked)
		theme.set_icon("checked_mirrored", type, checked)
		theme.set_icon("unchecked_mirrored", type, unchecked)
		theme.set_icon("checked_disabled_mirrored", type, checked_dim)
		theme.set_icon("unchecked_disabled_mirrored", type, unchecked)
		theme.set_constant("h_separation", type, 12)
		var focus : StyleBoxFlat = _box(Color.TRANSPARENT, CYAN)
		focus.draw_center = false
		theme.set_stylebox("focus", type, focus)
	theme.set_constant("check_v_offset", "CheckBox", 0)
	for kind : String in ["checked", "radio_checked"]:
		theme.set_icon(kind, "PopupMenu", checked)
		theme.set_icon(kind + "_disabled", "PopupMenu", checked_dim)
	for kind : String in ["unchecked", "radio_unchecked"]:
		theme.set_icon(kind, "PopupMenu", unchecked)
		theme.set_icon(kind + "_disabled", "PopupMenu", unchecked)

static func themed(base : Theme = null) -> Theme:
	var result : Theme = base if base else Theme.new()
	apply_theme(result)
	return result
