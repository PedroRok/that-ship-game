class_name BriefingScreen
extends RunScreen

const MAX_BONUS_FOR_METER : float = 0.6

var slots_row : HBoxContainer
var list_grid : GridContainer
var count_label : Label
var reward_value : Label
var reward_meter : HBoxContainer
var reward_box : VBoxContainer
var screws_label : Label
var weather_info : VBoxContainer
var risk_buttons : Dictionary = {}

func expected_stage() -> int:
	return RunData.Stage.BRIEFING

func screen_title() -> String:
	return "run.briefing"

func screen_subtitle() -> String:
	var node : Dictionary = run.map.get_node(run.pending_node)
	return Loc.t("run.floor") % [int(node["col"]) + 1, Loc.t(str(RunData.NODE_NAMES[int(node["type"])])).to_upper()]

func _build() -> void:
	var main : HBoxContainer = HBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(main)
	main.add_child(_build_mission_panel())
	main.add_child(_build_risk_panel())
	var back : Button = _button("run.back_to_map")
	back.custom_minimum_size.x = 250
	back.pressed.connect(_on_back)
	var start : Button = _button("run.start_battle")
	start.custom_minimum_size.x = 270
	start.pressed.connect(_on_start)
	content.add_child(_divider())
	content.add_child(_footer(back, start))
	_refresh()
	_defer_focus(start)

func _build_mission_panel() -> Control:
	var node : Dictionary = run.map.get_node(run.pending_node)
	var objective : int = int(node["objective"])
	var panel : PanelContainer = _panel(10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.9
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_plate("run.mission_objective", TEXT, 16))
	var head : HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var well : PanelContainer = PanelContainer.new()
	well.add_theme_stylebox_override("panel", _flat(Color("#1d2c33"), Color("#2a3d46")))
	well.add_child(_icon(RunData.objective_hud_icon(objective), Vector2(44, 44)))
	head.add_child(well)
	head.add_child(_label(Loc.t(RunData.OBJECTIVES[objective]["name"]), 24, TEXT, true))
	box.add_child(head)
	box.add_child(_wrapped(Loc.t(RunData.OBJECTIVES[objective]["text"]), 12, TEXT))
	var warning : String = RunBattleConfig.capability_warning(objective)
	if (warning != ""):
		box.add_child(_wrapped(warning, 12, DANGER))
	box.add_child(_divider())
	weather_info = VBoxContainer.new()
	box.add_child(weather_info)
	box.add_child(_divider())
	box.add_child(_label("run.expected_enemies", 12, TEXT_SOFT, true))
	var enemies : HBoxContainer = HBoxContainer.new()
	enemies.add_theme_constant_override("separation", 10)
	for enemy : Dictionary in RunBattleConfig.expected_enemies(node):
		enemies.add_child(_enemy_card(str(enemy["key"]), Loc.t(str(enemy["label"]))))
	box.add_child(enemies)
	box.add_child(_divider())
	box.add_child(_label("run.expected_reward", 12, TEXT_SOFT, true))
	reward_box = VBoxContainer.new()
	reward_box.add_theme_constant_override("separation", 6)
	box.add_child(reward_box)
	return panel

func _flat(fill : Color, edge : Color) -> StyleBoxFlat:
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.anti_aliasing = false
	return style

