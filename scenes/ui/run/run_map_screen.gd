class_name RunMapScreen
extends RunScreen

var chart : MapChart
var info_box : VBoxContainer
var confirm_button : Button
var abandon_button : Button
var relic_row : HBoxContainer
const INFO_WIDTH : int = 334
const INFO_HEIGHT : int = 236

var abandon_armed : bool = false

func expected_stage() -> int:
	return RunData.Stage.MAP

func screen_title() -> String:
	return "Run Map"

func screen_subtitle() -> String:
	return "FLOOR %02d / %02d" % [mini(run.floors_cleared() + 1, RunData.COLUMNS), RunData.COLUMNS]

func _build() -> void:
	content.add_child(_build_stats_row())
	var main : HBoxContainer = HBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(main)
	main.add_child(_build_chart_panel())
	main.add_child(_build_info_panel())
	run.focus_node = -1
	_refresh()
	var reachable : Array[int] = run.reachable_nodes()
	var first : Control = abandon_button
	if (!reachable.is_empty() and chart.buttons.has(reachable[0])):
		first = chart.buttons[reachable[0]] as Control
	_defer_focus(first)

func _build_stats_row() -> Control:
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var hp_panel : PanelContainer = _panel(12)
	hp_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_panel.size_flags_stretch_ratio = 2.0
	var hp_box : VBoxContainer = VBoxContainer.new()
	hp_panel.add_child(hp_box)
	hp_box.add_child(_label("BASE HEALTH", 12, TEXT_SOFT, true))
	var hp_row : HBoxContainer = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 10)
	hp_row.add_child(_icon(RunData.ui_icon("base_health")))
	hp_row.add_child(_hp_bar(run.base_hp, run.base_max_hp))
	hp_row.add_child(_spacer())
	hp_row.add_child(_label("%d / %d" % [run.base_hp, run.base_max_hp], 16, TEXT, true))
	hp_box.add_child(hp_row)
	row.add_child(hp_panel)
	row.add_child(_small_stat("RELICS", "%02d" % run.relics.size(), AMBER, null))
	row.add_child(_small_stat("FLOOR", "%02d / %02d" % [mini(run.floors_cleared(), RunData.COLUMNS), RunData.COLUMNS], TEXT, _icon(RunData.ui_icon("floors"))))
	row.add_child(_small_stat("SCREWS", str(run.screws), AMBER, _screw_icon()))
	return row

func _small_stat(title : String, value : String, color : Color, icon : Control) -> PanelContainer:
	var panel : PanelContainer = _panel(12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box : VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_label(title, 12, TEXT_SOFT, true))
	var line : HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	if (icon):
		line.add_child(icon)
	line.add_child(_label(value, 16, color, true))
	box.add_child(line)
	return panel

func _build_chart_panel() -> Control:
	var panel : PanelContainer = _panel(4)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 2.5
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var top : HBoxContainer = HBoxContainer.new()
	var plate : PanelContainer = _plate("NAVIGATION CHART", TEXT, 16)
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(plate)
	box.add_child(top)
	var holder : CenterContainer = CenterContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(holder)
	chart = MapChart.new()
	holder.add_child(chart)
	chart.setup(run)
	chart.node_activated.connect(_on_node_activated)
	box.add_child(_divider())
	var legend_margin : MarginContainer = MarginContainer.new()
	legend_margin.add_theme_constant_override("margin_bottom", 8)
	legend_margin.add_child(_legend())
	box.add_child(legend_margin)
	return panel

func _legend() -> HBoxContainer:
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var entries : Array = [["Traveled", MapChart.ROUTE_TRAVELED], ["Selected", MapChart.ROUTE_FOCUS],
		["Available", MapChart.ROUTE_AVAILABLE], ["Locked", MapChart.ROUTE_LOCKED]]
	for entry : Array in entries:
		var item : HBoxContainer = HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		var swatch : ColorRect = ColorRect.new()
		swatch.color = entry[1]
		swatch.custom_minimum_size = Vector2(14, 4)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(swatch)
		item.add_child(_label(entry[0], 12, TEXT_SOFT))
		row.add_child(item)
	return row

func _build_info_panel() -> Control:
	var panel : PanelContainer = _panel(10)
	panel.size_flags_horizontal = Control.SIZE_FILL
	panel.custom_minimum_size.x = INFO_WIDTH
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_plate("SELECTED NODE", TEXT, 16))
	var holder : Control = Control.new()
	holder.custom_minimum_size = Vector2(INFO_WIDTH - 2 * (10 + FRAME_ART), INFO_HEIGHT)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.clip_contents = true
	box.add_child(holder)
	info_box = VBoxContainer.new()
	info_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_box.add_theme_constant_override("separation", 8)
	holder.add_child(info_box)
	confirm_button = _button("SELECT A NODE")
	confirm_button.pressed.connect(_on_confirm)
	box.add_child(confirm_button)
	box.add_child(_divider())
	box.add_child(_label("RELICS COLLECTED", 12, TEXT_SOFT, true))
	relic_row = HBoxContainer.new()
	relic_row.add_theme_constant_override("separation", 6)
	relic_row.custom_minimum_size.y = 38
	box.add_child(relic_row)
	abandon_button = _button("ABANDON RUN", true, 12)
	abandon_button.custom_minimum_size.y = 34
	abandon_button.pressed.connect(_on_abandon)
	box.add_child(abandon_button)
	return panel

