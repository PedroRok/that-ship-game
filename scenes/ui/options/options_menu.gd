class_name OptionsMenu
extends CanvasLayer

signal closed

const PAUSE_DIR : String = "res://assets/ui/pause/"
const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")
const PIXEL_FONT : Font = preload("res://assets/fonts/dogicapixel.ttf")

const TEXT : Color = Color("#eaf3f5")
const TEXT_SOFT : Color = Color("#a3bec8")
const TEXT_DIM : Color = Color("#7795a1")
const CYAN : Color = Color("#78dddd")
const FACE : Color = Color("#152027")
const WELL : Color = Color("#090f16")
const STEEL : Color = Color("#34454f")
const EDGE : Color = Color("#4f6773")

const PANEL_WIDTH : int = 600
const LABEL_WIDTH : int = 190
const ROW_HEIGHT : int = 32

const SCALE_NOTES : Dictionary = {
	GameSettings.ScaleMode.FIT: "options.fills_the_window_and_keeps",
	GameSettings.ScaleMode.PIXEL: "options.only_whole_number_scales_sharp",
}

const PREVIEWS : Dictionary = {
	"Master": {"stream": preload("res://assets/game/sounds/hud/hud_confirm.ogg"), "bus": &"Master", "db": -4.0},
	"WorldSFX": {"stream": preload("res://assets/game/sounds/battle/small_ship_break/battle_small_ship_break_a_v14.ogg"), "bus": &"WorldSFX", "db": -7.0},
	"UI": {"stream": preload("res://assets/game/sounds/hud/hud_select.ogg"), "bus": &"UI", "db": -6.0},
}

var _preview_players : Dictionary = {}
var resolution_option : OptionButton
var mode_option : OptionButton
var info_label : Label
var scale_note : Label
var _building : bool = true
var _last_size : Vector2i = Vector2i.ZERO

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_building = false
	_refresh_info()
	mode_option.grab_focus.call_deferred()

func _process(_delta : float) -> void:
	var size : Vector2i = DisplayServer.window_get_size()
	if (size != _last_size):
		_last_size = size
		_refresh_info()

func _unhandled_input(event : InputEvent) -> void:
	if (event.is_action_pressed("game_pause")):
		get_viewport().set_input_as_handled()
		close()

func _reopen() -> void:
	for child : Node in get_children():
		if (child is Control):
			child.queue_free()
	_building = true
	_build()
	_building = false
	_refresh_info()
	mode_option.grab_focus.call_deferred()

func close() -> void:
	GameSettings.save_settings()
	closed.emit()
	queue_free()

