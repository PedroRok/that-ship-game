class_name ShopMenu
extends Control

const FONT := preload("res://assets/fonts/dogicabold.ttf")
const PIXEL_FONT := preload("res://assets/fonts/dogicapixel.ttf")
const DISPLAY_SHADER := preload("res://shaders/digital_panel.gdshader")
const ART_TINT_SHADER := preload("res://shaders/unit_tint.gdshader")
const SILHOUETTE_SHADER := preload("res://shaders/silhouette.gdshader")
const SCREW_ICON := preload("res://assets/game/misc/screw.png")
const GEAR_ICON := preload("res://assets/game/misc/gear.png")

const DISPLAY_REST := Color("#5fd9cf")
const DISPLAY_UNLOADED := Color("#1b4c4b")
const DISPLAY_LIGHT := Color("#b8fff6")
const BG := Color("#0b1419")
const PANEL := Color("#151f25")
const STEEL := Color("#34454f")
const EDGE := Color("#596a73")
const CYAN := Color("#70d6d3")
const AMBER := Color("#e6b35d")
const DIM := Color("#c4cdd0")
const TEXT := Color("#e8f1f2")
const ROW := Color("#1c2a32")

const DEMO := preload("res://scenes/ui/naval_hud/battle_sandbox.gd")
const SIM_SCALE : int = 2
const SIM_DIGITAL_SCREEN : bool = true

const FILTERS : Array[String] = ["ALL", "NAVAL", "AIR", "SUB"]
const CARD_COLUMNS : int = 4

var selected : BoatStats
var filter : String = "ALL"

var gear_label : Label
var screw_label : Label
var filter_buttons : Dictionary = {}
var grid : GridContainer
var detail_box : VBoxContainer
var sim : DEMO
var sim_well : PanelContainer
var sim_tag : Label
var sim_unit : EntityStats
var sim_overlay : ColorRect
var loadout_title : Label
var slots_row : HBoxContainer

func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	set_anchors_preset(PRESET_TOP_LEFT)
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()
	var ui_theme : Theme = Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 8
	theme = ui_theme
	if (!Global.CATALOG.units.is_empty()):
		selected = Global.CATALOG.units[0]
	_build()
	_refresh_all()

func _fit_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size

func loadout_limit() -> int:
	return PlayerStats.MAX_LOADOUT


func _style(fill : Color, border : Color, thickness : int = 1) -> StyleBoxFlat:
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(thickness)
	style.anti_aliasing = false
	return style

func _skin(button : Button, edge : Color = Color("#72838d"), face : Color = Color("#293740")) -> void:
	button.add_theme_stylebox_override("normal", _style(face, edge))
	button.add_theme_stylebox_override("hover", _style(face.lightened(0.10), edge.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _style(face.darkened(0.25), edge))
	button.add_theme_stylebox_override("disabled", _style(Color("#20292e"), Color("#47545a")))
	var focus : StyleBoxFlat = _style(Color.TRANSPARENT, CYAN)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_disabled_color", Color("#7f8b90"))

func _panel(color : Color = PANEL, edge : Color = Color("#2a3b44")) -> PanelContainer:
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(color, edge))
	return panel

func _framed_panel() -> PanelContainer:
	var panel : PanelContainer = PanelContainer.new()
	var box : StyleBoxTexture = MenuBackground.make_box()
	for side : String in ["left", "right", "top", "bottom"]:
		box.set("content_margin_" + side, 10.0)
	panel.add_theme_stylebox_override("panel", box)
	return panel

func _margin(parent : Node, px : int) -> MarginContainer:
	var margin : MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side : String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, px)
	parent.add_child(margin)
	return margin

func _label(text : String = "", color : Color = TEXT, size : int = 8) -> Label:
	var label : Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	if (size != 8):
		label.add_theme_font_size_override("font_size", size)
	return label

func _spacer() -> Control:
	var spacer : Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer

func _module(title : String, framed : bool = false) -> VBoxContainer:
	var panel : PanelContainer = _framed_panel() if framed else _panel()
	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_margin(panel, 4).add_child(col)
	var plate : PanelContainer = _panel(STEEL, EDGE)
	plate.custom_minimum_size.y = 20
	var heading : Label = _label(title, Color("#c5dbdd"))
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_margin(plate, 6).add_child(heading)
	col.add_child(plate)
	col.set_meta("panel", panel)
	return col

