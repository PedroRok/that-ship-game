class_name ShopMenu
extends Control

const FONT := preload("res://assets/fonts/dogicabold.ttf")
const PIXEL_FONT := preload("res://assets/fonts/dogicapixel.ttf")
const DISPLAY_SHADER := preload("res://shaders/digital_panel.gdshader")
const ART_TINT_SHADER := preload("res://shaders/unit_tint.gdshader")
const SILHOUETTE_SHADER := preload("res://shaders/silhouette.gdshader")
const SCREW_ICON := preload("res://assets/game/misc/screw.png")
const ICON_HP := preload("res://assets/ui/icons/hp_8x8_v01.png")
const ICON_SPEED := preload("res://assets/ui/icons/speed_8x8_v01.png")
const ICON_GUN := preload("res://assets/ui/icons/gun_8x8_v01.png")
const ICON_NAVAL := preload("res://assets/ui/icons/naval_8x8_v02.png")
const ICON_AIR := preload("res://assets/ui/icons/airship_8x8_v02.png")
const ICON_SUB := preload("res://assets/ui/icons/submarine_8x8_v01.png")
const ICON12_HP := preload("res://assets/ui/icons/hp_12x12_v01.png")
const ICON12_SPEED := preload("res://assets/ui/icons/speed_12x12_v01.png")
const ICON12_GUN := preload("res://assets/ui/icons/gun_turret_12x12_v04.png")
const ICON12_NAVAL := preload("res://assets/ui/icons/naval_12x12_v01.png")
const ICON12_AIR := preload("res://assets/ui/icons/airship_12x12_v03.png")
const ICON12_SUB := preload("res://assets/ui/icons/submarine_fleet_12x12_v05.png")
const GEAR_ICON := preload("res://assets/game/misc/gear.png")

const DISPLAY_REST := Color("#5fd9cf")
const DISPLAY_UNLOADED := Color("#1b4c4b")
const DISPLAY_LIGHT := Color("#b8fff6")
const DISPLAY_TEXT := Color("#9ad5ce")
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

const FILTERS : Array[String] = ["shop.all", "hud.naval", "hud.air", "hud.sub"]
const CARD_COLUMNS : int = 4

var selected : BoatStats
var filter : String = "shop.all"

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
var _weapon_scroll : ScrollContainer
var stats_expanded : bool = false
var detail_title : Label
var dock_slot : HBoxContainer

func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	set_anchors_preset(PRESET_TOP_LEFT)
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()
	var ui_theme : Theme = Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 8
	PixelControls.apply_theme(ui_theme)
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
	label.text = PixelText.fit(text, size)
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
		return "hud.sub"
	if (unit.unit_class == Enums.UnitClass.AIR):
		return "hud.air"
	return "hud.naval"

func _dock_icon(dock : String) -> Texture2D:
	return ICON_AIR if dock == "hud.air" else (ICON_SUB if dock == "hud.sub" else ICON_NAVAL)

func _dock_icon_12(dock : String) -> Texture2D:
	return ICON12_AIR if dock == "hud.air" else (ICON12_SUB if dock == "hud.sub" else ICON12_NAVAL)

func _icon_value(icon : Texture2D, text : String, color : Color = TEXT) -> HBoxContainer:
	var row : HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	row.add_child(_silhouette(icon, color))
	if (text != ""):
		row.add_child(_label(text, color))
	return row

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

func _currency_display(icon : Texture2D, factor : int, color : Color, value : Label) -> PanelContainer:
	var plate : PanelContainer = _panel(Color("#090f16"), STEEL)
	var screen : ColorRect = ColorRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var screen_material : ShaderMaterial = ShaderMaterial.new()
	screen_material.shader = DISPLAY_SHADER
	screen_material.set_shader_parameter("line_color", color)
	screen.material = screen_material
	screen.resized.connect(func() -> void: screen_material.set_shader_parameter("rect_size", screen.size))
	plate.add_child(screen)
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.custom_minimum_size.x = 56
	row.add_child(_silhouette(icon, color, factor))
	row.add_child(value)
	_margin(plate, 6).add_child(row)
	return plate