func _build() -> void:
	var root : Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.theme = _make_theme()
	add_child(root)

	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center : CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box("panel_frame_v01.png", 16, 22))
	center.add_child(panel)

	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_child(box)

	box.add_child(_header("options.settings", "options.display_audio"))

	mode_option = OptionButton.new()
	mode_option.add_item("options.windowed", GameSettings.WindowMode.WINDOWED)
	mode_option.add_item("options.borderless_fullscreen", GameSettings.WindowMode.BORDERLESS)
	mode_option.add_item("options.exclusive_fullscreen", GameSettings.WindowMode.FULLSCREEN)
	mode_option.select(mode_option.get_item_index(GameSettings.window_mode))
	mode_option.item_selected.connect(func(index : int) -> void:
		GameSettings.window_mode = mode_option.get_item_id(index)
		_apply())
	box.add_child(_row("options.window_mode", mode_option))

	resolution_option = OptionButton.new()
	for res : Vector2i in GameSettings.RESOLUTIONS:
		resolution_option.add_item("%d X %d" % [res.x, res.y])
	resolution_option.select(GameSettings.resolution_index)
	resolution_option.item_selected.connect(func(index : int) -> void:
		GameSettings.resolution_index = index
		_apply())
	box.add_child(_row("options.window_size", resolution_option))

	var language_option : OptionButton = OptionButton.new()
	for entry : Dictionary in Loc.languages():
		language_option.add_item(str(entry["name"]))
	language_option.select(Loc.language_index(GameSettings.language))
	language_option.item_selected.connect(func(index : int) -> void:
		Loc.set_language(str(Loc.languages()[index]["code"]))
		GameSettings.save_settings()
		_reopen.call_deferred())
	box.add_child(_row("options.language", language_option))

	box.add_child(_divider())

	var scale_option : OptionButton = OptionButton.new()
	scale_option.add_item("options.fit", GameSettings.ScaleMode.FIT)
	scale_option.add_item("options.pixel_perfect", GameSettings.ScaleMode.PIXEL)
	scale_option.select(scale_option.get_item_index(GameSettings.scale_mode))
	scale_option.item_selected.connect(func(index : int) -> void:
		GameSettings.scale_mode = scale_option.get_item_id(index)
		_refresh_scale_note()
		_apply(false))
	var vsync_check : CheckButton = CheckButton.new()
	vsync_check.text = "options.vsync"
	vsync_check.button_pressed = GameSettings.vsync
	vsync_check.focus_mode = Control.FOCUS_ALL
	vsync_check.toggled.connect(func(on : bool) -> void:
		GameSettings.vsync = on
		_apply(false))
	var scale_box : HBoxContainer = HBoxContainer.new()
	scale_box.add_theme_constant_override("separation", 16)
	scale_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vsync_check.size_flags_horizontal = Control.SIZE_SHRINK_END
	scale_box.add_child(scale_option)
	scale_box.add_child(vsync_check)
	box.add_child(_row("options.scaling", scale_box))

	scale_note = _wrapped("", 8, TEXT_DIM)
	box.add_child(_indent(scale_note))
	_refresh_scale_note()

	box.add_child(_divider())

	for entry : Array in [["options.master_volume", "Master"], ["options.effects_volume", "WorldSFX"], ["options.interface_volume", "UI"]]:
		box.add_child(_volume_row(str(entry[0]), str(entry[1])))

	box.add_child(_divider())

	info_label = _label("", 8, CYAN, true)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info_label)
	var hint : Label = _wrapped("options.you_can_also_drag_the", 8, TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var close_button : Button = _button("options.close", 16)
	close_button.custom_minimum_size = Vector2(0, 44)
	close_button.pressed.connect(close)
	box.add_child(close_button)

func _make_theme() -> Theme:
	var theme : Theme = PixelControls.themed()
	theme.default_font = PIXEL_FONT
	theme.default_font_size = 8
	for type : String in ["Button", "OptionButton"]:
		theme.set_font("font", type, FONT)
		theme.set_font_size("font_size", type, 8)
		for key : String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(key, type, TEXT)
		theme.set_color("font_disabled_color", type, TEXT_DIM)
		var pressed : StyleBoxTexture = _box("button_pressed_v01.png", 4)
		theme.set_stylebox("normal", type, _box("button_normal_v01.png", 4))
		theme.set_stylebox("hover", type, _box("button_hover_v01.png", 4))
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, _box("button_disabled_v01.png", 4))
		var focus : StyleBoxTexture = _box("button_focus_v01.png", 4)
		focus.texture_margin_left = 9.0
		theme.set_stylebox("focus", type, focus)
	for state : String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		(theme.get_stylebox(state, "OptionButton") as StyleBoxTexture).content_margin_left = 14
	theme.set_constant("h_separation", "OptionButton", 8)
	theme.set_color("icon_normal_color", "OptionButton", TEXT)
	theme.set_color("icon_hover_color", "OptionButton", CYAN)
	theme.set_color("icon_pressed_color", "OptionButton", CYAN)
	theme.set_color("icon_focus_color", "OptionButton", TEXT)

	var popup_panel : StyleBoxFlat = _flat(FACE, EDGE, 2)
	popup_panel.set_content_margin_all(4)
	theme.set_stylebox("panel", "PopupMenu", popup_panel)
	theme.set_stylebox("hover", "PopupMenu", _flat(STEEL, CYAN, 1))
	theme.set_stylebox("separator", "PopupMenu", _flat(STEEL, STEEL, 0))
	theme.set_font("font", "PopupMenu", PIXEL_FONT)
	theme.set_font_size("font_size", "PopupMenu", 8)
	theme.set_color("font_color", "PopupMenu", TEXT_SOFT)
	theme.set_color("font_hover_color", "PopupMenu", TEXT)
	theme.set_constant("v_separation", "PopupMenu", 10)
	theme.set_constant("item_start_padding", "PopupMenu", 8)
	theme.set_constant("item_end_padding", "PopupMenu", 8)

	var edit_normal : StyleBoxFlat = _flat(WELL, STEEL, 1)
	edit_normal.set_content_margin_all(6)
	var edit_focus : StyleBoxFlat = _flat(WELL, CYAN, 1)
	edit_focus.set_content_margin_all(6)
	theme.set_stylebox("normal", "LineEdit", edit_normal)
	theme.set_stylebox("focus", "LineEdit", edit_focus)
	theme.set_stylebox("read_only", "LineEdit", edit_normal)
	theme.set_font("font", "LineEdit", PIXEL_FONT)
	theme.set_font_size("font_size", "LineEdit", 8)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", CYAN)
	theme.set_color("selection_color", "LineEdit", CYAN.darkened(0.55))

	var rail : StyleBoxFlat = _flat(WELL, STEEL, 1)
	rail.content_margin_top = 4
	rail.content_margin_bottom = 4
	var fill : StyleBoxFlat = _flat(CYAN.darkened(0.45), CYAN, 1)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", rail)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	theme.set_icon("grabber", "HSlider", _knob(CYAN))
	theme.set_icon("grabber_highlight", "HSlider", _knob(TEXT))
	theme.set_icon("grabber_disabled", "HSlider", _knob(TEXT_DIM))
	theme.set_constant("center_grabber", "HSlider", 1)

	for state : String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var check_box : StyleBoxTexture = theme.get_stylebox(state, "Button").duplicate() as StyleBoxTexture
		check_box.content_margin_left = 14
		check_box.content_margin_right = 12
		theme.set_stylebox(state, "CheckButton", check_box)

	for type : String in ["CheckButton", "CheckBox"]:
		theme.set_font("font", type, FONT)
		theme.set_font_size("font_size", type, 8)
		for key : String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(key, type, TEXT)
	return theme

