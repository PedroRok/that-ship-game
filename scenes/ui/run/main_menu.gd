class_name MainMenu
extends RunScreen

var first_button : Button
var _busy : bool = false
var _pending_delete : int = -1
var _delete_buttons : Dictionary = {}
var _creative_checks : Dictionary = {}

func requires_run() -> bool:
	return false

func screen_title() -> String:
	return "menu.main_menu"

func screen_subtitle() -> String:
	return "menu.choose_a_save"

func header_kicker() -> String:
	return "menu.shiping"

func _build() -> void:
	Global.run = null
	Global.start_mode = Global.StartMode.NONE
	content.add_child(_label("menu.each_save_keeps_its_own", 16, TEXT_SOFT))
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_child(row)
	for index : int in range(1, SaveManager.SLOT_COUNT + 1):
		row.add_child(_slot_card(index))
	content.add_child(_spacer())
	content.add_child(_divider())
	var options : Button = _button("menu.options")
	options.custom_minimum_size.x = 220
	options.pressed.connect(Global.open_options)
	var quit : Button = _button("menu.quit", true)
	quit.custom_minimum_size.x = 220
	quit.pressed.connect(func() -> void: get_tree().quit())
	content.add_child(_footer(options, quit))
	_defer_focus(first_button if first_button else options)

func _slot_card(index : int) -> Control:
	var summary : Dictionary = SaveManager.slot_summary(index)
	var exists : bool = bool(summary["exists"])
	var panel : PanelContainer = _panel(14)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 360)
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_plate(Loc.t("menu.slot") % index, TEXT, 16, CYAN if exists else TEXT_DIM))
	var stats : VBoxContainer = VBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(stats)
	if (exists):
		var gears : HBoxContainer = HBoxContainer.new()
		gears.alignment = BoxContainer.ALIGNMENT_CENTER
		gears.add_theme_constant_override("separation", 8)
		gears.add_child(_gear_icon())
		gears.add_child(_label("%d" % int(summary["gear"]), 24, AMBER, true))
		stats.add_child(gears)
		stats.add_child(_centered(Loc.t("menu.troops_unlocked") % int(summary["units"]), TEXT))
		stats.add_child(_centered(Loc.t("menu.best_wave_2") % int(summary["best_wave"]), TEXT_SOFT))
		stats.add_child(_centered(_run_text(summary["run"]), TEXT_SOFT))
		if (bool(summary["creative"])):
			stats.add_child(_centered("menu.creative_mode", AMBER))
	else:
		stats.add_child(_centered("menu.empty_save", TEXT_DIM))
		stats.add_child(_centered("menu.starts_with_the_basic_troops", TEXT_DIM))
	box.add_child(_divider())
	if (!exists):
		box.add_child(_creative_check(index))
	var play : Button = _button("result.play" if exists else "menu.new_save")
	play.pressed.connect(_on_play.bind(index))
	box.add_child(play)
	if (first_button == null):
		first_button = play
	var delete : Button = _button("menu.delete", true, 8)
	delete.custom_minimum_size.y = 32
	delete.disabled = !exists
	delete.pressed.connect(_on_delete.bind(index))
	_delete_buttons[index] = delete
	box.add_child(delete)
	return panel

func _centered(text : String, color : Color) -> Label:
	var label : Label = _wrapped(text, 12, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _run_text(run_state : Variant) -> String:
	if (run_state == null):
		return "menu.no_campaign_in_progress"
	var state : RunState = run_state
	return Loc.t("menu.campaign_floor_base") % [
			mini(state.floors_cleared() + 1, RunData.COLUMNS), RunData.COLUMNS, state.base_hp, state.base_max_hp]

func _creative_check(index : int) -> CheckBox:
	var check : CheckBox = CheckBox.new()
	check.text = "menu.creative_mode"
	check.tooltip_text = "menu.creative_mode_hint"
	check.focus_mode = Control.FOCUS_ALL
	check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	check.add_theme_font_override("font", FONT)
	check.add_theme_font_size_override("font_size", PixelText.snap(8))
	for key : String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		check.add_theme_color_override(key, AMBER)
	_creative_checks[index] = check
	return check

func _on_play(index : int) -> void:
	if (_busy):
		return
	_busy = true
	Global.load_slot(index)
	var check : CheckBox = _creative_checks.get(index) as CheckBox
	if (check and check.button_pressed):
		Global.player_stats.creative = true
		Global.save_game()
		Global.load_slot(index)
	Global.change_scene(Global.Menu.CAMPAIGN_SELECT)

func _on_delete(index : int) -> void:
	if (_pending_delete != index):
		_reset_delete_labels()
		_pending_delete = index
		(_delete_buttons[index] as Button).text = PixelText.fit("menu.confirm_delete", 8)
		return
	SaveManager.delete_slot(index)
	Global.change_scene(Global.Menu.MAIN_MENU)

func _reset_delete_labels() -> void:
	for key : Variant in _delete_buttons:
		(_delete_buttons[key] as Button).text = "menu.delete"
	_pending_delete = -1
