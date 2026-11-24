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
const DOCK_ICONS_8: Dictionary = {
	BaseDock.Type.NAVAL: preload("res://assets/ui/icons/naval_8x8_v02.png"),
	BaseDock.Type.SUB: preload("res://assets/ui/icons/submarine_8x8_v01.png"),
	BaseDock.Type.AIR: preload("res://assets/ui/icons/airship_8x8_v02.png"),
}
const DOCK_ICONS_12: Dictionary = {
	BaseDock.Type.NAVAL: preload("res://assets/ui/icons/naval_12x12_v01.png"),
	BaseDock.Type.SUB: preload("res://assets/ui/icons/submarine_fleet_12x12_v05.png"),
	BaseDock.Type.AIR: preload("res://assets/ui/icons/airship_12x12_v03.png"),
}
const OFF_MODULATE := Color(0.38, 0.45, 0.45)
const SLOT_SIZE := Vector2(32, 26)
const QUEUE_TITLES: Dictionary = {
	BaseDock.Type.NAVAL: "hud.naval",
	BaseDock.Type.SUB: "hud.sub",
	BaseDock.Type.AIR: "hud.air",
}
const CATALOG_SLOTS: int = 10
const BASE_WARNING_RATIO: float = 0.25
const DENIED_REASONS: PackedStringArray = ["hud.low_screws", "hud.dock_offline", "hud.queue_full"]

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
var card_headers: Array[HBoxContainer] = []
var selected: int = -1
var ally_hp: ProgressBar
var enemy_hp: ProgressBar
var ally_caption: Label
var enemy_caption: Label
var wave_caption: Label
var queue_rows: Dictionary = {}
var queue_titles: Dictionary = {}
var queue_slots: Dictionary = {}
var queue_arts: Dictionary = {}
var queue_screens: Dictionary = {}
var queue_wells: Dictionary = {}
var queue_percents: Dictionary = {}
var queue_signatures: Dictionary = {}
var menu: Button
var demo: DEMO
var demo_title: Label
var stat_buttons: Dictionary = {}
var last_reasons: Array[String]
var bottom_panel: PanelContainer
var top_panel: PanelContainer
var minimap: BattleMinimap
var hover_stat: StringName
var focused_stat: StringName
var sfx: HudSfx
var base_warning_armed: bool = true

func _ready() -> void:
	sfx = UiSfx
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var hud_theme := Theme.new()
	hud_theme.default_font = FONT
	hud_theme.default_font_size = 8
	theme = hud_theme
	roster = Global.player_stats.loadout_slots(CATALOG_SLOTS)
	_make_header()
	_make_console()
	_select(_first_unit())

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
	label.text = Loc.t(value).to_upper()
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
	minimap = BattleMinimap.new()
	minimap.round_scene = round_scene
	add_child(minimap)
	minimap.set_anchors_preset(PRESET_CENTER_TOP)
	minimap.offset_left = -250.0
	minimap.offset_right = 250.0
	minimap.offset_top = 84.0
	minimap.offset_bottom = 100.0

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
	_make_resources(_module(row, "hud.resources", 120, 1.0))
	_make_queues(_module(row, "hud.production_queues", 182, 1.2))
	_make_catalog(_module(row, "hud.unit_catalog", 506, 4.25))
	var inspector: VBoxContainer = _module(row, "hud.unit_test_simulator", 204, 1.0)
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
const DISPLAY_TEXT := Color("#9ad5ce")
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
	menu.text = "hud.menu"
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