func _knob(color : Color) -> Texture2D:
	var image : Image = Image.create(10, 18, false, Image.FORMAT_RGBA8)
	image.fill(WELL)
	image.fill_rect(Rect2i(1, 1, 8, 16), color)
	image.fill_rect(Rect2i(4, 4, 2, 10), WELL)
	return ImageTexture.create_from_image(image)

func _flat(fill : Color, border : Color, width : int) -> StyleBoxFlat:
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.anti_aliasing = false
	return style

func _box(file : String, margin : int, content_margin : int = -1) -> StyleBoxTexture:
	var style : StyleBoxTexture = StyleBoxTexture.new()
	style.texture = load(PAUSE_DIR + file) as Texture2D
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	if (content_margin >= 0):
		style.content_margin_left = content_margin
		style.content_margin_right = content_margin
		style.content_margin_top = content_margin
		style.content_margin_bottom = content_margin
	return style

func _label(text : String, size : int = 8, color : Color = TEXT, bold : bool = false) -> Label:
	var label : Label = Label.new()
	label.text = PixelText.fit(text, size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT if bold else PIXEL_FONT)
	label.add_theme_font_size_override("font_size", PixelText.snap(size))
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _wrapped(text : String, size : int = 8, color : Color = TEXT) -> Label:
	var label : Label = _label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(text : String, font_size : int = 8) -> Button:
	var button : Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", PixelText.snap(font_size))
	return button