func _build_header() -> PanelContainer:
	var panel : PanelContainer = _framed_panel()
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_margin(panel, 10).add_child(row)
	var title : Label = _label("shop.fleet", TEXT, 32)
	title.add_theme_font_override("font", PIXEL_FONT)
	row.add_child(title)
	row.add_child(VSeparator.new())
	var gear_box : VBoxContainer = VBoxContainer.new()
	gear_box.add_theme_constant_override("separation", 4)
	gear_box.add_child(_label("run.gears", DIM))
	gear_label = _label("", Color("#ffe3a8"), 16)
	gear_box.add_child(_currency_display(GEAR_ICON, 2, AMBER, gear_label))
	row.add_child(gear_box)
	var start : VBoxContainer = VBoxContainer.new()
	start.add_theme_constant_override("separation", 4)
	start.add_child(_label("shop.starting", DIM))
	screw_label = _label("", DISPLAY_LIGHT, 16)
	start.add_child(_currency_display(SCREW_ICON, 2, DISPLAY_REST, screw_label))
	row.add_child(start)
	row.add_child(_spacer())
	for entry : Dictionary in [
			{"text": "shop.change_mode", "width": 150, "action": func() -> void: Global.change_scene(Global.Menu.CAMPAIGN_SELECT)},
			{"text": "research.research", "width": 130, "action": func() -> void: Global.change_scene(Global.Menu.RESEARCH)},
			{"text": "menu.options", "width": 130, "action": Global.open_options}]:
		var button : Button = Button.new()
		button.text = Loc.t(entry["text"])
		button.custom_minimum_size = Vector2(entry["width"], 34)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_skin(button)
		button.pressed.connect(entry["action"])
		row.add_child(button)
	return panel

func _build_catalog() -> PanelContainer:
	var col : VBoxContainer = _module("hud.unit_catalog", true)
	var panel : PanelContainer = col.get_meta("panel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_drag_forwarding(
		func(_at : Vector2) -> Variant: return null,
		func(_at : Vector2, data : Variant) -> bool: return _can_drop_remove(data),
		func(_at : Vector2, data : Variant) -> void: _drop_remove(data))
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
	var title_margin : Node = (col.get_child(0) as Node).get_child(0)
	detail_title = title_margin.get_child(0)
	title_margin.remove_child(detail_title)
	var title_row : HBoxContainer = HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(detail_title)
	title_row.add_child(_spacer())
	dock_slot = HBoxContainer.new()
	dock_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(dock_slot)
	title_margin.add_child(title_row)
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
	start.text = _start_text()
	start.custom_minimum_size = Vector2(190, 40)
	start.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skin(start, CYAN, Color("#1f4448"))
	start.pressed.connect(_on_start_pressed)
	row.add_child(start)
	return panel

