class_name ObjectiveHud
extends PanelContainer

const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")
const PIXEL_FONT : Font = preload("res://assets/fonts/dogicapixel.ttf")
const SEGMENTS : int = 20
const PAIR_HEIGHT : float = 3.0
const PAIR_GAP : int = 2
const RIVAL_COLOR : Color = Color("#dfa0a2")

var icon : TextureRect
var title_label : Label
var detail_label : Label
var debug_label : Label
var floor_label : Label
var bar : HBoxContainer
var rival_bar : HBoxContainer
var full : Texture2D
var empty : Texture2D
var objective_id : int = 0
var progress : float = 0.0
var rival : float = 0.0
var rival_full : Texture2D
var warning : bool = false
var time_left_seconds : float = -1.0
var countdown : float = -1.0
var counter : String = ""
var _last_filled : int = -1

func setup(objective : int) -> void:
	objective_id = objective
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
	floor_label = _label("", FONT, 8, Color("#ecc078"))
	head.add_child(floor_label)
	box.add_child(head)
	var bars : VBoxContainer = VBoxContainer.new()
	bars.add_theme_constant_override("separation", PAIR_GAP)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_child(bar)
	box.add_child(bars)
	for i : int in SEGMENTS:
		var segment : TextureRect = TextureRect.new()
		segment.texture = empty
		segment.stretch_mode = TextureRect.STRETCH_KEEP
		if (has_rival()):
			_squash(segment)
		bar.add_child(segment)
	if (has_rival()):
		rival_full = _tinted(full, RIVAL_COLOR)
		rival_bar = HBoxContainer.new()
		rival_bar.add_theme_constant_override("separation", 0)
		rival_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bars.add_child(rival_bar)
		for i : int in SEGMENTS:
			var segment : TextureRect = TextureRect.new()
			segment.texture = empty
			_squash(segment)
			rival_bar.add_child(segment)
	detail_label = _label("", PIXEL_FONT, 10, Color("#a3bec8"))
	box.add_child(detail_label)
	if (OS.is_debug_build()):
		debug_label = _label("", PIXEL_FONT, 8, Color("#7795a1"))
		box.add_child(debug_label)

func has_rival() -> bool:
	return objective_id == RunData.Objective.DEFEND

func _squash(segment : TextureRect) -> void:
	segment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	segment.stretch_mode = TextureRect.STRETCH_SCALE
	segment.custom_minimum_size = Vector2(empty.get_width(), PAIR_HEIGHT)

func _tinted(source : Texture2D, color : Color) -> Texture2D:
	var image : Image = source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y : int in image.get_height():
		for x : int in image.get_width():
			var pixel : Color = image.get_pixel(x, y)
			image.set_pixel(x, y, Color(color.r * pixel.v, color.g * pixel.v, color.b * pixel.v, pixel.a))
	return ImageTexture.create_from_image(image)

func set_rival(fraction : float) -> void:
	rival = clampf(fraction, 0.0, 1.0)
	if (!rival_bar):
		return
	var filled : int = roundi(rival * SEGMENTS)
	for i : int in SEGMENTS:
		(rival_bar.get_child(i) as TextureRect).texture = rival_full if i < filled else empty

func _label(text : String, font : Font, size : int, color : Color) -> Label:
	var label : Label = Label.new()
	label.text = PixelText.fit(text, size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", PixelText.snap(size))
	label.add_theme_color_override("font_color", color)
	return label

func set_floor(number : int) -> void:
	floor_label.text = (Loc.t("hud.floor") % number).to_upper()

func set_debug_text(text : String) -> void:
	if (debug_label):
		debug_label.text = PixelText.fit(text, 8)

func update_state(headline : String, fraction : float, detail : String, time_left : float, warn : bool = false) -> void:
	progress = clampf(fraction, 0.0, 1.0)
	warning = warn
	time_left_seconds = time_left
	title_label.text = headline
	title_label.add_theme_color_override("font_color", Color("#ecc078") if warn else Color("#eaf3f5"))
	detail_label.text = PixelText.fit(detail, 8)
	var filled : int = clampi(int(round(fraction * SEGMENTS)), 0, SEGMENTS)
	if (filled == _last_filled):
		return
	_last_filled = filled
	for i : int in SEGMENTS:
		(bar.get_child(i) as TextureRect).texture = full if i < filled else empty
