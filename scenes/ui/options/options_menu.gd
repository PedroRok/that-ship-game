class_name OptionsMenu
extends CanvasLayer

signal closed

var width_spin : SpinBox
var height_spin : SpinBox
var resolution_option : OptionButton
var info_label : Label
var _building : bool = true

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_building = false
	_refresh_info()
	get_window().size_changed.connect(_refresh_info)

func _exit_tree() -> void:
	var window : Window = get_window()
	if (window and window.size_changed.is_connected(_refresh_info)):
		window.size_changed.disconnect(_refresh_info)

func _unhandled_input(event : InputEvent) -> void:
	if (event.is_action_pressed("game_pause")):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	GameSettings.save_settings()
	closed.emit()
	queue_free()

func _build() -> void:
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center : CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel : PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var margin : MarginContainer = MarginContainer.new()
	for side : String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(460, 0)
	margin.add_child(box)

	var title : Label = Label.new()
	title.text = "DISPLAY"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var mode_option : OptionButton = OptionButton.new()
	mode_option.add_item("Windowed", GameSettings.WindowMode.WINDOWED)
	mode_option.add_item("Fullscreen (borderless)", GameSettings.WindowMode.BORDERLESS)
	mode_option.add_item("Fullscreen (exclusive)", GameSettings.WindowMode.FULLSCREEN)
	mode_option.select(mode_option.get_item_index(GameSettings.window_mode))
	mode_option.item_selected.connect(func(index : int) -> void:
		GameSettings.window_mode = mode_option.get_item_id(index)
		_apply())
	box.add_child(_row("Window mode", mode_option))

	resolution_option = OptionButton.new()
	for res : Vector2i in GameSettings.RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [res.x, res.y])
	resolution_option.add_item("Custom size")
	var custom_index : int = GameSettings.RESOLUTIONS.size()
	resolution_option.select(custom_index if GameSettings.custom_size != Vector2i.ZERO else GameSettings.resolution_index)
	resolution_option.item_selected.connect(func(index : int) -> void:
		if (index == custom_index):
			GameSettings.custom_size = Vector2i(int(width_spin.value), int(height_spin.value))
		else:
			GameSettings.custom_size = Vector2i.ZERO
			GameSettings.resolution_index = index
		_apply())
	box.add_child(_row("Window size", resolution_option))

	var custom_box : HBoxContainer = HBoxContainer.new()
	width_spin = _spin(320, 7680, get_window().size.x)
	height_spin = _spin(180, 4320, get_window().size.y)
	var apply_custom : Button = Button.new()
	apply_custom.text = "Apply"
	apply_custom.pressed.connect(func() -> void:
		GameSettings.custom_size = Vector2i(int(width_spin.value), int(height_spin.value))
		resolution_option.select(GameSettings.RESOLUTIONS.size())
		_apply())
	custom_box.add_child(width_spin)
	var x_label : Label = Label.new()
	x_label.text = " x "
	custom_box.add_child(x_label)
	custom_box.add_child(height_spin)
	custom_box.add_child(apply_custom)
	box.add_child(_row("Custom (W x H)", custom_box))

	var scale_option : OptionButton = OptionButton.new()
	scale_option.add_item("Fit (fills window, keeps proportion)", GameSettings.ScaleMode.FIT)
	scale_option.add_item("Pixel perfect (integer scale)", GameSettings.ScaleMode.PIXEL)
	scale_option.select(scale_option.get_item_index(GameSettings.scale_mode))
	scale_option.item_selected.connect(func(index : int) -> void:
		GameSettings.scale_mode = scale_option.get_item_id(index)
		_apply(false))
	box.add_child(_row("Scaling", scale_option))

	var vsync_check : CheckButton = CheckButton.new()
	vsync_check.button_pressed = GameSettings.vsync
	vsync_check.toggled.connect(func(on : bool) -> void:
		GameSettings.vsync = on
		_apply(false))
	box.add_child(_row("VSync", vsync_check))

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.modulate = Color(1, 1, 1, 0.7)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info_label)

	var hint : Label = Label.new()
	hint.text = "You can also drag the window edges: the game follows the new size."
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	var close_button : Button = Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(0, 34)
	close_button.pressed.connect(close)
	box.add_child(close_button)

func _row(label_text : String, control : Control) -> HBoxContainer:
	var row : HBoxContainer = HBoxContainer.new()
	var label : Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	return row

func _spin(min_value : float, max_value : float, value : float) -> SpinBox:
	var spin : SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1
	spin.value = value
	return spin

func _apply(apply_size : bool = true) -> void:
	if (_building):
		return
	GameSettings.apply(get_window(), apply_size)
	GameSettings.save_settings()
	_refresh_info.call_deferred()

func _refresh_info() -> void:
	if (!info_label or !is_instance_valid(info_label)):
		return
	var window : Window = get_window()
	info_label.text = "Current window: %d x %d" % [window.size.x, window.size.y]
	if (width_spin and !width_spin.get_line_edit().has_focus()):
		width_spin.set_value_no_signal(window.size.x)
		height_spin.set_value_no_signal(window.size.y)