func _make_portrait(unit : EntityStats, available : bool, min_height : float, max_factor : int, caption : String = "", show_header : bool = false, dock_text : bool = true, corner : String = "", corner_color : Color = DIM) -> PanelContainer:
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
	var pal : DisplayPalette = DisplayPalette.of_unit(unit)
	pal.apply_screen(screen_material)
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
		art_material.set_shader_parameter("tint", pal.rest if available else pal.unloaded)
		art.material = art_material
		stage.add_child(art)
		stage.resized.connect(_fit_art.bind(art, stage, max_factor))
	if (show_header and unit != null):
		var header_color : Color = pal.text if available else pal.text.darkened(0.55)
		var header : HBoxContainer = HBoxContainer.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_theme_constant_override("separation", 0)
		header.add_child(_silhouette(_dock_icon_12(_dock_of(unit)), header_color))
		if (dock_text):
			var dock_gap : Control = Control.new()
			dock_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dock_gap.custom_minimum_size.x = 3
			header.add_child(dock_gap)
			header.add_child(_label(_dock_of(unit), header_color))
		header.add_child(_spacer())
		header.add_child(_label(str(unit.price), header_color, 12))
		var gap : Control = Control.new()
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gap.custom_minimum_size.x = 2
		header.add_child(gap)
		header.add_child(_silhouette(SCREW_ICON, header_color, 2))
		stage.add_child(header)
		header.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
		header.offset_left = 3
		header.offset_right = -3
		header.offset_top = 3
		if (corner != ""):
			var corner_label : Label = _label(corner, corner_color)
			stage.add_child(corner_label)
			corner_label.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
			corner_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			corner_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
			corner_label.offset_right = -4
			corner_label.offset_top = -11.0
			corner_label.offset_bottom = 2.0
	if (caption != ""):
		var tag : Label = _label(caption, pal.light)
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
		if (filter == "shop.all" or filter == _dock_of(unit)):
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
	button.set_drag_forwarding(
		func(_at : Vector2) -> Variant: return _unit_drag_data(unit.name, stats.loadout.find(unit.name), button),
		func(_at : Vector2, _data : Variant) -> bool: return false,
		func(_at : Vector2, _data : Variant) -> void: pass)
	var col : VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 3)
	_margin(button, 5).add_child(col)
	button.get_child(0).set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var title : Label = _label(Loc.named("unit", unit.name).to_upper())
	title.modulate = Color.WHITE if available else Color(0.65, 0.68, 0.7)
	col.add_child(title)
	var corner : String = Loc.t("research.gears") % unit.unlock_cost
	var corner_color : Color = AMBER
	if (stats.has_boat(unit.name)):
		var slot : int = stats.loadout.find(unit.name)
		corner = Loc.t("menu.slot") % (slot + 1) if slot >= 0 else "shop.owned"
		corner_color = DIM if slot >= 0 else CYAN
	col.add_child(_make_portrait(unit, available, 60, 2, "", true, true, corner, corner_color))
	return button

func _refresh_detail() -> void:
	detail_title.text = Loc.named("unit", selected.name).to_upper() if selected else "shop.no_unit"
	_clear(dock_slot)
	if (selected != null):
		dock_slot.add_child(_silhouette(_dock_icon_12(_dock_of(selected)), DIM))
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
	var sim_pal : DisplayPalette = DisplayPalette.of_unit(selected)
	sim_tag.add_theme_color_override("font_color", sim_pal.light)
	if (sim_overlay):
		sim_pal.apply_overlay(sim_overlay.material as ShaderMaterial)
	sim_tag.text = Loc.t("shop.unit") % Loc.t(_dock_of(selected))
	sim_well.modulate = Color.WHITE if _is_available(selected) else Color(0.72, 0.74, 0.78)
	if (sim_overlay):
		(sim_overlay.material as ShaderMaterial).set_shader_parameter("band_strength", 1.0 if _is_available(selected) else 0.0)
	if (sim_unit != selected):
		sim_unit = selected
		sim.show_unit(upgraded)
	var rows : Array = [
		["HP", "%.1f" % upgraded.health, ICON_HP],
		["shop.speed", "%.1f" % upgraded.speed, ICON_SPEED],
		["shop.gun_slots", str(upgraded.gun_slots.size()), ICON_GUN],
		["shop.dock", _dock_of(selected), _dock_icon(_dock_of(selected))],
	]
	var summary_panel : PanelContainer = _panel(ROW, ROW)
	var summary : HBoxContainer = HBoxContainer.new()
	summary.add_theme_constant_override("separation", 10)
	_margin(summary_panel, 4).add_child(summary)
	summary.add_child(_icon_value(ICON12_HP, "%.0f" % upgraded.health))
	summary.add_child(_icon_value(ICON12_SPEED, "%.1f" % upgraded.speed))
	summary.add_child(_icon_value(ICON12_GUN, "%d" % upgraded.gun_slots.size()))
	summary.add_child(_spacer())
	summary.add_child(_screw_value(selected.price, TEXT))
	var toggle : Button = Button.new()
	toggle.text = "-" if stats_expanded else "+"
	toggle.custom_minimum_size = Vector2(22, 20)
	_skin(toggle, CYAN, Color("#1f4448"))
	toggle.pressed.connect(_toggle_stats)
	summary.add_child(toggle)
	detail_box.add_child(summary_panel)
	if (stats_expanded):
		var stat_col : VBoxContainer = VBoxContainer.new()
		stat_col.add_theme_constant_override("separation", 2)
		for entry : Array in rows:
			var row_panel : PanelContainer = _panel(ROW, ROW)
			var row : HBoxContainer = HBoxContainer.new()
			_margin(row_panel, 5).add_child(row)
			row.add_child(_icon_value(entry[2], entry[0], DIM))
			row.add_child(_spacer())
			row.add_child(_label(entry[1]))
			stat_col.add_child(row_panel)
		detail_box.add_child(stat_col)
		var cost : HBoxContainer = HBoxContainer.new()
		cost.add_theme_constant_override("separation", 10)
		cost.add_child(_label("shop.build_cost", DIM))
		cost.add_child(_screw_value(selected.price, TEXT))
		var cost_margin : MarginContainer = MarginContainer.new()
		cost_margin.add_theme_constant_override("margin_left", 5)
		cost_margin.add_child(cost)
		detail_box.add_child(cost_margin)
	_add_weapon_selector(upgraded)
	var action : Button = Button.new()
	action.custom_minimum_size = Vector2(0, 30)
	if (stats.has_boat(selected.name)):
		var equipped : bool = stats.in_loadout(selected.name)
		action.text = "shop.remove_from_loadout" if equipped else "shop.add_to_loadout"
		action.disabled = !equipped and stats.loadout_count() >= loadout_limit()
		_skin(action, CYAN, Color("#1f4448"))
		action.pressed.connect(_toggle_loadout.bind(selected))
	else:
		action.text = Loc.t("shop.unlock_gears") % selected.unlock_cost
		action.disabled = !stats.can_buy(selected.unlock_cost)
		_skin(action, AMBER, Color("#3a3220"))
		action.add_theme_color_override("font_color", AMBER)
		action.pressed.connect(_buy_unit.bind(selected))
	detail_box.add_child(action)

