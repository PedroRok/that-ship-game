class_name PauseMenu
extends CanvasLayer

const TEX_DIR := "res://assets/ui/pause/"
const FONT := preload("res://assets/fonts/dogicabold.ttf")
const PIXEL_FONT := preload("res://assets/fonts/dogicapixel.ttf")
const BATTLE_TOP := 38.0
const HUD_BOTTOM := 200.0
const PANEL_SIZE := Vector2(320, 216)
const TEXT_COLOR := Color(0.92, 0.96, 0.97)
const DANGER_COLOR := Color(1.0, 0.72, 0.72)
const DISABLED_COLOR := Color(0.55, 0.6, 0.62)

enum Page { PAUSED, ABANDON, OPTIONS }

var page: Page = Page.PAUSED
var pause_page: Control
var abandon_page: Control
var resume_button: Button
var options_button: Button
var cancel_button: Button
var test_label: Label
var _options: OptionsMenu

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build()
	_show_page(Page.PAUSED)

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var stage := Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.offset_top = BATTLE_TOP
	stage.offset_bottom = -HUD_BOTTOM
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", _box("panel_frame_v01.png", 16))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	panel.add_child(margin)
	var pages := Control.new()
	margin.add_child(pages)

	pause_page = _build_pause_page()
	abandon_page = _build_abandon_page()
	for p: Control in [pause_page, abandon_page]:
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		pages.add_child(p)

	if OS.is_debug_build():
		test_label = Label.new()
		test_label.add_theme_font_override("font", PIXEL_FONT)
		test_label.add_theme_font_size_override("font_size", 8)
		test_label.modulate = Color(1, 1, 1, 0.45)
		test_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		test_label.offset_left = 8.0
		test_label.offset_top = -HUD_BOTTOM - 14.0
		test_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(test_label)
		_refresh_test_label()

func _build_pause_page() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_header("PAUSED", "icon_pause_v01.png"))
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	box.add_child(gap)
	resume_button = _button("RESUME", false)
	resume_button.pressed.connect(resume)
	options_button = _button("DISPLAY OPTIONS", false)
	options_button.pressed.connect(_open_options)
	var abandon := _button("ABANDON RUN", true)
	abandon.pressed.connect(func() -> void: _show_page(Page.ABANDON))
	box.add_child(_inset(resume_button))
	box.add_child(_inset(options_button))
	box.add_child(_inset(_divider(), 0))
	box.add_child(_inset(abandon))
	return box

func _build_abandon_page() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_header("ABANDON RUN?", "icon_alert_v01.png"))
	var message := Label.new()
	message.text = "Progress in this run will be lost."
	message.add_theme_font_override("font", PIXEL_FONT)
	message.add_theme_font_size_override("font_size", 8)
	message.add_theme_color_override("font_color", TEXT_COLOR)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.y = 40
	box.add_child(message)
	box.add_child(_inset(_divider(), 0))
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	box.add_child(gap)
	cancel_button = _button("CANCEL", false)
	cancel_button.pressed.connect(func() -> void: _show_page(Page.PAUSED))
	var confirm := _button("ABANDON RUN", true)
	confirm.pressed.connect(_abandon)
	for b: Button in [cancel_button, confirm]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(cancel_button)
	row.add_child(confirm)
	box.add_child(_inset(row))
	return box

func _header(text: String, icon_file: String) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.custom_minimum_size.y = 32
	plate.add_theme_stylebox_override("panel", _box("header_plate_v01.png", 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	plate.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(TEX_DIR + icon_file)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(29, 0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	var balance := Control.new()
	balance.custom_minimum_size.x = 29
	row.add_child(balance)
	return plate

func _divider() -> TextureRect:
	var line := TextureRect.new()
	line.texture = load(TEX_DIR + "divider_v01.png")
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.custom_minimum_size.y = 2
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _inset(child: Control, side: int = 11) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", side)
	m.add_theme_constant_override("margin_right", side)
	m.add_child(child)
	return m

func _button(text: String, danger: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 34)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 8)
	var color: Color = DANGER_COLOR if danger else TEXT_COLOR
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, color)
	b.add_theme_color_override("font_disabled_color", DISABLED_COLOR)
	var prefix: String = "button_danger_" if danger else "button_"
	var normal: StyleBoxTexture = _box(prefix + "normal_v01.png", 4)
	var hover: StyleBoxTexture = _box(prefix + "hover_v01.png", 4)
	var pressed: StyleBoxTexture = _box(prefix + "pressed_v01.png", 4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", _box("button_disabled_v01.png", 4))
	var focus: StyleBoxTexture = _box("button_focus_v01.png", 4)
	focus.texture_margin_left = 9.0
	b.add_theme_stylebox_override("focus", focus)
	return b

func _box(file: String, margin: float) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(TEX_DIR + file)
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	return box

func _show_page(target: Page) -> void:
	page = target
	pause_page.visible = target != Page.ABANDON
	abandon_page.visible = target == Page.ABANDON
	match target:
		Page.PAUSED:
			resume_button.grab_focus.call_deferred()
		Page.ABANDON:
			cancel_button.grab_focus.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if page == Page.OPTIONS:
		return
	if event.is_action_pressed("game_pause"):
		get_viewport().set_input_as_handled()
		if page == Page.ABANDON:
			_show_page(Page.PAUSED)
		else:
			resume()
		return
	var key := event as InputEventKey
	if OS.is_debug_build() and key and key.pressed and not key.echo and key.keycode == KEY_F9:
		get_viewport().set_input_as_handled()
		Global.test_enemy_all_units = not Global.test_enemy_all_units
		_refresh_test_label()

func _refresh_test_label() -> void:
	if test_label:
		test_label.text = "[F9] test mode, enemy spawns all units: %s" % ("ON" if Global.test_enemy_all_units else "OFF")

func resume() -> void:
	get_tree().paused = false
	queue_free()

func _open_options() -> void:
	Global.open_options()
	_options = get_tree().root.get_node_or_null("OptionsMenu") as OptionsMenu
	if not _options:
		return
	page = Page.OPTIONS
	_options.closed.connect(_on_options_closed, CONNECT_ONE_SHOT)

func _on_options_closed() -> void:
	_options = null
	page = Page.PAUSED
	options_button.grab_focus.call_deferred()

func _abandon() -> void:
	get_tree().paused = false
	queue_free()
	if (Global.run):
		RunFlow.abandon()
		return
	Global.change_scene(Global.Menu.SHOP)
