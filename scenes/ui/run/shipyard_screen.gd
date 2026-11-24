class_name ShipyardScreen
extends RunScreen

var repair_button : Button
var upgrade_button : Button
var picker : Control
var _busy : bool = false

func expected_stage() -> int:
	return RunData.Stage.SHIPYARD

func screen_title() -> String:
	return "run.shipyard"

func screen_subtitle() -> String:
	return Loc.t("run.floor_repair_node") % [int(run.map.get_node(run.pending_node)["col"]) + 1]

func _build() -> void:
	var top : PanelContainer = _panel(10)
	var top_box : VBoxContainer = VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 10)
	top.add_child(top_box)
	top_box.add_child(_plate("run.base_under_maintenance", TEXT, 16, CYAN))
	var status : HBoxContainer = HBoxContainer.new()
	status.add_theme_constant_override("separation", 14)
	status.add_child(_icon(RunData.ui_icon("base_health")))
	status.add_child(_hp_bar(run.base_hp, run.base_max_hp, 24))
	status.add_child(_label("%d / %d HP" % [run.base_hp, run.base_max_hp], 16, TEXT, true))
	status.add_child(_spacer())
	status.add_child(_screw_icon())
	status.add_child(_label(Loc.t("run.screws") % run.screws, 16, AMBER, true))
	top_box.add_child(status)
	content.add_child(top)
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	repair_button = _button(Loc.t("run.repair_screws") % RunData.REPAIR_COST)
	upgrade_button = _button(Loc.t("run.choose_screws") % RunData.UPGRADE_COST)
	row.add_child(_action_panel("run.repair_base", RunData.ui_icon("repair"),
			Loc.t("run.recover_up_to_hp_of") % RunData.REPAIR_HP, repair_button, CYAN))
	row.add_child(_action_panel("run.upgrade_1_unit", RunData.ui_icon("upgrade_unit"),
			Loc.t("run.pick_a_unit_health_for") % int((RunData.UPGRADE_HEALTH_MULT - 1.0) * 100.0),
			upgrade_button, AMBER))
	content.add_child(row)
	content.add_child(_spacer())
	content.add_child(_divider())
	var back : Button = _button("run.back_to_map")
	back.custom_minimum_size.x = 270
	back.pressed.connect(_on_back)
	content.add_child(_footer(null, back))
	repair_button.pressed.connect(_on_repair)
	upgrade_button.pressed.connect(_on_upgrade)
	_refresh()
	var first : Control = back
	if (!repair_button.disabled):
		first = repair_button
	elif (!upgrade_button.disabled):
		first = upgrade_button
	_defer_focus(first)

func _action_panel(title : String, icon : Texture2D, text : String, button : Button, accent : Color) -> Control:
	var panel : PanelContainer = _panel(10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_plate(title, TEXT, 16, accent))
	var line : HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.add_child(_icon(icon))
	line.add_child(_wrapped(text, 14, TEXT))
	box.add_child(line)
	box.add_child(_divider())
	box.add_child(button)
	return panel

func _refresh() -> void:
	repair_button.disabled = !run.can_repair()
	upgrade_button.disabled = !run.can_upgrade_unit()
	if (run.shipyard_used("repair")):
		repair_button.text = "run.repaired"
	elif (run.base_hp >= run.base_max_hp):
		repair_button.text = "run.base_at_full_health"
	if (run.shipyard_used("upgrade")):
		upgrade_button.text = "run.upgraded"

func _on_repair() -> void:
	if (run.repair_base()):
		RunFlow.persist()
		_rebuild()

func _rebuild() -> void:
	Global.change_scene(Global.Menu.RUN_SHIPYARD)

func _on_upgrade() -> void:
	if (picker or !run.can_upgrade_unit()):
		return
	picker = _build_picker()
	add_child(picker)

func _build_picker() -> Control:
	var overlay : ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center : CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel : PanelContainer = _panel(14)
	center.add_child(panel)
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_plate("run.choose_a_unit", TEXT, 16, AMBER))
	var grid : GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	var first : Button = null
	for stats : EntityStats in Global.player_stats.loadout_entities():
		var level : int = int(run.unit_buffs.get(stats.name, 0))
		var button : Button = _button("%s  +%d" % [Loc.named("unit", stats.name).to_upper(), level], false, 12)
		button.custom_minimum_size = Vector2(190, 40)
		button.pressed.connect(_on_unit_chosen.bind(stats.name))
		grid.add_child(button)
		if (first == null):
			first = button
	var cancel : Button = _button("pause.cancel", true, 12)
	cancel.custom_minimum_size.y = 36
	cancel.pressed.connect(_close_picker)
	box.add_child(cancel)
	_defer_focus(first if first else cancel)
	return overlay

func _close_picker() -> void:
	if (picker):
		picker.queue_free()
		picker = null
	_defer_focus(upgrade_button)

func _on_unit_chosen(unit_name : String) -> void:
	if (run.upgrade_unit(unit_name)):
		RunFlow.persist()
		_rebuild()

func _on_back() -> void:
	if (_busy):
		return
	_busy = true
	run.leave_shipyard()
	_advance()