func _add_weapon_selector(unit : EntityStats) -> void:
	var stats : PlayerStats = Global.player_stats
	_weapon_scroll = ScrollContainer.new()
	_weapon_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_weapon_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_box.add_child(_weapon_scroll)
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
		row.add_child(_label("shop.weapon", DIM))
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
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin : MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	_weapon_scroll.add_child(margin)

func _cycle_weapon(unit : EntityStats, slot_index : int, options : Array[int], new_index : int) -> void:
	var wrapped : int = posmod(new_index, options.size())
	Global.player_stats.set_gun_choice(unit.name, slot_index, options[wrapped])
	Global.save_game()
	sim_unit = null
	_refresh_all()

func _refresh_loadout() -> void:
	var stats : PlayerStats = Global.player_stats
	var limit : int = loadout_limit()
	loadout_title.text = Loc.t("shop.loadout") % [stats.loadout_count(), limit]
	_clear(slots_row)
	var start_screws : int = _start_screws()
	for index : int in range(limit):
		slots_row.add_child(_make_slot(index, _slot_unit(index), start_screws))

func _slot_unit(index : int) -> EntityStats:
	var stats : PlayerStats = Global.player_stats
	if (index >= stats.loadout.size() or stats.loadout[index] == ""):
		return null
	for item : Variant in stats.unlocked_entities:
		if ((item as EntityStats).name == stats.loadout[index]):
			return item
	return null

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
		button.pressed.connect(_drop_on_slot.bind({"unit": selected.name, "from": -1}, index))
	var unit_name : String = unit.name if unit != null else ""
	button.set_drag_forwarding(
		func(_at : Vector2) -> Variant: return _unit_drag_data(unit_name, index, button) if unit_name != "" else null,
		func(_at : Vector2, data : Variant) -> bool: return _can_drop_on_slot(data),
		func(_at : Vector2, data : Variant) -> void: _drop_on_slot(data, index))
	var col : VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	_margin(button, 3).add_child(col)
	button.get_child(0).set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	col.add_child(_label(str(index + 1), DIM))
	if (unit != null):
		col.add_child(_make_portrait(unit, usable, 30, 1, "", true, false))
		var name_label : Label = _label(Loc.named("unit", unit.name).to_upper())
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.modulate = Color.WHITE if usable else Color(0.65, 0.68, 0.7)
		col.add_child(name_label)
	else:
		var plus : Label = _label("+", Color("#7f8b90"), 16)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.size_flags_vertical = Control.SIZE_EXPAND_FILL
		plus.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		col.add_child(plus)
		var empty : Label = _label("hud.empty", Color("#7f8b90"))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(empty)
	return button


