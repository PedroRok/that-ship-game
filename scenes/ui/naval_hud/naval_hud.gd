extends Control

signal open_menu

const DEMO := preload("res://scenes/ui/naval_hud/battle_sandbox.gd")
const FONT := preload("res://assets/fonts/dogicabold.ttf")
const PIXEL_FONT := preload("res://assets/fonts/dogicapixel.ttf")
const SCREW := preload("res://assets/game/misc/screw.png")
const GEAR := preload("res://assets/game/misc/gear.png")
const PANEL := Color("#151f25")
const STEEL := Color("#34454f")
const EDGE := Color("#596a73")
const CYAN := Color("#a4d7d4")
const AMBER := Color("#e6b35d")
const PINK := Color("#d7a4a0")
const DIM := Color("#c4cdd0")
const CAM_SIZE := Vector2i(84, 41)

var round_scene: GameRound
var legacy: GameUI
var roster: Array[EntityStats]
var cards: Array[Button]
var card_status: Array[Label]
var card_wells: Array[PanelContainer]
var card_art_materials: Array[ShaderMaterial]
var card_screen_materials: Array[ShaderMaterial]
var demo_overlay: ColorRect
var card_titles: Array[Label]
var selected: int = -1
var ally_hp: ProgressBar
var enemy_hp: ProgressBar
var ally_caption: Label
var enemy_caption: Label
var wave_caption: Label
var dock_status: Dictionary = {}
var dock_viewports: Dictionary = {}
var dock_panels: Dictionary = {}
var last_dock_states: Dictionary = {}
var completion_until: Dictionary = {}
var menu: Button
var demo: DEMO
var demo_title: Label
var stat_buttons: Dictionary = {}
var last_reasons: Array[String]
var bottom_panel: PanelContainer
var top_panel: PanelContainer
var hover_stat: StringName
var focused_stat: StringName

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var hud_theme := Theme.new()
	hud_theme.default_font = FONT
	hud_theme.default_font_size = 8
	theme = hud_theme
	roster = Global.player_stats.loadout_entities()
	_make_header()
	_make_console()
	_select(0 if not roster.is_empty() else -1)

