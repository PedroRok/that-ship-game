class_name EventScreen
extends RunScreen

var _busy : bool = false

func expected_stage() -> int:
	return RunData.Stage.EVENT

func screen_title() -> String:
	return "run.event"

func screen_subtitle() -> String:
	return Loc.t("run.floor_event_node") % [int(run.map.get_node(run.pending_node)["col"]) + 1]

func _build() -> void:
	var event : Dictionary = run.current_event()
	var panel : PanelContainer = _panel(12)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(_plate(Loc.t(str(event["title"])).to_upper(), TEXT, 16, CYAN))
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	var left : VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.add_child(_banner(StringName(event["id"])))
	left.add_child(_label(Loc.t(str(event["tag"])), 12, TEXT_SOFT, true))
	row.add_child(left)
	var right : VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var story : Label = _wrapped(Loc.t(str(event["text"])), 14, TEXT)
	PixelText.describe(story)
	right.add_child(story)
	right.add_child(_divider())
	var first : Button = null
	var choices : Array = event["choices"]
	for index : int in choices.size():
		var button : Button = _choice_button(choices[index], index)
		right.add_child(button)
		if (first == null and !button.disabled):
			first = button
	row.add_child(right)
	content.add_child(panel)
	if (first):
		_defer_focus(first)

func _banner(event_id : StringName) -> Control:
	var banner : TextureRect = TextureRect.new()
	banner.custom_minimum_size = Vector2(512, 192)
	banner.stretch_mode = TextureRect.STRETCH_SCALE
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path : String = str(RunData.EVENT_BANNER.get(event_id, RunData.EVENT_BANNER[&"drifting_signal"]))
	banner.texture = load(path) as Texture2D
	return banner

func _choice_button(choice : Dictionary, index : int) -> Button:
	var button : Button = _button("")
	button.custom_minimum_size = Vector2(0, 70)
	button.disabled = !run.can_choose_event(index)
	var inner : HBoxContainer = HBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 14
	inner.offset_right = -10
	inner.add_theme_constant_override("separation", 12)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inner)
	inner.add_child(_icon(RunData.ui_icon(str(choice["icon"]), button.disabled)))
	var texts : VBoxContainer = VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 4)
	texts.add_child(_label(Loc.t(str(choice["label"])), 16, TEXT if !button.disabled else TEXT_DIM, true))
	var detail : String = Loc.t(str(choice["text"]))
	if (button.disabled):
		detail += "  (not enough screws)"
	var outcome : Label = _label(detail, 10, TEXT_SOFT if !button.disabled else TEXT_DIM)
	PixelText.describe(outcome)
	texts.add_child(outcome)
	inner.add_child(texts)
	button.pressed.connect(_on_choice.bind(index))
	return button

func _on_choice(index : int) -> void:
	if (_busy):
		return
	_busy = true
	if (run.choose_event(index)):
		_advance()
	else:
		_busy = false