func _on_node_activated(id : int) -> void:
	run.set_focus(id)
	_refresh()
	if (run.is_reachable(id)):
		_defer_focus(confirm_button)

func _on_confirm() -> void:
	if (run.confirm_focus()):
		_advance()

func _on_abandon() -> void:
	if (!abandon_armed):
		abandon_armed = true
		abandon_button.text = "CONFIRM ABANDON?"
		get_tree().create_timer(3.0).timeout.connect(_disarm_abandon)
		return
	RunFlow.abandon()

func _disarm_abandon() -> void:
	abandon_armed = false
	if (is_instance_valid(abandon_button)):
		abandon_button.text = "ABANDON RUN"

func _refresh() -> void:
	chart.refresh()
	_refresh_info()
	for child : Node in relic_row.get_children():
		child.queue_free()
	for relic_id : StringName in run.relics:
		var holder : PanelContainer = PanelContainer.new()
		holder.add_theme_stylebox_override("panel", _pause_box("button_disabled_v01.png", 4, 2))
		var rarity : int = int(RunData.RELICS[relic_id]["rarity"])
		holder.tooltip_text = "%s [%s]\n%s" % [RunData.RELICS[relic_id]["name"], RunData.RARITY_NAMES[rarity], RunData.RELICS[relic_id]["tag"]]
		holder.add_child(_icon(RunData.relic_icon(relic_id)))
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		relic_row.add_child(holder)

func _refresh_info() -> void:
	for child : Node in info_box.get_children():
		child.queue_free()
	var id : int = run.focus_node
	if (id < 0):
		info_box.add_child(_wrapped("Click a node on the chart to inspect it.", 14, TEXT_DIM))
		info_box.add_child(_wrapped("Hovering only highlights. Reachable nodes can be entered from here.", 11, TEXT_DIM))
		confirm_button.disabled = true
		confirm_button.text = "SELECT A NODE"
		return
	var entry : Dictionary = run.map.get_node(id)
	var node_type : int = int(entry["type"])
	var objective : int = int(entry["objective"])
	var is_fight : bool = node_type == RunData.NodeType.BATTLE or node_type == RunData.NodeType.ELITE or node_type == RunData.NodeType.BOSS
	var head : HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_icon(RunData.node_glyph(node_type, "normal")))
	var names : VBoxContainer = VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.add_child(_label(str(RunData.NODE_NAMES[node_type]).to_upper(), 12, AMBER, true))
	var title : String = RunData.OBJECTIVES[objective]["name"] if is_fight else _non_fight_title(entry)
	names.add_child(_label(title, 16 if title.length() > 12 else 24, TEXT, true))
	head.add_child(names)
	info_box.add_child(head)
	info_box.add_child(_divider())
	info_box.add_child(_label("OBJECTIVE" if is_fight else "DETAILS", 12, TEXT_SOFT, true))
	info_box.add_child(_wrapped(_describe(entry, is_fight), 12))
	info_box.add_child(_divider())
	var weather : int = run.node_weather(id)
	var weather_row : HBoxContainer = HBoxContainer.new()
	weather_row.add_theme_constant_override("separation", 8)
	weather_row.add_child(_icon(RunData.weather_icon(weather)))
	weather_row.add_child(_label(RunData.WEATHER[weather]["name"], 14, TEXT))
	info_box.add_child(weather_row)
	if (is_fight):
		var difficulty : int = run.node_difficulty(id)
		var diff_row : HBoxContainer = HBoxContainer.new()
		diff_row.add_theme_constant_override("separation", 10)
		diff_row.add_child(_segment_bar(float(difficulty), 5.0, 5,
				load("res://assets/ui/modifiers/reward_full_v01.png") as Texture2D,
				load("res://assets/ui/modifiers/reward_empty_v01.png") as Texture2D))
		diff_row.add_child(_label("Difficulty %d/5" % difficulty, 11, TEXT_DIM))
		info_box.add_child(diff_row)
		var reward : HBoxContainer = HBoxContainer.new()
		reward.add_theme_constant_override("separation", 8)
		reward.add_child(_screw_icon())
		var reward_text : String = "%d screws" % run.expected_screws(id)
		var relic_text : String = run.expected_relic_text(id)
		if (relic_text != ""):
			reward_text += " + " + relic_text
		reward.add_child(_label(reward_text, 11, TEXT_SOFT))
		info_box.add_child(reward)
	info_box.add_child(_spacer())
	var state : String = run.node_state(id)
	confirm_button.disabled = state != "normal"
	if (state == "normal"):
		confirm_button.text = "ENTER NODE"
	elif (state == "locked"):
		confirm_button.text = "NOT REACHABLE"
	else:
		confirm_button.text = "COMPLETED"

func _non_fight_title(entry : Dictionary) -> String:
	if (int(entry["type"]) == RunData.NodeType.EVENT):
		return str(RunData.event_by_id(StringName(entry["event_id"]))["title"])
	return "Repair Dock"

func _describe(entry : Dictionary, is_fight : bool) -> String:
	if (is_fight):
		return str(RunData.OBJECTIVES[int(entry["objective"])]["text"])
	if (int(entry["type"]) == RunData.NodeType.EVENT):
		return "Something drifts in the water. Choose how to respond."
	return "Repair the base or upgrade one unit for %d screws." % RunData.UPGRADE_COST