func _enemy_card(key : String, label : String) -> Control:
	var card : PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _flat(Color("#10191f"), Color("#2a3d46")))
	var col : VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_icon(RunBattleConfig.silhouette(key), Vector2(128, 64)))
	var text : Label = _label(label, 10, TEXT_SOFT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(text)
	card.add_child(col)
	return card

func _build_risk_panel() -> Control:
	var panel : PanelContainer = _panel(10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.4
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var top : HBoxContainer = HBoxContainer.new()
	var plate : PanelContainer = _plate("run.risk_modifiers", TEXT, 16)
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(plate)
	box.add_child(top)
	count_label = _label("", 16, CYAN, true)
	count_label.position = Vector2.ZERO
	var count_holder : HBoxContainer = HBoxContainer.new()
	count_holder.add_child(_label("run.active_slots", 12, TEXT_SOFT, true))
	count_holder.add_child(_spacer())
	count_holder.add_child(count_label)
	box.add_child(count_holder)
	slots_row = HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 8)
	box.add_child(slots_row)
	box.add_child(_divider())
	box.add_child(_label("run.available_modifiers", 12, TEXT_SOFT, true))
	list_grid = GridContainer.new()
	list_grid.columns = 2
	list_grid.add_theme_constant_override("h_separation", 8)
	list_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(list_grid)
	box.add_child(_spacer())
	box.add_child(_divider())
	var reward_row : HBoxContainer = HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 12)
	reward_row.add_child(_label("run.reward", 14, TEXT_SOFT, true))
	reward_meter = HBoxContainer.new()
	reward_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_row.add_child(reward_meter)
	reward_value = _label("", 24, AMBER, true)
	reward_row.add_child(reward_value)
	box.add_child(reward_row)
	return panel

func _refresh() -> void:
	_refresh_weather()
	_refresh_slots()
	_refresh_list()
	_refresh_reward()

func _refresh_weather() -> void:
	for child : Node in weather_info.get_children():
		child.queue_free()
	var weather : int = run.node_weather(run.pending_node)
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_icon(RunData.weather_icon(weather)))
	row.add_child(_label(Loc.t(RunData.WEATHER[weather]["name"]), 14, TEXT))
	row.add_child(_spacer())
	var difficulty : int = run.node_difficulty(run.pending_node)
	row.add_child(_segment_bar(float(difficulty), 5.0, 5,
			load("res://assets/ui/modifiers/reward_full_v01.png") as Texture2D,
			load("res://assets/ui/modifiers/reward_empty_v01.png") as Texture2D))
	row.add_child(_label("%d/5" % difficulty, 14, TEXT_DIM))
	weather_info.add_child(row)
	weather_info.add_child(_label(Loc.t(RunData.WEATHER[weather]["text"]), 10, TEXT_DIM))

func _refresh_slots() -> void:
	count_label.text = "%d / %d" % [run.risks.size(), RunData.MAX_RISKS]
	for child : Node in slots_row.get_children():
		child.queue_free()
	for index : int in RunData.MAX_RISKS:
		var slot : Button = _slot_button(index)
		slots_row.add_child(slot)

func _slot_button(index : int) -> Button:
	var slot : Button = Button.new()
	slot.custom_minimum_size = Vector2(0, 50)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.focus_mode = Control.FOCUS_ALL
	var filled : bool = index < run.risks.size()
	var style : String = "equipped" if filled else "empty"
	var box : StyleBoxTexture = _box("res://assets/ui/modifiers/slot_%s_v01.png" % style, 8 if filled else 4)
	for state : String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		slot.add_theme_stylebox_override(state, box)
	slot.add_theme_stylebox_override("focus", _pause_box("button_focus_v01.png", 4))
	slot.disabled = !filled
	var inner : HBoxContainer = HBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(inner)
	if (filled):
		var risk_id : StringName = run.risks[index]
		var data : Dictionary = RunData.RISKS[risk_id]
		inner.add_child(_margin_spacer(8))
		inner.add_child(_icon(RunData.risk_icon(risk_id)))
		var texts : VBoxContainer = VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_theme_constant_override("separation", 4)
		texts.add_child(_label(Loc.t(str(data["name"])), 10, TEXT, true))
		texts.add_child(_label("+%d%%" % int(float(data["bonus"]) * 100.0), 10, AMBER))
		inner.add_child(texts)
		inner.add_child(_spacer())
		inner.add_child(_icon(RunData.ui_icon("cross_fail", true)))
		slot.pressed.connect(_on_risk_toggled.bind(risk_id))
	else:
		inner.add_child(_margin_spacer(8))
		inner.add_child(_label(Loc.t("run.empty_slot") % (index + 1), 10, TEXT_DIM))
	return slot