func _silhouette(texture : Texture2D, color : Color, factor : int = 1) -> TextureRect:
	var icon : TextureRect = TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.custom_minimum_size = Vector2(texture.get_size()) * factor
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material : ShaderMaterial = ShaderMaterial.new()
	material.shader = SILHOUETTE_SHADER
	material.set_shader_parameter("tint", color)
	icon.material = material
	return icon

func _screw_value(value : int, color : Color, size : int = 8, factor : int = 1) -> HBoxContainer:
	var row : HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	row.add_child(_label(str(value), color, size))
	row.add_child(_silhouette(SCREW_ICON, color, factor))
	return row


func _dock_of(unit : EntityStats) -> String:
	var boat : BoatStats = unit as BoatStats
	if (boat != null and boat.can_submerge):
		return "SUB"
	if (unit.unit_class == Enums.UnitClass.AIR):
		return "AIR"
	return "NAVAL"

func _start_screws() -> int:
	return int(Global.modify(Enums.UpgradeTarget.BASE, &"start_screw", Global.player_stats.start_screw))

func _is_available(unit : BoatStats) -> bool:
	var stats : PlayerStats = Global.player_stats
	if (stats.has_boat(unit.name)):
		return !stats.in_loadout(unit.name)
	return stats.can_buy(unit.unlock_cost)


func _build() -> void:
	add_child(MenuBackground.new())
	var outer : MarginContainer = _margin(self, 18)
	outer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var page : VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	outer.add_child(page)
	page.add_child(_build_header())
	var main : HBoxContainer = HBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(main)
	main.add_child(_build_catalog())
	main.add_child(_build_detail())
	page.add_child(_build_loadout())

func _build_header() -> PanelContainer:
	var panel : PanelContainer = _framed_panel()
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_margin(panel, 10).add_child(row)
	var title : Label = _label("FLEET", TEXT, 32)
	title.add_theme_font_override("font", PIXEL_FONT)
	row.add_child(title)
	row.add_child(VSeparator.new())
	var gears : VBoxContainer = VBoxContainer.new()
	gears.add_theme_constant_override("separation", 4)
	gears.add_child(_label("GEARS", DIM))
	var gear_row : HBoxContainer = HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", 6)
	gear_label = _label("", TEXT, 16)
	gear_row.add_child(_silhouette(GEAR_ICON, EDGE, 2))
	gear_row.add_child(gear_label)
	gears.add_child(gear_row)
	row.add_child(gears)
	var start : VBoxContainer = VBoxContainer.new()
	start.add_theme_constant_override("separation", 4)
	var start_title : HBoxContainer = HBoxContainer.new()
	start_title.add_theme_constant_override("separation", 4)
	start_title.add_child(_label("STARTING", DIM))
	start_title.add_child(_silhouette(SCREW_ICON, DIM, 1))
	start.add_child(start_title)
	screw_label = _label("", TEXT, 16)
	start.add_child(screw_label)
	row.add_child(start)
	row.add_child(_spacer())
	for entry : Dictionary in [
			{"text": "RESEARCH", "width": 130, "action": func() -> void: Global.change_scene(Global.Menu.RESEARCH)},
			{"text": "OPTIONS", "width": 130, "action": Global.open_options}]:
		var button : Button = Button.new()
		button.text = entry["text"]
		button.custom_minimum_size = Vector2(entry["width"], 34)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_skin(button)
		button.pressed.connect(entry["action"])
		row.add_child(button)
	return panel

func _build_catalog() -> PanelContainer:
	var col : VBoxContainer = _module("UNIT CATALOG", true)
	var panel : PanelContainer = col.get_meta("panel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar : HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	col.add_child(bar)
	for key : String in FILTERS:
		var button : Button = Button.new()
		button.text = key
		button.custom_minimum_size = Vector2(72, 22)
		button.pressed.connect(_set_filter.bind(key))
		bar.add_child(button)
		filter_buttons[key] = button
	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = CARD_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 11)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	return panel

