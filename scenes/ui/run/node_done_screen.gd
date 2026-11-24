class_name NodeDoneScreen
extends RunScreen

var _busy : bool = false

func expected_stage() -> int:
	return RunData.Stage.NODE_DONE

func screen_title() -> String:
	return "run.node_complete" if bool(run.node_result.get("success", false)) else "run.objective_failed"

func screen_subtitle() -> String:
	var node : Dictionary = run.map.get_node(int(run.node_result.get("node", run.current_node)))
	return Loc.t("run.floor") % [int(node["col"]) + 1, Loc.t(str(RunData.NODE_NAMES[int(node["type"])])).to_upper()]

func _build() -> void:
	var result : Dictionary = run.node_result
	var success : bool = bool(result.get("success", false))
	var node : Dictionary = run.map.get_node(int(result.get("node", run.current_node)))
	var objective : Dictionary = RunData.OBJECTIVES[int(node["objective"])]
	var panel : PanelContainer = _panel(10)
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title : String = (Loc.t("run.complete") % Loc.t(objective["name"])) if success else (Loc.t("run.failed") % Loc.t(objective["name"]))
	box.add_child(_plate(title.to_upper(), TEXT, 16, CYAN if success else DANGER))
	var line : HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.add_child(_icon(RunData.ui_icon("check_ok" if success else "cross_fail")))
	var text : String = "run.objective_complete_rewards_collected" if success \
			else Loc.t("run.the_objective_was_lost_the") % RunData.FAIL_BASE_DAMAGE
	line.add_child(_label(text, 14, TEXT))
	box.add_child(line)
	content.add_child(panel)
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var offered : bool = bool(result.get("relic_offered", false))
	var bonus : int = int(round(float(result.get("risk_bonus", 0.0)) * 100.0))
	var bonus_note : String = "run.no_risk_modifiers"
	if (bonus > 0):
		bonus_note = Loc.t("run.includes_risk_bonus") % bonus
	row.add_child(_stat_panel("run.screws_earned", "+%d" % int(result.get("screws", 0)), bonus_note, AMBER, _screw_icon()))
	row.add_child(_stat_panel("run.relic", "run.offer" if offered else "-",
			"run.pick_one_on_the_next" if offered else "run.no_relic_this_time", Color("#9bbeeb")))
	var damage : int = int(result.get("damage", 0))
	row.add_child(_stat_panel("run.base_damage", "-%d HP" % damage, Loc.t("run.hp_left") % [run.base_hp, run.base_max_hp],
			DANGER if damage > 0 else TEXT, _icon(RunData.ui_icon("base_health_damaged"))))
	content.add_child(row)
	var hp_panel : PanelContainer = _panel(8)
	var hp_box : VBoxContainer = VBoxContainer.new()
	hp_panel.add_child(hp_box)
	hp_box.add_child(_label("run.base_health", 12, TEXT_SOFT, true))
	var hp_row : HBoxContainer = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 14)
	hp_row.add_child(_hp_bar(run.base_hp, run.base_max_hp, 24))
	hp_row.add_child(_label("%d / %d HP" % [run.base_hp, run.base_max_hp], 16, TEXT, true))
	hp_box.add_child(hp_row)
	content.add_child(hp_panel)
	content.add_child(_spacer())
	content.add_child(_divider())
	var go : Button = _button("run.choose_relic" if offered else "run.continue_to_map")
	go.custom_minimum_size.x = 300
	go.pressed.connect(_on_continue)
	content.add_child(_footer(null, go))
	_defer_focus(go)

func _on_continue() -> void:
	if (_busy):
		return
	_busy = true
	run.continue_after_node()
	_advance()
