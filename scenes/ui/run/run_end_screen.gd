class_name RunEndScreen
extends RunScreen

var _busy : bool = false

func expected_stage() -> int:
	return RunData.Stage.ENDED

func screen_title() -> String:
	return "run.run_won" if run.result == RunData.Result.WON else "run.run_lost"

func screen_subtitle() -> String:
	return "run.victory_summary" if run.result == RunData.Result.WON else "run.defeat_summary"

func _build() -> void:
	var won : bool = run.result == RunData.Result.WON
	var accent : Color = CYAN if won else DANGER
	var panel : PanelContainer = _panel(10)
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_plate("run.boss_defeated" if won else "battle.base_destroyed", TEXT, 16, accent))
	var line : HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.add_child(_icon(RunData.ui_icon("boss" if won else "base_health_damaged")))
	line.add_child(_label(run.end_reason, 14, TEXT))
	box.add_child(line)
	content.add_child(panel)
	var summary : Dictionary = run.end_summary
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_stat_panel("run.gears", "+%d" % int(summary.get("gears", 0)), "run.campaign_reward", AMBER, _gear_icon()))
	row.add_child(_stat_panel("run.boss_coins", "+%d" % int(summary.get("boss_coins", 0)), "run.boss_reward", Color("#9bbeeb"),
			_icon(RunData.ui_icon("boss"))))
	row.add_child(_stat_panel("run.floors", "%02d / %02d" % [int(summary.get("floors", 0)), RunData.COLUMNS], "run.run_progress",
			accent, _icon(RunData.ui_icon("floors"))))
	content.add_child(row)
	content.add_child(_spacer())
	content.add_child(_divider())
	var back : Button = _button("run.back_to_menu")
	back.custom_minimum_size.x = 290
	back.pressed.connect(_on_back)
	content.add_child(_footer(null, back))
	_defer_focus(back)

func _on_back() -> void:
	if (_busy):
		return
	_busy = true
	RunFlow.leave_to_menu()