func _build_detail() -> PanelContainer:
	var col : VBoxContainer = _module("", true)
	var panel : PanelContainer = col.get_meta("panel")
	panel.custom_minimum_size.x = 412
	detail_box = col
	sim_well = _panel(Color("#4d6069"), Color("#172127"))
	var stage : Control = Control.new()
	var sim_size : Vector2 = Vector2(DEMO.VIEW) * SIM_SCALE
	stage.custom_minimum_size = sim_size
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sim = DEMO.new()
	sim.team_outlines = false
	sim.scale = Vector2(SIM_SCALE, SIM_SCALE)
	stage.add_child(sim)
	stage.resized.connect(func() -> void: sim.position = ((stage.size - sim_size) / 2.0).floor())
	if (SIM_DIGITAL_SCREEN):
		var overlay : ColorRect = DEMO.make_digital_overlay()
		sim_overlay = overlay
		stage.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	sim_tag = _label("", DISPLAY_LIGHT)
	sim_tag.position = Vector2(8, 6)
	stage.add_child(sim_tag)
	sim_well.add_child(stage)
	col.add_child(sim_well)
	return panel

func _build_loadout() -> PanelContainer:
	var col : VBoxContainer = _module("", true)
	var panel : PanelContainer = col.get_meta("panel")
	panel.custom_minimum_size.y = 126
	var plate : PanelContainer = col.get_child(0)
	loadout_title = plate.get_child(0).get_child(0)
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	slots_row = HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 8)
	slots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slots_row)
	var start : Button = Button.new()
	start.text = "START RUN"
	start.custom_minimum_size = Vector2(132, 40)
	start.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skin(start, CYAN, Color("#1f4448"))
	start.pressed.connect(_on_button_button_down)
	row.add_child(start)
	return panel


func _make_portrait(unit : EntityStats, available : bool, min_height : float, max_factor : int, caption : String = "") -> PanelContainer:
	var well : PanelContainer = _panel(Color("#4d6069") if available else Color("#2f3c43"), Color("#172127"))
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.custom_minimum_size.y = min_height
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	well.modulate = Color.WHITE if available else Color(0.72, 0.74, 0.78)
	var stage : Control = Control.new()
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(stage)
	var screen : ColorRect = ColorRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var screen_material : ShaderMaterial = ShaderMaterial.new()
	screen_material.shader = DISPLAY_SHADER
	screen.material = screen_material
	screen.resized.connect(func() -> void: screen_material.set_shader_parameter("rect_size", screen.size))
	if (!available or unit == null):
		screen_material.set_shader_parameter("band_strength", 0.0)
	stage.add_child(screen)
	screen.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if (unit != null):
		var art : TextureRect = TextureRect.new()
		art.texture = unit.sprite
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var art_material : ShaderMaterial = ShaderMaterial.new()
		art_material.shader = ART_TINT_SHADER
		art_material.set_shader_parameter("tint", DISPLAY_REST if available else DISPLAY_UNLOADED)
		art.material = art_material
		stage.add_child(art)
		stage.resized.connect(_fit_art.bind(art, stage, max_factor))
	if (caption != ""):
		var tag : Label = _label(caption, DISPLAY_LIGHT)
		tag.position = Vector2(8, 6)
		stage.add_child(tag)
	return well

func _fit_art(art : TextureRect, stage : Control, max_factor : int) -> void:
	if (art.texture == null):
		return
	var native : Vector2 = art.texture.get_size()
	var factor : int = clampi(int(minf(stage.size.x / native.x, stage.size.y / native.y)), 1, max_factor)
	art.size = native * factor
	art.position = ((stage.size - art.size) / 2.0).floor()


func _clear(node : Node) -> void:
	for child : Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _refresh_all() -> void:
	var stats : PlayerStats = Global.player_stats
	gear_label.text = str(stats.gear)
	screw_label.text = str(_start_screws())
	for key : String in filter_buttons:
		var button : Button = filter_buttons[key]
		_skin(button, CYAN if key == filter else Color("#72838d"), Color("#1f4448") if key == filter else Color("#293740"))
	_refresh_catalog()
	_refresh_detail()
	_refresh_loadout()

func _refresh_catalog() -> void:
	_clear(grid)
	for item : Variant in Global.CATALOG.units:
		var unit : BoatStats = item
		if (filter == "ALL" or filter == _dock_of(unit)):
			grid.add_child(_make_card(unit))

