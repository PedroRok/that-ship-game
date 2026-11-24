class_name RunScreen
extends Control

const PAUSE_DIR : String = "res://assets/ui/pause/"
const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")
const PIXEL_FONT : Font = preload("res://assets/fonts/dogicapixel.ttf")
const SCREW_ICON : Texture2D = preload("res://assets/game/misc/screw.png")
const GEAR_ICON : Texture2D = preload("res://assets/game/misc/gear.png")

const TEXT : Color = Color("#eaf3f5")
const TEXT_SOFT : Color = Color("#a3bec8")
const TEXT_DIM : Color = Color("#7795a1")
const CYAN : Color = Color("#78dddd")
const AMBER : Color = Color("#ecc078")
const DANGER : Color = Color("#dfa0a2")
const FACE : Color = Color("#152027")
const WELL : Color = Color("#090f16")
const STEEL : Color = Color("#34454f")

const FRAME_ART : int = 6
const SILHOUETTE_SHADER : Shader = preload("res://shaders/silhouette.gdshader")
const SIDE_MARGIN : int = 32
const HEADER_TOP : int = 28
const HEADER_HEIGHT : int = 92

var run : RunState
var content : VBoxContainer

func expected_stage() -> int:
	return RunData.Stage.MAP

func requires_run() -> bool:
	return true

func screen_title() -> String:
	return ""

func screen_subtitle() -> String:
	return ""

func header_kicker() -> String:
	return "CAMPAIGN RUN"

func _build() -> void:
	pass

func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	set_anchors_preset(PRESET_TOP_LEFT)
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()
	run = Global.run
	if (requires_run() and (run == null or run.stage != expected_stage())):
		RunFlow.advance.call_deferred()
		return
	var ui_theme : Theme = Theme.new()
	ui_theme.default_font = PIXEL_FONT
	ui_theme.default_font_size = 8
	PixelControls.apply_theme(ui_theme)
	theme = ui_theme
	add_child(MenuBackground.new())
	var margin : MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", HEADER_TOP)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	content.add_child(_header(screen_title(), screen_subtitle()))
	_build()

func _fit_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size

func _label(text : String, size : int = 12, color : Color = TEXT, bold : bool = false) -> Label:
	var label : Label = Label.new()
	label.text = PixelText.fit(text, size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT if bold else PIXEL_FONT)
	label.add_theme_font_size_override("font_size", PixelText.snap(size))
	label.add_theme_color_override("font_color", color)
	return label

func _wrapped(text : String, size : int = 12, color : Color = TEXT) -> Label:
	var label : Label = _label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _box(file : String, margin : int, content_margin : int = -1) -> StyleBoxTexture:
	var box : StyleBoxTexture = StyleBoxTexture.new()
	box.texture = load(file) as Texture2D
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	if (content_margin >= 0):
		box.content_margin_left = content_margin
		box.content_margin_right = content_margin
		box.content_margin_top = content_margin
		box.content_margin_bottom = content_margin
	return box

func _pause_box(file : String, margin : int, content_margin : int = -1) -> StyleBoxTexture:
	return _box(PAUSE_DIR + file, margin, content_margin)

func _panel(content_margin : int = 12) -> PanelContainer:
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _pause_box("panel_frame_v01.png", 16, content_margin + FRAME_ART))
	return panel

func _margin_box(parent : Node, px : int) -> MarginContainer:
	var margin : MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side : String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, px)
	parent.add_child(margin)
	return margin

func _header(title : String, subtitle : String) -> Control:
	var plate : PanelContainer = PanelContainer.new()
	plate.custom_minimum_size = Vector2(0, HEADER_HEIGHT)
	plate.add_theme_stylebox_override("panel", _pause_box("header_plate_v01.png", 2, 0))
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	plate.add_child(row)
	var strip : ColorRect = ColorRect.new()
	strip.color = CYAN
	strip.custom_minimum_size = Vector2(4, 0)
	row.add_child(strip)
	var texts : VBoxContainer = VBoxContainer.new()
	texts.add_theme_constant_override("separation", 8)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin : MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_child(texts)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(margin)
	texts.add_child(_label(header_kicker(), 16, CYAN, true))
	texts.add_child(_label(title, 32, TEXT, true))
	var sub : Label = _label(subtitle, 16, TEXT_DIM)
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sub_margin : MarginContainer = MarginContainer.new()
	sub_margin.add_theme_constant_override("margin_right", 24)
	sub_margin.add_child(sub)
	row.add_child(sub_margin)
	return plate

