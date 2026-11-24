class_name CampaignSelectScreen
extends RunScreen

var saved : RunState
var first_button : Button
var new_button : Button
var _busy : bool = false

func requires_run() -> bool:
	return false

func screen_title() -> String:
	return "menu.select_campaign"

func screen_subtitle() -> String:
	return Loc.t("menu.slot") % SaveManager.slot

func _build() -> void:
	Global.run = null
	saved = SaveManager.load_run() if SaveManager.has_run() else null
	content.add_child(_label("menu.pick_how_you_want_to", 16, TEXT_SOFT))
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_child(row)
	row.add_child(_card("menu.new_campaign", CYAN, RunData.node_glyph(RunData.NodeType.BATTLE, "normal"),
			Loc.t("menu.a_sector_run_floors_and") % RunData.COLUMNS,
			"menu.replaces_your_saved_campaign" if saved else "menu.starts_a_fresh_run",
			"menu.start_new", _on_new, true))
	var continue_text : String = "menu.no_saved_campaign"
	if (saved):
		continue_text = Loc.t("menu.floor_base_hp_relics_screws") % [
				mini(saved.floors_cleared() + 1, RunData.COLUMNS), RunData.COLUMNS, saved.base_hp, saved.base_max_hp,
				saved.relics.size(), saved.screws]
	row.add_child(_card("menu.continue_campaign", AMBER, RunData.node_glyph(RunData.NodeType.SHIPYARD, "normal"),
			"menu.pick_up_the_run_where",
			continue_text, "menu.continue", _on_continue, saved != null))
	row.add_child(_card("menu.endless_waves", DANGER, RunData.node_glyph(RunData.NodeType.ELITE, "normal"),
			"menu.the_original_mode_survive_wave",
			Loc.t("menu.best_wave") % Global.player_stats.best_wave, "menu.play_endless", _on_classic, true))
	content.add_child(_spacer())
	content.add_child(_divider())
	var options : Button = _button("menu.options")
	options.custom_minimum_size.x = 220
	options.pressed.connect(Global.open_options)
	var back : Button = _button("menu.main_menu")
	back.custom_minimum_size.x = 220
	back.pressed.connect(func() -> void: Global.change_scene(Global.Menu.MAIN_MENU))
	content.add_child(_footer(back, options))
	var target : Button = first_button if first_button else options
	_defer_focus(target)

func _card(title : String, accent : Color, icon : Texture2D, text : String, note : String, button_text : String,
		action : Callable, enabled : bool) -> Control:
	var panel : PanelContainer = _panel(14)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 380)
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(_plate(title, TEXT, 16, accent))
	var art : CenterContainer = CenterContainer.new()
	art.custom_minimum_size.y = 96
	var well : PanelContainer = PanelContainer.new()
	well.add_theme_stylebox_override("panel", _flat_well())
	var glyph : TextureRect = TextureRect.new()
	glyph.texture = icon
	glyph.custom_minimum_size = Vector2(64, 64)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_SCALE
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	well.add_child(glyph)
	art.add_child(well)
	box.add_child(art)
	var body : Label = _wrapped(text, 12, TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	box.add_child(_divider())
	var note_label : Label = _wrapped(note, 11, TEXT_SOFT if enabled else TEXT_DIM)
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_label.custom_minimum_size.y = 40
	box.add_child(note_label)
	var button : Button = _button(button_text)
	button.disabled = !enabled
	button.pressed.connect(action)
	box.add_child(button)
	if (enabled and first_button == null):
		first_button = button
	return panel

func _flat_well() -> StyleBoxFlat:
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#10191f")
	style.border_color = Color("#2a3d46")
	style.set_border_width_all(1)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.anti_aliasing = false
	return style

func _pick(mode : Global.StartMode, new_run : bool) -> void:
	if (_busy):
		return
	_busy = true
	Global.start_mode = mode
	Global.start_new_campaign = new_run
	Global.change_scene(Global.Menu.SHOP)

func _on_new() -> void:
	_pick(Global.StartMode.CAMPAIGN, true)

func _on_continue() -> void:
	if (saved):
		_pick(Global.StartMode.CAMPAIGN, false)

func _on_classic() -> void:
	_pick(Global.StartMode.CLASSIC, true)