func _make_card(unit : BoatStats) -> Button:
	var stats : PlayerStats = Global.player_stats
	var available : bool = _is_available(unit)
	var picked : bool = unit == selected
	var button : Button = Button.new()
	button.custom_minimum_size = Vector2(0, 112)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var edge : Color = CYAN if picked else (Color("#72838d") if available else Color("#3a464c"))
	var face : Color = Color("#293740") if available else Color("#141b1f")
	_skin(button, edge, face)
	button.add_theme_stylebox_override("disabled", _style(face, edge))
	button.pressed.connect(_select.bind(unit))
	var col : VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 3)
	_margin(button, 5).add_child(col)
	button.get_child(0).set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var title : Label = _label(unit.name.to_upper())
	title.modulate = Color.WHITE if available else Color(0.65, 0.68, 0.7)
	col.add_child(title)
	col.add_child(_make_portrait(unit, available, 60, 2))
	var footer : HBoxContainer = HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_label(_dock_of(unit), DIM))
	footer.add_child(_spacer())
	if (stats.has_boat(unit.name)):
		var slot : int = stats.loadout.find(unit.name)
		footer.add_child(_label("SLOT %d" % (slot + 1) if slot >= 0 else "OWNED", CYAN if slot < 0 else DIM))
	else:
		footer.add_child(_label("%d GEARS" % unit.unlock_cost, AMBER))
	col.add_child(footer)
	return button

func _refresh_detail() -> void:
	var plate : PanelContainer = detail_box.get_child(0)
	(plate.get_child(0).get_child(0) as Label).text = selected.name.to_upper() if selected else "NO UNIT"
	while (detail_box.get_child_count() > 2):
		var old : Node = detail_box.get_child(2)
		detail_box.remove_child(old)
		old.queue_free()
	if (selected == null):
		sim.show_unit(null)
		sim_unit = null
		sim_tag.text = ""
		if (sim_overlay):
			(sim_overlay.material as ShaderMaterial).set_shader_parameter("band_strength", 0.0)
		return
	var stats : PlayerStats = Global.player_stats
	var upgraded : EntityStats = Global.upgraded_entity(selected)
	sim_tag.text = "%s UNIT" % _dock_of(selected)
	sim_well.modulate = Color.WHITE if _is_available(selected) else Color(0.72, 0.74, 0.78)
	if (sim_overlay):
		(sim_overlay.material as ShaderMaterial).set_shader_parameter("band_strength", 1.0 if _is_available(selected) else 0.0)
	if (sim_unit != selected):
		sim_unit = selected
		sim.show_unit(upgraded)
	var rows : Array = [
		["HP", "%.1f" % upgraded.health],
		["SPEED", "%.1f" % upgraded.speed],
		["GUN SLOTS", str(upgraded.gun_slots.size())],
		["DOCK", _dock_of(selected)],
	]
	var stat_col : VBoxContainer = VBoxContainer.new()
	stat_col.add_theme_constant_override("separation", 2)
	for entry : Array in rows:
		var row_panel : PanelContainer = _panel(ROW, ROW)
		var row : HBoxContainer = HBoxContainer.new()
		_margin(row_panel, 5).add_child(row)
		row.add_child(_label(entry[0], DIM))
		row.add_child(_spacer())
		row.add_child(_label(entry[1]))
		stat_col.add_child(row_panel)
	detail_box.add_child(stat_col)
	var cost : HBoxContainer = HBoxContainer.new()
	cost.add_theme_constant_override("separation", 10)
	cost.add_child(_label("BUILD COST", DIM))
	cost.add_child(_screw_value(selected.price, TEXT))
	var cost_margin : MarginContainer = MarginContainer.new()
	cost_margin.add_theme_constant_override("margin_left", 5)
	cost_margin.add_child(cost)
	detail_box.add_child(cost_margin)
	_add_weapon_selector(upgraded)
	detail_box.add_child(_spacer())
	var action : Button = Button.new()
	action.custom_minimum_size = Vector2(0, 30)
	if (stats.has_boat(selected.name)):
		var equipped : bool = stats.in_loadout(selected.name)
		action.text = "REMOVE FROM LOADOUT" if equipped else "ADD TO LOADOUT"
		action.disabled = !equipped and stats.loadout.size() >= loadout_limit()
		_skin(action, CYAN, Color("#1f4448"))
		action.pressed.connect(_toggle_loadout.bind(selected))
	else:
		action.text = "UNLOCK  %d GEARS" % selected.unlock_cost
		action.disabled = !stats.can_buy(selected.unlock_cost)
		_skin(action, AMBER, Color("#3a3220"))
		action.add_theme_color_override("font_color", AMBER)
		action.pressed.connect(_buy_unit.bind(selected))
	detail_box.add_child(action)