func _header(kicker : String, title : String) -> Control:
	var plate : PanelContainer = PanelContainer.new()
	plate.custom_minimum_size = Vector2(0, 64)
	plate.add_theme_stylebox_override("panel", _box("header_plate_v01.png", 2, 0))
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	plate.add_child(row)
	var strip : ColorRect = ColorRect.new()
	strip.color = CYAN
	strip.custom_minimum_size = Vector2(4, 0)
	row.add_child(strip)
	var margin : MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(margin)
	var texts : VBoxContainer = VBoxContainer.new()
	texts.add_theme_constant_override("separation", 6)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(texts)
	texts.add_child(_label(kicker, 8, CYAN, true))
	texts.add_child(_label(title, 16, TEXT, true))
	return plate

func _divider() -> TextureRect:
	var line : TextureRect = TextureRect.new()
	line.texture = load(PAUSE_DIR + "divider_v01.png") as Texture2D
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.custom_minimum_size.y = 2
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _indent(child : Control) -> MarginContainer:
	var margin : MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", LABEL_WIDTH + 8)
	margin.add_child(child)
	return margin

func _row(label_text : String, control : Control) -> HBoxContainer:
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label : Label = _label(label_text, 8, TEXT_SOFT)
	label.custom_minimum_size = Vector2(LABEL_WIDTH, ROW_HEIGHT)
	if (control.size_flags_horizontal != Control.SIZE_SHRINK_BEGIN):
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.y = ROW_HEIGHT
	row.add_child(label)
	row.add_child(control)
	return row

func _play_preview(bus : String) -> void:
	var data : Dictionary = PREVIEWS[bus]
	var player : AudioStreamPlayer = _preview_players.get(bus) as AudioStreamPlayer
	if (!player):
		player = AudioStreamPlayer.new()
		player.stream = data["stream"]
		player.bus = data["bus"]
		player.volume_db = float(data["db"])
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_preview_players[bus] = player
	player.play()

func _volume_row(label_text : String, bus : String) -> HBoxContainer:
	var slider : HSlider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = int(GameSettings.volumes[bus])
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	var preview : Timer = Timer.new()
	preview.one_shot = true
	preview.wait_time = 0.18
	preview.process_mode = Node.PROCESS_MODE_ALWAYS
	preview.timeout.connect(_play_preview.bind(bus))
	slider.add_child(preview)
	var readout : Label = _label("%d" % int(slider.value), 8, CYAN, true)
	readout.custom_minimum_size.x = 40
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(value : float) -> void:
		GameSettings.volumes[bus] = int(value)
		readout.text = "%d" % int(value)
		GameSettings.apply_volume(bus)
		if (!_building):
			GameSettings.save_settings()
			preview.start())
	var holder : HBoxContainer = HBoxContainer.new()
	holder.add_theme_constant_override("separation", 8)
	holder.add_child(slider)
	holder.add_child(readout)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label : Label = _label(label_text, 8, TEXT_SOFT)
	label.custom_minimum_size = Vector2(LABEL_WIDTH, ROW_HEIGHT)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(holder)
	return row

func _refresh_scale_note() -> void:
	if (scale_note):
		scale_note.text = PixelText.fit(str(SCALE_NOTES.get(GameSettings.scale_mode, "")), 8)

func _apply(apply_size : bool = true) -> void:
	if (_building):
		return
	GameSettings.apply(get_window(), apply_size)
	GameSettings.save_settings()
	_refresh_info.call_deferred()

func _refresh_info() -> void:
	if (!info_label or !is_instance_valid(info_label)):
		return
	var size : Vector2i = DisplayServer.window_get_size()
	info_label.text = Loc.t("options.current_window_x") % [size.x, size.y]