func _plate(text : String, color : Color = TEXT_SOFT, size : int = 12, accent : Color = Color.TRANSPARENT) -> PanelContainer:
	var plate : PanelContainer = PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _pause_box("header_plate_v01.png", 2, 0))
	var row : HBoxContainer = HBoxContainer.new()
	plate.add_child(row)
	if (accent.a > 0.0):
		var strip : ColorRect = ColorRect.new()
		strip.color = accent
		strip.custom_minimum_size = Vector2(3, 0)
		row.add_child(strip)
	var margin : MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_label(text, size, color, true))
	row.add_child(margin)
	return plate

func _divider() -> TextureRect:
	var line : TextureRect = TextureRect.new()
	line.texture = load(PAUSE_DIR + "divider_v01.png") as Texture2D
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.custom_minimum_size.y = 2
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _icon(texture : Texture2D, size : Vector2 = Vector2.ZERO) -> TextureRect:
	var rect : TextureRect = TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if (size != Vector2.ZERO):
		rect.custom_minimum_size = size
	elif (texture):
		rect.custom_minimum_size = texture.get_size()
	return rect

func _tinted_icon(texture : Texture2D, color : Color, factor : int = 2) -> TextureRect:
	var rect : TextureRect = TextureRect.new()
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = Vector2(texture.get_size()) * factor
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material : ShaderMaterial = ShaderMaterial.new()
	material.shader = SILHOUETTE_SHADER
	material.set_shader_parameter("tint", color)
	rect.material = material
	return rect

func _screw_icon() -> TextureRect:
	return _tinted_icon(SCREW_ICON, AMBER, 2)

func _gear_icon() -> TextureRect:
	return _tinted_icon(GEAR_ICON, AMBER, 2)

func _button(text : String, danger : bool = false, font_size : int = 16) -> Button:
	var button : Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", PixelText.snap(font_size))
	var color : Color = DANGER if danger else TEXT
	for key : String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, color)
	button.add_theme_color_override("font_disabled_color", TEXT_DIM)
	var prefix : String = "button_danger_" if danger else "button_"
	var pressed : StyleBoxTexture = _pause_box(prefix + "pressed_v01.png", 4)
	button.add_theme_stylebox_override("normal", _pause_box(prefix + "normal_v01.png", 4))
	button.add_theme_stylebox_override("hover", _pause_box(prefix + "hover_v01.png", 4))
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", _pause_box("button_disabled_v01.png", 4))
	var focus : StyleBoxTexture = _pause_box("button_focus_v01.png", 4)
	focus.texture_margin_left = 9.0
	button.add_theme_stylebox_override("focus", focus)
	return button

func _segment_bar(value : float, maximum : float, segments : int, full : Texture2D, empty : Texture2D) -> HBoxContainer:
	var bar : HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var filled : int = 0
	if (maximum > 0.0 and value > 0.0):
		filled = clampi(int(ceil(value / maximum * segments)), 1, segments)
	for i : int in segments:
		bar.add_child(_icon(full if i < filled else empty))
	return bar

func _hp_bar(hp : int, max_hp : int, segments : int = 16) -> HBoxContainer:
	return _segment_bar(float(hp), float(max_hp), segments,
			load("res://assets/ui/hud/progress_full_v01.png") as Texture2D,
			load("res://assets/ui/hud/progress_empty_v01.png") as Texture2D)

func _reward_bar(bonus : float, maximum : float, segments : int = 14) -> HBoxContainer:
	return _segment_bar(bonus, maximum, segments,
			load("res://assets/ui/modifiers/reward_full_v01.png") as Texture2D,
			load("res://assets/ui/modifiers/reward_empty_v01.png") as Texture2D)

func _spacer() -> Control:
	var spacer : Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _footer(left : Button, right : Button) -> HBoxContainer:
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	if (left):
		row.add_child(left)
	row.add_child(_spacer())
	if (right):
		row.add_child(right)
	return row

func _stat_panel(title : String, value : String, note : String, value_color : Color, icon : Control = null) -> PanelContainer:
	var panel : PanelContainer = _panel(12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var plate : PanelContainer = _plate(title, TEXT_DIM, 12)
	box.add_child(plate)
	var row : HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 56
	if (icon):
		row.add_child(icon)
	row.add_child(_label(value, 24, value_color, true))
	box.add_child(row)
	box.add_child(_divider())
	var note_label : Label = _label(note, 10, TEXT_SOFT)
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note_label)
	return panel

func _defer_focus(control : Control) -> void:
	control.grab_focus.call_deferred()

func _advance() -> void:
	RunFlow.advance()