func _add_weapon_selector(unit : EntityStats) -> void:
	var stats : PlayerStats = Global.player_stats
	if (!stats.has_boat(unit.name)):
		return
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	for slot_index : int in range(unit.gun_slots.size()):
		var options : Array[int] = stats.gun_options(unit.name, unit.gun_slots[slot_index], Global.CATALOG)
		if (options.size() < 2):
			continue
		var current : int = Global.gun_type_for(unit.name, slot_index, unit.gun_slots[slot_index])
		var index : int = maxi(0, options.find(current))
		var row : HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_label("WEAPON", DIM))
		row.add_child(_spacer())
		for step : int in [-1, 1]:
			var arrow : Button = Button.new()
			arrow.text = "<" if step < 0 else ">"
			arrow.custom_minimum_size = Vector2(26, 22)
			_skin(arrow, CYAN, Color("#1f4448"))
			arrow.pressed.connect(_cycle_weapon.bind(unit, slot_index, options, index + step))
			row.add_child(arrow)
			if (step < 0):
				var name_label : Label = _label(Enums.gun_name(current), TEXT)
				name_label.custom_minimum_size.x = 150
				name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				row.add_child(name_label)
		box.add_child(row)
		var desc : Label = _label(Enums.gun_description(current), DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc)
	if (box.get_child_count() == 0):
		box.free()
		return
	var margin : MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_child(box)
	detail_box.add_child(margin)

func _cycle_weapon(unit : EntityStats, slot_index : int, options : Array[int], new_index : int) -> void:
	var wrapped : int = posmod(new_index, options.size())
	Global.player_stats.set_gun_choice(unit.name, slot_index, options[wrapped])
	Global.save_game()
	sim_unit = null
	_refresh_all()

func _refresh_loadout() -> void:
	var stats : PlayerStats = Global.player_stats
	var entities : Array[EntityStats] = stats.loadout_entities()
	var limit : int = loadout_limit()
	loadout_title.text = "LOADOUT   %d / %d" % [entities.size(), limit]
	_clear(slots_row)
	var start_screws : int = _start_screws()
	for index : int in range(limit):
		var unit : EntityStats = entities[index] if index < entities.size() else null
		slots_row.add_child(_make_slot(index, unit, start_screws))

func _make_slot(index : int, unit : EntityStats, start_screws : int) -> Button:
	var button : Button = Button.new()
	button.custom_minimum_size = Vector2(0, 78)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var usable : bool = unit != null and unit.price <= start_screws
	_skin(button, Color("#72838d") if unit != null else Color("#3a464c"), Color("#293740") if unit != null else Color("#141b1f"))
	button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("normal"))
	if (unit != null):
		button.pressed.connect(_toggle_loadout.bind(unit))
	elif (selected != null):
		button.pressed.connect(_toggle_loadout.bind(selected))
	var col : VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	_margin(button, 3).add_child(col)
	button.get_child(0).set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	col.add_child(_label(str(index + 1), DIM))
	if (unit != null):
		col.add_child(_make_portrait(unit, usable, 30, 1))
		var name_label : Label = _label(unit.name.to_upper())
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.modulate = Color.WHITE if usable else Color(0.65, 0.68, 0.7)
		col.add_child(name_label)
		var center : CenterContainer = CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(_screw_value(unit.price, DISPLAY_LIGHT if usable else DIM))
		col.add_child(center)
	else:
		var plus : Label = _label("+", Color("#7f8b90"), 16)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.size_flags_vertical = Control.SIZE_EXPAND_FILL
		plus.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		col.add_child(plus)
		var empty : Label = _label("EMPTY", Color("#7f8b90"))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(empty)
	return button


func _set_filter(key : String) -> void:
	filter = key
	_refresh_all()

func _select(unit : BoatStats) -> void:
	selected = unit
	_refresh_all()

func _buy_unit(unit : BoatStats) -> void:
	if (!Global.player_stats.buy(unit.unlock_cost, unit)):
		return
	Global.save_game()
	_refresh_all()

func _toggle_loadout(unit : EntityStats) -> void:
	var stats : PlayerStats = Global.player_stats
	if (!stats.in_loadout(unit.name) and stats.loadout.size() >= loadout_limit()):
		return
	if (stats.toggle_loadout(unit.name)):
		Global.save_game()
	_refresh_all()

func _on_button_button_down() -> void:
	Global.change_scene(Global.Menu.GAME)