func _make_queues(col: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var rows := _column(scroll, 4)
	rows.size_flags_horizontal = SIZE_EXPAND_FILL
	for kind: BaseDock.Type in [BaseDock.Type.NAVAL, BaseDock.Type.SUB, BaseDock.Type.AIR]:
		var panel := _panel(Color("#202b31"), EDGE)
		rows.add_child(panel)
		var inner := _column(_margin(panel, 3), 2)
		var title_row := _row(inner, 3)
		title_row.add_child(_tinted_icon(DOCK_ICONS_8[kind], Vector2.ZERO, CYAN))
		var title := _label(QUEUE_TITLES[kind])
		title_row.add_child(title)
		var strip := HFlowContainer.new()
		strip.add_theme_constant_override("h_separation", 2)
		strip.add_theme_constant_override("v_separation", 2)
		inner.add_child(strip)
		var slots: Array[Button] = []
		var arts: Array[TextureRect] = []
		var screens: Array[ShaderMaterial] = []
		var wells: Array[PanelContainer] = []
		var percents: Array[Label] = []
		for index: int in range(round_scene.ally_base.queue_capacity(kind)):
			var slot := Button.new()
			slot.set_meta(UiSfx.MANUAL_META, true)
			slot.custom_minimum_size = SLOT_SIZE
			slot.focus_mode = Control.FOCUS_NONE
			slot.flat = true
			var well := _panel(Color("#2f3c43"), Color("#172127"))
			well.mouse_filter = MOUSE_FILTER_IGNORE
			well.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			slot.add_child(well)
			var screen := ColorRect.new()
			screen.mouse_filter = MOUSE_FILTER_IGNORE
			var screen_material := ShaderMaterial.new()
			screen_material.shader = DISPLAY_SHADER
			screen_material.set_shader_parameter("band_strength", 0.0)
			screen.material = screen_material
			screen.resized.connect(func() -> void: screen_material.set_shader_parameter("rect_size", screen.size))
			well.add_child(screen)
			var art := TextureRect.new()
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			art.clip_contents = true
			art.mouse_filter = MOUSE_FILTER_IGNORE
			var art_material := ShaderMaterial.new()
			art_material.shader = ART_TINT_SHADER
			art_material.set_shader_parameter("tint", DISPLAY_REST)
			art.material = art_material
			well.add_child(art)
			var percent := _label("", true)
			percent.mouse_filter = MOUSE_FILTER_IGNORE
			percent.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			percent.add_theme_color_override("font_color", DISPLAY_LIGHT)
			percent.add_theme_color_override("font_outline_color", Color("#06181a"))
			percent.add_theme_constant_override("outline_size", 4)
			percent.visible = false
			well.add_child(percent)
			percents.append(percent)
			slot.pressed.connect(_cancel_slot.bind(kind, index))
			strip.add_child(slot)
			slots.append(slot)
			arts.append(art)
			screens.append(screen_material)
			wells.append(well)
		queue_rows[kind] = panel
		queue_titles[kind] = title
		queue_slots[kind] = slots
		queue_arts[kind] = arts
		queue_screens[kind] = screens
		queue_wells[kind] = wells
		queue_percents[kind] = percents

func _unit_icon(stats: EntityStats) -> Texture2D:
	if stats is AirPlaneState:
		var plane: AirPlaneState = stats as AirPlaneState
		if not plane.body_frames.is_empty():
			return plane.body_frames[0]
	return stats.sprite

func _cancel_slot(kind: BaseDock.Type, index: int) -> void:
	var removed: BoatStats = round_scene.ally_base.cancel_slot(kind, index)
	if removed == null:
		return
	legacy.refund_entity(removed)
	sfx.play(&"confirm")
	_refresh_catalog()

func _make_catalog(col: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 1)
	col.add_child(grid)
	for index: int in range(10):
		var unit: EntityStats = roster[index] if index < roster.size() else null
		var button := Button.new()
		button.set_meta(UiSfx.MANUAL_META, true)
		button.custom_minimum_size = Vector2(100, 72)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		_skin(button)
		button.disabled = unit == null
		button.pressed.connect(quick_build.bind(index))
		button.mouse_entered.connect(_on_card_hover.bind(index))
		button.focus_entered.connect(_on_card_focus.bind(index))
		grid.add_child(button)
		cards.append(button)
		button.focus_neighbor_left = button.get_path()
		button.focus_neighbor_right = button.get_path()
		var card := _column(_margin(button, 4), 1)
		var upper := _row(card, 3)
		var badge := _panel(Color("#10191f"), EDGE)
		badge.custom_minimum_size.x = 13
		badge.mouse_filter = MOUSE_FILTER_IGNORE
		badge.add_child(_label(str((index + 1) % 10), true))
		upper.add_child(badge)
		var title := _label(Loc.named("unit", unit.name).to_upper() if unit else "hud.empty")
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
		var header := HBoxContainer.new()
		header.mouse_filter = MOUSE_FILTER_IGNORE
		stack.add_child(header)
		header.add_theme_constant_override("separation", 0)
		card_headers.append(header)
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
		if unit != null:
			header.add_child(_tinted_icon(DOCK_ICONS_12[Base.dock_type_of(unit)], Vector2.ZERO, DISPLAY_TEXT))
			var header_gap := Control.new()
			header_gap.mouse_filter = MOUSE_FILTER_IGNORE
			header_gap.size_flags_horizontal = SIZE_EXPAND_FILL
			header.add_child(header_gap)
			var price := _label(str(unit.price))
			price.add_theme_font_size_override("font_size", 12)
			price.add_theme_color_override("font_color", DISPLAY_TEXT)
			price.size_flags_vertical = SIZE_SHRINK_CENTER
			header.add_child(price)
			var price_gap := Control.new()
			price_gap.mouse_filter = MOUSE_FILTER_IGNORE
			price_gap.custom_minimum_size.x = 2
			header.add_child(price_gap)
			header.add_child(_tinted_icon(SCREW_ICON, Vector2(18, 18), DISPLAY_TEXT))
		last_reasons.append("#")

func _tinted_icon(texture: Texture2D, size: Vector2, tint: Color) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = SIZE_SHRINK_CENTER
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	if size == Vector2.ZERO:
		icon.stretch_mode = TextureRect.STRETCH_KEEP
	else:
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.custom_minimum_size = size
	var material := ShaderMaterial.new()
	material.shader = ART_TINT_SHADER
	material.set_shader_parameter("tint", tint)
	icon.set_meta(&"base_tint", tint)
	icon.material = material
	return icon

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

func _first_unit() -> int:
	for index: int in range(roster.size()):
		if roster[index] != null:
			return index
	return -1

func _has_unit(index: int) -> bool:
	return index >= 0 and index < roster.size() and roster[index] != null

func _on_card_hover(index: int) -> void:
	if _has_unit(index):
		sfx.play(&"hover")
	_select(index)

func _on_card_focus(index: int) -> void:
	if _has_unit(index) and index != selected:
		sfx.play(&"select")
	_select(index)

func _select(index: int) -> void:
	selected = index
	for i: int in range(last_reasons.size()):
		last_reasons[i] = "#"
	var value: EntityStats = roster[index] if index >= 0 and index < roster.size() else null
	var stats: EntityStats = Global.upgraded_entity(value) if value else null
	demo.show_unit(stats)
	(demo_overlay.material as ShaderMaterial).set_shader_parameter("band_strength", 1.0 if stats else 0.0)
	demo_title.text = Loc.named("unit", stats.name).to_upper() if stats else "hud.hover_a_unit"
	var health: Button = stat_buttons[&"health"]
	var speed: Button = stat_buttons[&"speed"]
	var weapons: Button = stat_buttons[&"weapons"]
	var targets: Button = stat_buttons[&"targets"]
	health.icon = load("res://assets/ui/icons/hp_8x8_v01.png")
	speed.icon = load("res://assets/ui/icons/speed_8x8_v01.png")
	weapons.icon = load("res://assets/ui/icons/gun_8x8_v01.png")
	health.text = _number(stats.health) if stats else "HP"
	speed.text = _number(stats.speed) if stats else "hud.spd"
	weapons.text = "%d" % stats.gun_slots.size() if stats else "hud.guns"
	targets.text = "hud.targets"
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
		targets.append(Loc.t("hud.surface"))
	if air:
		targets.append(Loc.t("hud.air_2"))
	if submerged:
		targets.append(Loc.t("hud.submerged"))
	return ", ".join(targets) if not targets.is_empty() else Loc.t("hud.no_default_armament")

func _number(value: float) -> String:
	return str(snappedf(value, 0.1))

func quick_build(index: int) -> void:
	if not _has_unit(index):
		return
	var unit: EntityStats = roster[index]
	var reason: String = _build_reason(unit)
	if reason != "hud.ready":
		if DENIED_REASONS.has(reason):
			sfx.play(&"denied")
		return
	legacy.spawn_entity(unit)
	sfx.play(&"confirm")
	_refresh_catalog()

func _update_base_warning(current: float, full: float) -> void:
	var ratio: float = current / maxf(1.0, full)
	if ratio > BASE_WARNING_RATIO:
		base_warning_armed = true
	elif base_warning_armed and current > 0.0 and not round_scene.game_ended:
		base_warning_armed = false
		sfx.play(&"base_warning")

func _build_reason(unit: EntityStats) -> String:
	if round_scene.game_ended or get_tree().paused:
		return "hud.unavailable"
	if not unit:
		return "hud.empty"
	if unit.price > legacy.screw_label.total_value:
		return "hud.low_screws"
	var kind: BaseDock.Type = Base.dock_type_of(unit)
	if kind != BaseDock.Type.NAVAL and not (round_scene.ally_base.docks[kind] as BaseDock).active:
		return "hud.dock_offline"
	if not round_scene.ally_base.queue_has_room(kind):
		return "hud.queue_full"
	return "hud.ready"

func _refresh_catalog() -> void:
	for index: int in range(cards.size()):
		var unit: EntityStats = roster[index] if index < roster.size() else null
		var reason: String = _build_reason(unit)
		if reason == last_reasons[index]:
			continue
		last_reasons[index] = reason
		card_status[index].text = reason
		var color: Color = DISPLAY_TEXT if reason == "hud.ready" else DIM
		if reason == "hud.low_screws":
			color = PINK
		elif reason == "hud.queue_full":
			color = AMBER
		elif reason == "hud.empty":
			color = DISPLAY_UNLOADED
		card_status[index].add_theme_color_override("font_color", color)
		_skin_card(cards[index], reason == "hud.ready", selected == index)
		card_wells[index].add_theme_stylebox_override("panel", _style(Color("#4d6069") if reason == "hud.ready" else Color("#2f3c43"), Color("#172127")))
		card_art_materials[index].set_shader_parameter("tint", DISPLAY_REST if reason == "hud.ready" else DISPLAY_UNLOADED)
		card_screen_materials[index].set_shader_parameter("band_strength", 1.0 if reason == "hud.ready" else 0.0)
		card_wells[index].modulate = Color.WHITE if reason == "hud.ready" else Color(0.72, 0.74, 0.78)
		card_titles[index].modulate = Color.WHITE if reason == "hud.ready" else Color(0.65, 0.68, 0.7)
		card_headers[index].modulate = Color.WHITE if reason == "hud.ready" else OFF_MODULATE
		for child: Node in card_headers[index].get_children():
			if child is TextureRect and child.has_meta(&"base_tint"):
				var base_tint: Color = child.get_meta(&"base_tint")
				((child as TextureRect).material as ShaderMaterial).set_shader_parameter("tint", base_tint if reason == "hud.ready" else base_tint.darkened(0.55))

func _process(_delta: float) -> void:
	_refresh_catalog()
	var ally_max: float = float(round_scene.get("ally_max_hp"))
	var enemy_max: float = float(round_scene.get("enemy_max_hp"))
	_update_hp(ally_hp, ally_caption, "hud.base_hp", round_scene.ally_base.health_component.health, ally_max)
	_update_hp(enemy_hp, enemy_caption, "hud.enemy_hp", round_scene.enemy_base.health_component.health, enemy_max)
	_update_base_warning(round_scene.ally_base.health_component.health, ally_max)
	if round_scene.wave_manager:
		wave_caption.text = Loc.t("hud.wave") % round_scene.wave_manager.current_wave_number()
	elif Global.run:
		wave_caption.text = Loc.t("hud.floor") % (int(Global.run.map.get_node(Global.run.pending_node)["col"]) + 1)
	if int(round_scene.get("boss_notice_until")) > Time.get_ticks_msec():
		wave_caption.text += "  BOSS"
	for kind: int in queue_rows:
		_update_queue(kind)
	var key: StringName = hover_stat if hover_stat != &"" else focused_stat
	demo.set_demo(&"damage" if key == &"health" else key)
	if _has_unit(selected):
		var label: String = Loc.named("unit", roster[selected].name).to_upper()
		demo_title.text = "%s: %s" % [label.to_upper(), stat_buttons[&"targets"].tooltip_text] if key == &"targets" else label.to_upper()
	menu.disabled = round_scene.game_ended

func _update_hp(bar: ProgressBar, caption: Label, title: String, current: float, full: float) -> void:
	bar.max_value = maxf(1, full)
	bar.value = current
	caption.text = "%s  %s / %s" % [Loc.t(title).to_upper(), _number(current), _number(full)]

func _update_queue(kind: int) -> void:
	var base: Base = round_scene.ally_base
	var active: bool = kind == BaseDock.Type.NAVAL or (base.docks[kind] as BaseDock).active
	(queue_rows[kind] as PanelContainer).visible = active
	if not active:
		return
	var constructor: ShipConstructor = base.constructors[kind]
	var waiting: Array = base.queues[kind]
	var building: BoatStats = constructor.boat_stats
	var title: Label = queue_titles[kind]
	var signature: Array = [building, waiting.duplicate(), base.queue_capacity(kind)]
	var slots: Array = queue_slots[kind]
	if building:
		var material: ShaderMaterial = constructor.material as ShaderMaterial
		var progress: float = float(material.get_shader_parameter("build_progress"))
		(queue_percents[kind][0] as Label).text = "%d%%" % roundi(progress * 100.0)
		(queue_percents[kind][0] as Label).visible = true
		title.text = "%s  %d/%d" % [Loc.t(QUEUE_TITLES[kind]), base.queue_used(kind), base.queue_capacity(kind)]
		title.add_theme_color_override("font_color", AMBER)
	else:
		(queue_percents[kind][0] as Label).visible = false
		title.text = "%s  %d/%d" % [Loc.t(QUEUE_TITLES[kind]), base.queue_used(kind), base.queue_capacity(kind)]
		title.add_theme_color_override("font_color", CYAN if waiting.is_empty() else DIM)
	if queue_signatures.get(kind) == signature:
		return
	queue_signatures[kind] = signature
	for index: int in range(slots.size()):
		var slot: Button = slots[index]
		var stats: EntityStats = null
		if index == 0:
			stats = building
		elif index - 1 < waiting.size():
			stats = waiting[index - 1]
		var filled: bool = stats != null
		(queue_arts[kind][index] as TextureRect).texture = _unit_icon(stats) if filled else null
		(queue_screens[kind][index] as ShaderMaterial).set_shader_parameter("band_strength", 1.0 if filled else 0.0)
		var edge: Color = AMBER if index == 0 and filled else Color("#172127")
		(queue_wells[kind][index] as PanelContainer).add_theme_stylebox_override("panel", _style(Color("#4d6069") if filled else Color("#2f3c43"), edge))
		slot.disabled = not filled
		slot.tooltip_text = Loc.t("hud.click_to_cancel_and_refund") % Loc.named("unit", stats.name).to_upper() if filled else ""

func covers_point(point: Vector2) -> bool:
	return top_panel.get_global_rect().has_point(point) or bottom_panel.get_global_rect().has_point(point) or minimap.get_global_rect().has_point(point)