func _style(fill: Color, border: Color, thickness: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(thickness)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.anti_aliasing = false
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _skin(button: Button, active: bool = true, highlighted: bool = false) -> void:
	var edge: Color = AMBER if highlighted else (Color("#72838d") if active else Color("#47545a"))
	var face: Color = Color("#293740") if active else Color("#20292e")
	button.add_theme_stylebox_override("normal", _style(face, edge))
	button.add_theme_stylebox_override("hover", _style(face.lightened(0.10), edge.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _style(face.darkened(0.25), edge))
	button.add_theme_stylebox_override("disabled", _style(Color("#20292e"), edge))
	var focus := _style(Color.TRANSPARENT, Color("#70d6d3"))
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_disabled_color", DIM)

func _skin_card(button: Button, available: bool, picked: bool) -> void:
	var edge: Color = AMBER if picked else (Color("#72838d") if available else Color("#3a464c"))
	var face: Color = Color("#293740") if available else Color("#141b1f")
	var lift: float = 0.10 if available else 0.04
	button.add_theme_stylebox_override("normal", _style(face, edge))
	button.add_theme_stylebox_override("hover", _style(face.lightened(lift), edge.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _style(face.darkened(0.35), edge.darkened(0.2)))
	button.add_theme_stylebox_override("disabled", _style(face, edge))
	var focus := _style(Color.TRANSPARENT, Color("#70d6d3"), 2)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)

func _label(value: String = "", centered: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = MOUSE_FILTER_IGNORE
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _panel(color: Color = PANEL, edge: Color = EDGE) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(color, edge))
	return panel

func _margin(parent: Control, px: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, px)
	parent.add_child(margin)
	if parent is BaseButton:
		margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return margin

func _column(parent: Control, gap: int = 3) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", gap)
	parent.add_child(col)
	return col

func _row(parent: Control, gap: int = 4) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", gap)
	parent.add_child(row)
	return row

func _make_header() -> void:
	var panel := _panel()
	top_panel = panel
	add_child(panel)
	panel.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	panel.offset_bottom = 38
	var row := _row(_margin(panel, 5), 14)
	ally_hp = _hp_bar(row, CYAN)
	ally_caption = ally_hp.get_meta("caption")
	wave_caption = _label("", true)
	wave_caption.custom_minimum_size.x = 215
	row.add_child(wave_caption)
	enemy_hp = _hp_bar(row, Color("#eb6862"))
	enemy_caption = enemy_hp.get_meta("caption")

func _hp_bar(row: HBoxContainer, color: Color) -> ProgressBar:
	var column := _column(row, 4)
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	var caption := _label()
	column.add_child(caption)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.add_theme_stylebox_override("background", _style(Color("#293740"), Color("#0a1014")))
	bar.add_theme_stylebox_override("fill", _style(color, color.darkened(0.22)))
	column.add_child(bar)
	bar.set_meta("caption", caption)
	return bar

func _make_console() -> void:
	bottom_panel = _panel()
	var frame := StyleBoxTexture.new()
	frame.texture = preload("res://assets/ui/pause/panel_frame_v01.png")
	frame.texture_margin_left = 16.0
	frame.texture_margin_right = 16.0
	frame.texture_margin_top = 16.0
	frame.texture_margin_bottom = 16.0
	frame.content_margin_left = 10.0
	frame.content_margin_right = 10.0
	frame.content_margin_top = 10.0
	frame.content_margin_bottom = 10.0
	bottom_panel.add_theme_stylebox_override("panel", frame)
	bottom_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(bottom_panel)
	bottom_panel.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bottom_panel.offset_top = -200
	var row := _row(_margin(bottom_panel, 4), 4)
	_make_resources(_module(row, "RESOURCES", 120, 1.0))
	_make_docks(_module(row, "LIVE DOCK CAMERAS", 182, 1.2))
	_make_catalog(_module(row, "UNIT CATALOG", 506, 4.25))
	var inspector: VBoxContainer = _module(row, "UNIT TEST SIMULATOR", 204, 1.0)
	inspector.get_parent().get_parent().size_flags_horizontal = SIZE_FILL
	_make_inspector(inspector)

func _module(row: HBoxContainer, title: String, width: int, weight: float) -> VBoxContainer:
	var panel := _panel()
	panel.custom_minimum_size.x = width
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = weight
	row.add_child(panel)
	var col := _column(_margin(panel, 4), 3)
	var plate := _panel(STEEL, EDGE)
	plate.custom_minimum_size.y = 14
	col.add_child(plate)
	var heading := _label(title)
	heading.add_theme_color_override("font_color", Color("#c5dbdd"))
	_margin(plate, 2).add_child(heading)
	return col

const DISPLAY_SHADER := preload("res://shaders/digital_panel.gdshader")
const DISPLAY_REST := Color("#5fd9cf")
const DISPLAY_SHADOW := Color("#0a2b2d")
const DISPLAY_UNLOADED := Color("#1b4c4b")
const DISPLAY_LIGHT := Color("#b8fff6")
const SCREW_ICON := preload("res://assets/game/misc/screw.png")
const ART_TINT_SHADER := preload("res://shaders/unit_tint.gdshader")

func _make_resources(col: VBoxContainer) -> void:
	var frame := _panel(Color("#04090b"), Color("#2c7f7b"))
	frame.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(frame)
	var screen := ColorRect.new()
	screen.mouse_filter = MOUSE_FILTER_IGNORE
	var screen_material := ShaderMaterial.new()
	screen_material.shader = DISPLAY_SHADER
	screen.material = screen_material
	screen.resized.connect(func() -> void: screen_material.set_shader_parameter("rect_size", screen.size))
	frame.add_child(screen)
	var content := VBoxContainer.new()
	content.mouse_filter = MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	screen.add_child(content)
	content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_counter(content, legacy.screw_label)
	_counter(content, legacy.gear_label)
	var centering := CenterContainer.new()
	col.add_child(centering)
	menu = Button.new()
	menu.text = "MENU"
	menu.custom_minimum_size = Vector2(54, 22)
	_skin(menu)
	menu.pressed.connect(func() -> void: open_menu.emit())
	centering.add_child(menu)

func _counter(content: VBoxContainer, value: BarValue) -> void:
	var centering := CenterContainer.new()
	centering.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(centering)
	value.reparent(centering, false)
	value.show()
	value.size_flags_horizontal = SIZE_SHRINK_CENTER
	value.custom_minimum_size.x = 104.0
	value.apply_palette(DISPLAY_REST, DISPLAY_SHADOW, DISPLAY_LIGHT, 0.001, 0.001)
	if value == legacy.screw_label:
		value.apply_charge_style(DISPLAY_UNLOADED, DISPLAY_REST)

func _make_docks(col: VBoxContainer) -> void:
	var top := _row(col)
	var naval: ShipConstructor = round_scene.ally_base.constructors[BaseDock.Type.NAVAL]
	var sub: ShipConstructor = round_scene.ally_base.constructors[BaseDock.Type.SUB]
	var air: ShipConstructor = round_scene.ally_base.constructors[BaseDock.Type.AIR]
	_make_dock(top, BaseDock.Type.NAVAL, "NAVAL DOCK", naval)
	_make_dock(top, BaseDock.Type.SUB, "SUB DOCK", sub)
	var lower := CenterContainer.new()
	col.add_child(lower)
	_make_dock(lower, BaseDock.Type.AIR, "AIR DOCK", air)

func _make_dock(parent: Control, kind: BaseDock.Type, title: String, constructor: ShipConstructor) -> void:
	var panel := _panel(Color("#202b31"), EDGE)
	panel.custom_minimum_size = Vector2(CAM_SIZE.x + 8, CAM_SIZE.y + 31)
	parent.add_child(panel)
	var col := _column(_margin(panel, 4), 2)
	col.add_child(_label(title))
	var texture := TextureRect.new()
	texture.custom_minimum_size = Vector2(CAM_SIZE)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP
	texture.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(texture)
	var viewport := SubViewport.new()
	viewport.size = CAM_SIZE
	viewport.world_2d = round_scene.get_world_2d()
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.gui_disable_input = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	add_child(viewport)
	var camera := Camera2D.new()
	viewport.add_child(camera)
	camera.make_current()
	camera.position = _dock_center(kind, constructor).round()
	texture.texture = viewport.get_texture()
	var status := _label("", true)
	col.add_child(status)
	dock_status[kind] = status
	dock_panels[kind] = panel
	dock_viewports[kind] = viewport
	constructor.ship_build_finish.connect(_dock_finished.bind(kind))

func _dock_center(kind: BaseDock.Type, constructor: ShipConstructor) -> Vector2:
	if kind == BaseDock.Type.NAVAL:
		return constructor.global_position + Vector2(0, -7)
	var dock: BaseDock = round_scene.ally_base.docks[kind]
	var definition: Dictionary = BaseDock.DEFS[kind]
	var center: Vector2 = definition["center"]
	return dock.to_global(center)

func _dock_finished(_stats: BoatStats, kind: BaseDock.Type) -> void:
	completion_until[kind] = Time.get_ticks_msec() + 850

func _make_catalog(col: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 1)
	col.add_child(grid)
	for index: int in range(10):
		var unit: EntityStats = roster[index] if index < roster.size() else null
		var button := Button.new()
		button.custom_minimum_size = Vector2(100, 72)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		_skin(button)
		button.disabled = unit == null
		button.pressed.connect(quick_build.bind(index))
		button.mouse_entered.connect(_select.bind(index))
		button.focus_entered.connect(_select.bind(index))
		grid.add_child(button)
		cards.append(button)
		var card := _column(_margin(button, 4), 1)
		var upper := _row(card, 3)
		var badge := _panel(Color("#10191f"), EDGE)
		badge.custom_minimum_size.x = 13
		badge.mouse_filter = MOUSE_FILTER_IGNORE
		badge.add_child(_label(str((index + 1) % 10), true))
		upper.add_child(badge)
		var title := _label(unit.name.to_upper() if unit else "EMPTY")
		title.add_theme_font_override("font", PIXEL_FONT)
		title.size_flags_horizontal = SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		upper.add_child(title)
		card_titles.append(title)
		var well := _panel(Color("#4d6069"), Color("#172127"))
		well.mouse_filter = MOUSE_FILTER_IGNORE
		well.custom_minimum_size = Vector2(0, 30)
		well.size_flags_vertical = SIZE_EXPAND_FILL
		card.add_child(well)
		card_wells.append(well)
		var screen := ColorRect.new()
		screen.mouse_filter = MOUSE_FILTER_IGNORE
		var screen_material := ShaderMaterial.new()
		screen_material.shader = DISPLAY_SHADER
		screen.material = screen_material
		screen.resized.connect(func() -> void: screen_material.set_shader_parameter("rect_size", screen.size))
		if unit == null:
			screen_material.set_shader_parameter("band_strength", 0.0)
		card_screen_materials.append(screen_material)
		well.add_child(screen)
		var art := TextureRect.new()
		art.texture = unit.sprite if unit else null
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		art.clip_contents = true
		art.mouse_filter = MOUSE_FILTER_IGNORE
		var art_material := ShaderMaterial.new()
		art_material.shader = ART_TINT_SHADER
		art_material.set_shader_parameter("tint", DISPLAY_REST)
		art.material = art_material
		card_art_materials.append(art_material)
		well.add_child(art)
		var overlay := _margin(well, 3)
		overlay.mouse_filter = MOUSE_FILTER_IGNORE
		var stack := VBoxContainer.new()
		stack.mouse_filter = MOUSE_FILTER_IGNORE
		overlay.add_child(stack)
		var spacer := Control.new()
		spacer.mouse_filter = MOUSE_FILTER_IGNORE
		spacer.size_flags_vertical = SIZE_EXPAND_FILL
		stack.add_child(spacer)
		var footer := HBoxContainer.new()
		footer.mouse_filter = MOUSE_FILTER_IGNORE
		stack.add_child(footer)
		if unit == null:
			var bottom_spacer := Control.new()
			bottom_spacer.mouse_filter = MOUSE_FILTER_IGNORE
			bottom_spacer.size_flags_vertical = SIZE_EXPAND_FILL
			stack.add_child(bottom_spacer)
		var status := _label()
		status.size_flags_horizontal = SIZE_EXPAND_FILL
		if unit == null:
			status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		footer.add_child(status)
		card_status.append(status)
		var price := _label(str(unit.price) if unit else "")
		price.add_theme_color_override("font_color", DISPLAY_LIGHT)
		if unit != null:
			var screw := TextureRect.new()
			screw.texture = SCREW_ICON
			screw.stretch_mode = TextureRect.STRETCH_KEEP
			screw.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			screw.size_flags_vertical = SIZE_SHRINK_CENTER
			screw.mouse_filter = MOUSE_FILTER_IGNORE
			var screw_material := ShaderMaterial.new()
			screw_material.shader = ART_TINT_SHADER
			screw_material.set_shader_parameter("tint", DISPLAY_LIGHT)
			screw.material = screw_material
			footer.add_child(screw)
		footer.add_child(price)
		last_reasons.append("#")

func _make_inspector(col: VBoxContainer) -> void:
	var frame := _panel()
	frame.custom_minimum_size.y = 88
	col.add_child(frame)
	demo = DEMO.new()
	demo.team_outlines = false
	_margin(frame, 2).add_child(demo)
	var overlay := DEMO.make_digital_overlay()
	demo_overlay = overlay
	demo.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	demo_title = _label()
	col.add_child(demo_title)
	for keys: Array in [[&"health", &"speed"], [&"weapons", &"targets"]]:
		var row := _row(col)
		for key: StringName in keys:
			var button := Button.new()
			button.custom_minimum_size.y = 16
			button.size_flags_horizontal = SIZE_EXPAND_FILL
			_skin(button)
			button.mouse_entered.connect(_on_stat_hover.bind(key))
			button.mouse_exited.connect(_clear_stat_hover.bind(key))
			button.focus_entered.connect(_on_stat_focus.bind(key))
			button.focus_exited.connect(_clear_stat_focus.bind(key))
			row.add_child(button)
			stat_buttons[key] = button

func _on_stat_hover(key: StringName) -> void:
	hover_stat = key

func _clear_stat_hover(key: StringName) -> void:
	if hover_stat == key:
		hover_stat = &""

func _on_stat_focus(key: StringName) -> void:
	focused_stat = key

func _clear_stat_focus(key: StringName) -> void:
	if focused_stat == key:
		focused_stat = &""

func _select(index: int) -> void:
	selected = index
	for i: int in range(last_reasons.size()):
		last_reasons[i] = "#"
	var value: EntityStats = roster[index] if index >= 0 and index < roster.size() else null
	var stats: EntityStats = Global.upgraded_entity(value) if value else null
	demo.show_unit(stats)
	(demo_overlay.material as ShaderMaterial).set_shader_parameter("band_strength", 1.0 if stats else 0.0)
	demo_title.text = stats.name.to_upper() if stats else "HOVER A UNIT"
	var health: Button = stat_buttons[&"health"]
	var speed: Button = stat_buttons[&"speed"]
	var weapons: Button = stat_buttons[&"weapons"]
	var targets: Button = stat_buttons[&"targets"]
	health.text = "HP %s" % _number(stats.health) if stats else "HP"
	speed.text = "SPD %s" % _number(stats.speed) if stats else "SPD"
	weapons.text = "GUNS %d" % stats.gun_slots.size() if stats else "GUNS"
	targets.text = "TARGETS"
	targets.tooltip_text = _target_summary(stats)
	for button: Button in stat_buttons.values():
		button.disabled = stats == null
	_refresh_catalog()

func _target_summary(stats: EntityStats) -> String:
	if not stats:
		return ""
	var surface: bool = false
	var air: bool = false
	var submerged: bool = false
	for slot_index: int in range(stats.gun_slots.size()):
		var slot: GunSlot = stats.gun_slots[slot_index]
		var gun_type: int = Global.gun_type_for(stats.name, slot_index, slot)
		if gun_type < 0:
			continue
		var packed: PackedScene = Enums.gun_scene(gun_type)
		var gun: Gun = packed.instantiate() as Gun
		surface = surface or gun.hits_surface
		air = air or gun.hits_air
		submerged = submerged or gun.hits_submerged
		gun.free()
	var targets: PackedStringArray = []
	if surface:
		targets.append("Surface")
	if air:
		targets.append("Air")
	if submerged:
		targets.append("Submerged")
	return ", ".join(targets) if not targets.is_empty() else "No default armament"

func _number(value: float) -> String:
	return str(snappedf(value, 0.1))

func quick_build(index: int) -> void:
	if index < 0 or index >= roster.size():
		return
	var unit: EntityStats = roster[index]
	if _build_reason(unit) != "READY":
		return
	legacy.spawn_entity(unit)
	_refresh_catalog()

func _build_reason(unit: EntityStats) -> String:
	if round_scene.game_ended or get_tree().paused:
		return "UNAVAILABLE"
	if not unit:
		return "EMPTY"
	if unit.price > legacy.screw_label.total_value:
		return "LOW SCREWS"
	var kind: BaseDock.Type = Base.dock_type_of(unit)
	if kind != BaseDock.Type.NAVAL and not (round_scene.ally_base.docks[kind] as BaseDock).active:
		return "DOCK OFFLINE"
	var constructor: ShipConstructor = round_scene.ally_base.constructors[kind]
	if constructor.is_building():
		return "DOCK BUSY"
	return "READY"

func _refresh_catalog() -> void:
	for index: int in range(cards.size()):
		var unit: EntityStats = roster[index] if index < roster.size() else null
		var reason: String = _build_reason(unit)
		if reason == last_reasons[index]:
			continue
		last_reasons[index] = reason
		card_status[index].text = reason
		var color: Color = CYAN if reason == "READY" else DIM
		if reason == "LOW SCREWS":
			color = PINK
		elif reason == "DOCK BUSY":
			color = AMBER
		elif reason == "EMPTY":
			color = DISPLAY_UNLOADED
		card_status[index].add_theme_color_override("font_color", color)
		_skin_card(cards[index], reason == "READY", selected == index)
		card_wells[index].add_theme_stylebox_override("panel", _style(Color("#4d6069") if reason == "READY" else Color("#2f3c43"), Color("#172127")))
		card_art_materials[index].set_shader_parameter("tint", DISPLAY_REST if reason == "READY" else DISPLAY_UNLOADED)
		card_screen_materials[index].set_shader_parameter("band_strength", 1.0 if reason == "READY" else 0.0)
		card_wells[index].modulate = Color.WHITE if reason == "READY" else Color(0.72, 0.74, 0.78)
		card_titles[index].modulate = Color.WHITE if reason == "READY" else Color(0.65, 0.68, 0.7)

func _process(_delta: float) -> void:
	_refresh_catalog()
	var ally_max: float = float(round_scene.get("ally_max_hp"))
	var enemy_max: float = float(round_scene.get("enemy_max_hp"))
	_update_hp(ally_hp, ally_caption, "BASE HP", round_scene.ally_base.health_component.health, ally_max)
	_update_hp(enemy_hp, enemy_caption, "ENEMY HP", round_scene.enemy_base.health_component.health, enemy_max)
	wave_caption.text = "WAVE %02d" % round_scene.wave_manager.current_wave_number()
	if int(round_scene.get("boss_notice_until")) > Time.get_ticks_msec():
		wave_caption.text += "  BOSS"
	for kind: int in dock_status:
		_update_dock(kind)
	var key: StringName = hover_stat if hover_stat != &"" else focused_stat
	demo.set_demo(&"damage" if key == &"health" else key)
	if selected >= 0 and selected < roster.size():
		var label: String = roster[selected].name.to_upper()
		demo_title.text = "%s: %s" % [label, stat_buttons[&"targets"].tooltip_text] if key == &"targets" else label
	menu.disabled = round_scene.game_ended

func _update_hp(bar: ProgressBar, caption: Label, title: String, current: float, full: float) -> void:
	bar.max_value = maxf(1, full)
	bar.value = current
	caption.text = "%s  %s / %s" % [title, _number(current), _number(full)]

func _update_dock(kind: int) -> void:
	var constructor: ShipConstructor = round_scene.ally_base.constructors[kind]
	var status: Label = dock_status[kind]
	var viewport: SubViewport = dock_viewports[kind]
	var active: bool = kind == BaseDock.Type.NAVAL or (round_scene.ally_base.docks[kind] as BaseDock).active
	var state: String = "OFFLINE"
	var caption: String = state
	var color: Color = EDGE
	if active:
		state = "READY"
		caption = state
		color = CYAN
		if constructor.is_building():
			var material: ShaderMaterial = constructor.material as ShaderMaterial
			var progress: float = float(material.get_shader_parameter("build_progress"))
			state = "BUILDING"
			caption = "%d%%" % roundi(progress * 100.0)
			color = AMBER
		elif int(completion_until.get(kind, 0)) > Time.get_ticks_msec():
			state = "LAUNCHING"
			caption = state
	if last_dock_states.get(kind) != state:
		var panel: PanelContainer = dock_panels[kind]
		panel.add_theme_stylebox_override("panel", _style(Color("#202b31").lerp(color, 0.12), color.darkened(0.38)))
		status.add_theme_color_override("font_color", color)
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if active else SubViewport.UPDATE_DISABLED
		last_dock_states[kind] = state
	status.text = caption

func covers_point(point: Vector2) -> bool:
	return top_panel.get_global_rect().has_point(point) or bottom_panel.get_global_rect().has_point(point)