func _margin_spacer(width : int) -> Control:
	var spacer : Control = Control.new()
	spacer.custom_minimum_size.x = width
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _refresh_list() -> void:
	for child : Node in list_grid.get_children():
		child.queue_free()
	risk_buttons.clear()
	for risk_id : StringName in RunData.RISKS:
		if (!run.risk_applies(risk_id)):
			continue
		var button : Button = _risk_button(risk_id)
		list_grid.add_child(button)
		risk_buttons[risk_id] = button

func _risk_button(risk_id : StringName) -> Button:
	var data : Dictionary = RunData.RISKS[risk_id]
	var equipped : bool = run.risks.has(risk_id)
	var available : bool = equipped or run.risk_available(risk_id)
	var button : Button = Button.new()
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	var style : String = "equipped" if equipped else ("available" if available else "unavailable")
	var box : StyleBoxTexture = _box("res://assets/ui/modifiers/slot_%s_v01.png" % style, 8 if style != "available" else 4)
	for state : String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", _pause_box("button_focus_v01.png", 4))
	button.disabled = !available
	var inner : HBoxContainer = HBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 8)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inner)
	inner.add_child(_margin_spacer(8))
	inner.add_child(_icon(RunData.risk_icon(risk_id)))
	var texts : VBoxContainer = VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 5)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(_label(Loc.t(str(data["name"])), 12, TEXT if available else TEXT_DIM, true))
	texts.add_child(_label(Loc.t(str(data["text"])), 10, TEXT_SOFT if available else TEXT_DIM))
	inner.add_child(texts)
	var mark : Texture2D = RunData.ui_icon("check_ok") if equipped else null
	if (mark):
		inner.add_child(_icon(mark))
	else:
		inner.add_child(_label("+" if available else "", 14, TEXT_SOFT, true))
	inner.add_child(_margin_spacer(8))
	button.pressed.connect(_on_risk_toggled.bind(risk_id))
	return button

func _refresh_reward() -> void:
	var bonus : float = run.equipped_risks_bonus()
	reward_value.text = "+%d%%" % int(round(bonus * 100.0))
	for child : Node in reward_meter.get_children():
		child.queue_free()
	reward_meter.add_child(_reward_bar(bonus, MAX_BONUS_FOR_METER))
	for child : Node in reward_box.get_children():
		child.queue_free()
	var screws_row : HBoxContainer = HBoxContainer.new()
	screws_row.add_theme_constant_override("separation", 10)
	screws_row.add_child(_screw_icon())
	screws_row.add_child(_label(Loc.t("run.screws") % run.expected_screws(run.pending_node), 16, TEXT, true))
	reward_box.add_child(screws_row)
	var relic_text : String = run.expected_relic_text(run.pending_node)
	if (relic_text != ""):
		var relic_row : HBoxContainer = HBoxContainer.new()
		relic_row.add_theme_constant_override("separation", 10)
		relic_row.add_child(_icon(RunData.relic_icon(&"compass")))
		relic_row.add_child(_label(relic_text, 12, TEXT_SOFT))
		reward_box.add_child(relic_row)

func _on_risk_toggled(risk_id : StringName) -> void:
	if (run.toggle_risk(risk_id)):
		var focused : Control = get_viewport().gui_get_focus_owner()
		_refresh()
		if (focused and is_instance_valid(focused) and risk_buttons.has(risk_id)):
			_defer_focus(risk_buttons[risk_id] as Control)
		RunFlow.persist()

func _on_back() -> void:
	run.back_to_map()
	_advance()

var _starting : bool = false

func _on_start() -> void:
	if (_starting):
		return
	_starting = true
	if (run.start_battle()):
		_advance()
	else:
		_starting = false