func _toggle_stats() -> void:
	stats_expanded = !stats_expanded
	_refresh_detail()

func _unit_drag_data(unit_name : String, from_slot : int, source : Control) -> Variant:
	var unit : BoatStats = null
	for item : Variant in Global.CATALOG.units:
		if ((item as BoatStats).name == unit_name):
			unit = item
	if (unit == null or !Global.player_stats.has_boat(unit_name)):
		return null
	var copy : Control
	if (from_slot >= 0):
		copy = _make_slot(from_slot, unit, _start_screws())
	else:
		copy = _make_card(unit)
	copy.custom_minimum_size = source.size
	copy.size = source.size
	_freeze(copy)
	copy.modulate = Color(1, 1, 1, 0.9)
	var holder : Control = Control.new()
	holder.add_child(copy)
	copy.position = -source.size / 2.0
	source.set_drag_preview(holder)
	_blank_source(source)
	return {"unit": unit_name, "from": from_slot}

func _blank_source(source : Control) -> void:
	var fresh : Button = _make_empty_card()
	for child : Node in source.get_children():
		source.remove_child(child)
		child.queue_free()
	for child : Node in fresh.get_children():
		fresh.remove_child(child)
		source.add_child(child)
	for state : String in ["normal", "hover", "pressed", "disabled", "focus"]:
		source.add_theme_stylebox_override(state, fresh.get_theme_stylebox(state))
	fresh.free()

func _make_empty_card() -> Button:
	var button : Button = Button.new()
	button.custom_minimum_size = Vector2(0, 112)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var face : Color = Color("#141b1f")
	var edge : Color = Color("#3a464c")
	_skin(button, edge, face)
	button.add_theme_stylebox_override("disabled", _style(face, edge))
	var holder : MarginContainer = _margin(button, 5)
	holder.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var empty : Label = _label("hud.empty", Color("#7f8b90"))
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(empty)
	return button

func _freeze(node : Node) -> void:
	if (node is Control):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(node as Control).set_drag_forwarding(Callable(), Callable(), Callable())
	for child : Node in node.get_children():
		_freeze(child)

func _notification(what : int) -> void:
	if (what == NOTIFICATION_DRAG_END and grid != null and is_inside_tree()):
		_refresh_all.call_deferred()

func _can_drop_on_slot(data : Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("unit")

func _drop_on_slot(data : Variant, slot_index : int) -> void:
	var info : Dictionary = data
	if (Global.player_stats.place_in_loadout(str(info["unit"]), slot_index, loadout_limit())):
		Global.save_game()
		_refresh_all()

func _can_drop_remove(data : Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("unit") and int((data as Dictionary)["from"]) >= 0

func _drop_remove(data : Variant) -> void:
	var info : Dictionary = data
	var stats : PlayerStats = Global.player_stats
	if (stats.in_loadout(str(info["unit"]))):
		stats.toggle_loadout(str(info["unit"]))
		Global.save_game()
		_refresh_all()

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
	if (!stats.in_loadout(unit.name) and stats.loadout_count() >= loadout_limit()):
		return
	if (stats.toggle_loadout(unit.name)):
		Global.save_game()
	_refresh_all()

func _start_text() -> String:
	if (Global.start_mode == Global.StartMode.CAMPAIGN):
		return "menu.continue_campaign" if !Global.start_new_campaign else "shop.start_campaign"
	return "shop.start_endless"

func _on_start_pressed() -> void:
	if (Global.start_mode == Global.StartMode.CAMPAIGN):
		if (Global.start_new_campaign):
			RunFlow.start_new_run()
		else:
			RunFlow.continue_run()
		return
	Global.change_scene(Global.Menu.GAME)

func _on_button_button_down() -> void:
	Global.change_scene(Global.Menu.GAME)
