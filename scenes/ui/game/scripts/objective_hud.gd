class_name ObjectiveHud
extends PanelContainer

const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")
const PIXEL_FONT : Font = preload("res://assets/fonts/dogicapixel.ttf")
const SEGMENTS : int = 20

var icon : TextureRect
var title_label : Label
var detail_label : Label
var debug_label : Label
var time_label : Label
var bar : HBoxContainer
var full : Texture2D
var empty : Texture2D
var _last_filled : int = -1

func setup(objective : int) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style : StyleBoxTexture = StyleBoxTexture.new()
	style.texture = load("res://assets/ui/pause/panel_frame_v01.png") as Texture2D
	for side : String in ["left", "right", "top", "bottom"]:
		style.set("texture_margin_" + side, 16)
		style.set("content_margin_" + side, 12)
	add_theme_stylebox_override("panel", style)
	full = load("res://assets/ui/hud/progress_full_v01.png") as Texture2D
	empty = load("res://assets/ui/hud/progress_empty_v01.png") as Texture2D
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var head : HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	icon = TextureRect.new()
	icon.texture = RunData.objective_hud_icon(objective)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	title_label = _label("", FONT, 16, Color("#eaf3f5"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	time_label = _label("", FONT, 12, Color("#ecc078"))
	head.add_child(time_label)
	box.add_child(head)
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	for i : int in SEGMENTS:
		var segment : TextureRect = TextureRect.new()
		segment.texture = empty
		segment.stretch_mode = TextureRect.STRETCH_KEEP
		bar.add_child(segment)
	detail_label = _label("", PIXEL_FONT, 10, Color("#a3bec8"))
	box.add_child(detail_label)
	if (OS.is_debug_build()):
		debug_label = _label("", PIXEL_FONT, 8, Color("#7795a1"))
		box.add_child(debug_label)

func _label(text : String, font : Font, size : int, color : Color) -> Label:
	var label : Label = Label.new()
	label.text = PixelText.fit(text, size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", PixelText.snap(size))
	label.add_theme_color_override("font_color", color)
	return label

func set_debug_text(text : String) -> void:
	if (debug_label):
		debug_label.text = PixelText.fit(text, 8)

func update_state(headline : String, fraction : float, detail : String, time_left : float, warn : bool = false) -> void:
	title_label.text = headline
	title_label.add_theme_color_override("font_color", Color("#ecc078") if warn else Color("#eaf3f5"))
	detail_label.text = PixelText.fit(detail, 8)
	time_label.text = "" if time_left < 0.0 else "%d:%02d" % [int(time_left) / 60, int(time_left) % 60]
	var filled : int = clampi(int(round(fraction * SEGMENTS)), 0, SEGMENTS)
	if (filled == _last_filled):
		return
	_last_filled = filled
	for i : int in SEGMENTS:
		(bar.get_child(i) as TextureRect).texture = full if i < filled else empty
