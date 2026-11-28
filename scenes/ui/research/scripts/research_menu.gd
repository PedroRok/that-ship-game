class_name ResearchMenu
extends Control

const FONT := preload("res://assets/fonts/dogicabold.ttf")
const PIXEL_FONT := preload("res://assets/fonts/dogicapixel.ttf")
const SILHOUETTE_SHADER := preload("res://shaders/silhouette.gdshader")
const GEAR_ICON := preload("res://assets/game/misc/gear.png")
const ICON_BOSS := preload("res://assets/ui/icons/boss_coin_12x12_v01.png")
const ICON_CHECK := preload("res://assets/ui/icons/check_ok_v01.png")

const ICON_ECONOMY := preload("res://assets/ui/icons/cargo_box_v01.png")
const ICON_BASE := preload("res://assets/ui/icons/base_health_v01.png")
const ICON_REPAIR := preload("res://assets/ui/icons/repair_v01.png")
const ICON_RADAR := preload("res://assets/ui/icons/beacon_signal_v01.png")
const ICON_UNIT := preload("res://assets/ui/icons/upgrade_unit_v01.png")
const ICON12_HP := preload("res://assets/ui/icons/hp_12x12_v01.png")
const ICON12_SPEED := preload("res://assets/ui/icons/speed_12x12_v01.png")
const ICON12_GUN := preload("res://assets/ui/icons/gun_turret_12x12_v04.png")
const ICON12_NAVAL := preload("res://assets/ui/icons/naval_12x12_v01.png")
const ICON12_AIR := preload("res://assets/ui/icons/airship_12x12_v03.png")
const ICON12_SUB := preload("res://assets/ui/icons/submarine_fleet_12x12_v05.png")

const BG := Color("#0b1419")
const PANEL := Color("#151f25")
const WELL := Color("#090f16")
const STEEL := Color("#34454f")
const EDGE := Color("#596a73")
const CYAN := Color("#70d6d3")
const AMBER := Color("#e6b35d")
const RED := Color("#d9726b")
const GREEN := Color("#7fd68a")
const BOSS := Color("#e0524a")
const BOSS_LIGHT := Color("#ffb3ad")
const TIP_DELAY : float = 0.12
const TIP_OFFSET : Vector2 = Vector2(16, 18)
const DIM := Color("#7f8b90")
const TEXT := Color("#e8f1f2")

const CELL : Vector2 = Vector2(132, 124)
const NODE_SIZE : Vector2 = Vector2(120, 112)
const ORIGIN : Vector2 = Vector2(8, 32)
const ICON_WELL : float = 56.0
const ICON_DRAW : int = 48
const DISPLAY_SHADER := preload("res://shaders/digital_panel.gdshader")

const BRANCHES : Array[Dictionary] = [
	{"title": "research.economy", "color": Color("#8fd66a"), "col": 0, "cols": 2},
	{"title": "research.base", "color": Color("#70d6d3"), "col": 2, "cols": 1},
	{"title": "research.units", "color": Color("#6fa8ee"), "col": 3, "cols": 2},
	{"title": "research.weapons", "color": Color("#e8776a"), "col": 5, "cols": 2},
	{"title": "research.skills", "color": Color("#c58ae8"), "col": 7, "cols": 2},
]

const STAT_ICONS : Dictionary = {
	&"base_health": ICON_BASE,
	&"build_time": ICON_REPAIR,
	&"radar_distance": ICON_RADAR,
	&"health": ICON12_HP,
	&"speed": ICON12_SPEED,
	&"damage": ICON12_GUN,
	&"shoot_interval": ICON12_GUN,
	&"weapon_unlock": ICON12_GUN,
	&"bomb_damage": ICON12_AIR,
	&"bomb_count": ICON12_AIR,
	&"bomb_cooldown": ICON12_AIR,
	&"supply_amount": ICON_ECONOMY,
	&"unlock_supply": ICON_ECONOMY,
	&"unlock_flak": ICON12_GUN,
	&"unlock_bomb": ICON12_AIR,
	&"queue_naval": ICON12_NAVAL,
	&"queue_sub": ICON12_SUB,
	&"queue_air": ICON12_AIR,
	&"auto_collect": ICON_ECONOMY,
}

enum NodeState { LOCKED, AVAILABLE, UNAFFORDABLE, MAXED }

class TreeLines extends Control:
	var links : Array[Dictionary] = []

	func _draw() -> void:
		for pass_active : bool in [false, true]:
			for link : Dictionary in links:
				if (link["active"] != pass_active):
					continue
				var color : Color = link["color"] if pass_active else Color("#34454f")
				var from_rect : Rect2 = link["from"]
				var to_rect : Rect2 = link["to"]
				var points : PackedVector2Array
				if (is_equal_approx(from_rect.position.y, to_rect.position.y)):
					var y : float = roundf(from_rect.get_center().y)
					var forward : bool = to_rect.position.x > from_rect.position.x
					var start_x : float = from_rect.end.x if forward else from_rect.position.x
					var end_x : float = to_rect.position.x if forward else to_rect.end.x
					points = PackedVector2Array([Vector2(start_x, y), Vector2(end_x, y)])
				else:
					var start : Vector2 = Vector2(roundf(from_rect.get_center().x), from_rect.end.y)
					var end : Vector2 = Vector2(roundf(to_rect.get_center().x), to_rect.position.y)
					var mid_y : float = roundf((start.y + end.y) / 2.0)
					points = PackedVector2Array([start, Vector2(start.x, mid_y), Vector2(end.x, mid_y), end])
				draw_polyline(points, color, 2.0)
				draw_rect(Rect2(points[points.size() - 1] - Vector2(2, 2), Vector2(4, 4)), color)

var gear_value : Label
var coin_value : Label
var lines : TreeLines
var node_buttons : Dictionary = {}
var hovered : UpgradeStats
var tip : Control
var tip_timer : Timer

func _ready() -> void:
	tip_timer = Timer.new()
	tip_timer.one_shot = true
	tip_timer.timeout.connect(_show_tip)
	add_child(tip_timer)
	texture_filter = TEXTURE_FILTER_NEAREST
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var ui_theme : Theme = Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 8
	PixelControls.apply_theme(ui_theme)
	theme = ui_theme

	var bg : ColorRect = ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(MenuBackground.new())

	var margin : MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side : String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var root : VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var top_panel : PanelContainer = _framed_panel()
	var top_margin : MarginContainer = MarginContainer.new()
	for side : String in ["left", "right", "top", "bottom"]:
		top_margin.add_theme_constant_override("margin_" + side, 10)
	top_margin.add_child(_build_top_bar())
	top_panel.add_child(top_margin)
	root.add_child(top_panel)

	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tree_panel : PanelContainer = _framed_panel()
	tree_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_panel.add_child(scroll)
	root.add_child(tree_panel)

	var canvas : Control = Control.new()
	canvas.custom_minimum_size = ORIGIN + Vector2(9, 4) * CELL + Vector2(0, 8)
	scroll.add_child(canvas)

	lines = TreeLines.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(lines)

	_build_branch_labels(canvas)
	_build_nodes(canvas)
	_refresh()

func _style(fill : Color, border : Color, thickness : int = 1) -> StyleBoxFlat:
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(thickness)
	style.anti_aliasing = false
	return style

func _framed_panel() -> PanelContainer:
	var panel : PanelContainer = PanelContainer.new()
	var box : StyleBoxTexture = MenuBackground.make_box()
	for side : String in ["left", "right", "top", "bottom"]:
		box.set("content_margin_" + side, 10.0)
	panel.add_theme_stylebox_override("panel", box)
	return panel

func _label(text : String, color : Color = TEXT, size : int = 8) -> Label:
	var label : Label = Label.new()
	label.text = PixelText.fit(text, size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	if (size != 8):
		label.add_theme_font_size_override("font_size", size)
	return label

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

func _currency(caption : String, icon : Texture2D, factor : int, color : Color, light : Color) -> Label:
	var column : VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.add_child(_label(caption, DIM))
	var plate : PanelContainer = PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _style(WELL, STEEL))
	var screen : ColorRect = ColorRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var screen_material : ShaderMaterial = ShaderMaterial.new()
	screen_material.shader = DISPLAY_SHADER
	screen_material.set_shader_parameter("line_color", color)
	screen.material = screen_material
	screen.resized.connect(func() -> void: screen_material.set_shader_parameter("rect_size", screen.size))
	plate.add_child(screen)
	var margin : MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side : String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	plate.add_child(margin)
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var value : Label = _label("", light)
	value.add_theme_font_size_override("font_size", 16)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.custom_minimum_size.x = 56
	row.add_child(_silhouette(icon, color, factor))
	row.add_child(value)
	column.add_child(plate)
	value.set_meta("plate", column)
	return value

func _skin_button(button : Button) -> void:
	button.add_theme_stylebox_override("normal", _style(Color("#293740"), Color("#72838d")))
	button.add_theme_stylebox_override("hover", _style(Color("#293740").lightened(0.10), Color("#72838d").lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _style(Color("#293740").darkened(0.25), Color("#72838d")))
	var focus : StyleBoxFlat = _style(Color.TRANSPARENT, CYAN)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)

func _build_top_bar() -> HBoxContainer:
	var bar : HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	var title : Label = _label("research.research", TEXT, 32)
	title.add_theme_font_override("font", PIXEL_FONT)
	bar.add_child(title)
	bar.add_child(VSeparator.new())
	gear_value = _currency("run.gears", GEAR_ICON, 2, AMBER, Color("#ffe3a8"))
	bar.add_child(gear_value.get_meta("plate"))
	coin_value = _currency("run.boss_coins", ICON_BOSS, 2, BOSS, BOSS_LIGHT)
	bar.add_child(coin_value.get_meta("plate"))
	var spacer : Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var back : Button = Button.new()
	back.text = Loc.t("research.back_to_shop")
	back.custom_minimum_size = Vector2(150, 34)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skin_button(back)
	back.pressed.connect(func() -> void: Global.change_scene(Global.Menu.SHOP))
	bar.add_child(back)
	return bar

func _build_branch_labels(canvas : Control) -> void:
	for branch : Dictionary in BRANCHES:
		var plate : PanelContainer = PanelContainer.new()
		var box : StyleBoxFlat = _style(STEEL, branch["color"])
		box.content_margin_left = 6
		box.content_margin_right = 6
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		plate.add_theme_stylebox_override("panel", box)
		plate.add_child(_label(str(branch["title"]), branch["color"]))
		plate.position = Vector2(ORIGIN.x + branch["col"] * CELL.x, 4)
		plate.custom_minimum_size.x = NODE_SIZE.x + (int(branch["cols"]) - 1) * CELL.x
		plate.size.x = plate.custom_minimum_size.x
		canvas.add_child(plate)

func _node_position(upgrade : UpgradeStats) -> Vector2:
	return ORIGIN + upgrade.tree_position * CELL

func _branch_color(upgrade : UpgradeStats) -> Color:
	for branch : Dictionary in BRANCHES:
		var first : int = int(branch["col"])
		if (upgrade.tree_position.x >= first and upgrade.tree_position.x < first + int(branch["cols"])):
			return branch["color"]
	return CYAN

func _hover_start(upgrade : UpgradeStats) -> void:
	hovered = upgrade
	tip_timer.start(TIP_DELAY)

func _hover_end(upgrade : UpgradeStats) -> void:
	if (hovered == upgrade):
		hovered = null
		tip_timer.stop()
		_hide_tip()

func _show_tip() -> void:
	if (hovered == null):
		return
	_hide_tip()
	tip = _build_tooltip(hovered)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.z_index = 100
	tip.modulate.a = 0.0
	add_child(tip)
	_settle_tip.call_deferred(tip)

func _settle_tip(shown : Control) -> void:
	if (!is_instance_valid(shown) or shown != tip):
		return
	shown.reset_size()
	_follow_mouse()
	shown.modulate.a = 1.0

func _hide_tip() -> void:
	if (tip != null):
		tip.queue_free()
		tip = null

func _follow_mouse() -> void:
	if (tip == null):
		return
	var viewport : Vector2 = get_viewport_rect().size
	var target : Vector2 = get_local_mouse_position() + TIP_OFFSET
	if (target.x + tip.size.x > viewport.x):
		target.x = get_local_mouse_position().x - TIP_OFFSET.x - tip.size.x
	if (target.y + tip.size.y > viewport.y):
		target.y = get_local_mouse_position().y - TIP_OFFSET.y - tip.size.y
	tip.position = target.floor()

func _process(_delta : float) -> void:
	_follow_mouse()

func _build_tooltip(upgrade : UpgradeStats) -> Control:
	var stats : PlayerStats = Global.player_stats
	var tint : Color = _branch_color(upgrade)
	var state : NodeState = _state_of(upgrade)
	var level : int = stats.get_upgrade_level(upgrade)
	var panel : PanelContainer = PanelContainer.new()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var box : StyleBoxFlat = _style(Color("#0b1419"), tint, 2)
	for side : String in ["left", "right", "top", "bottom"]:
		box.set("content_margin_" + side, 10.0)
	panel.add_theme_stylebox_override("panel", box)
	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size.x = 232
	panel.add_child(col)

	var head : HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var icon : Texture2D = _icon_for(upgrade)
	head.add_child(_silhouette(icon, tint, maxi(1, 24 / int(icon.get_size().x))))
	var title : Label = _tip_label(upgrade.name_key, tint)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	col.add_child(head)
	col.add_child(ColorRect.new())
	var rule : ColorRect = col.get_child(col.get_child_count() - 1)
	rule.color = STEEL
	rule.custom_minimum_size.y = 2

	var desc : Label = _tip_label(upgrade.description_key, Color("#c4cdd0"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc)

	var lv : HBoxContainer = HBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	lv.add_child(_tip_label("LV %d/%d" % [level, upgrade.max_level], TEXT))
	var pips : HBoxContainer = HBoxContainer.new()
	pips.add_theme_constant_override("separation", 2)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i : int in upgrade.max_level:
		var pip : ColorRect = ColorRect.new()
		pip.custom_minimum_size = Vector2(6, 6)
		pip.color = tint if i < level else WELL.lightened(0.18)
		pips.add_child(pip)
	lv.add_child(pips)
	var gap : Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(gap)
	col.add_child(lv)

	var foot : HBoxContainer = lv
	foot.add_theme_constant_override("separation", 4)
	if (state == NodeState.MAXED):
		foot.add_child(_silhouette(ICON_CHECK, tint))
		foot.add_child(_tip_label("research.max", tint))
	elif (state == NodeState.LOCKED):
		foot.add_child(_tip_label("research.locked", DIM))
	else:
		var color : Color = AMBER.darkened(0.4) if state == NodeState.UNAFFORDABLE else AMBER
		foot.add_child(_tip_label("research.next", DIM))
		foot.add_child(_tip_label(str(upgrade.gears_for_level(level + 1)), color))
		foot.add_child(_silhouette(GEAR_ICON, color))
		var coins : int = upgrade.boss_coins_for_level(level + 1)
		if (coins > 0):
			foot.add_child(_tip_label("+%d" % coins, BOSS))
			foot.add_child(_silhouette(ICON_BOSS, BOSS))
	return panel

func _tip_label(text : String, color : Color) -> Label:
	var label : Label = _label(text, color)
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 8)
	return label

func _icon_for(upgrade : UpgradeStats) -> Texture2D:
	if (upgrade.icon != null):
		return upgrade.icon
	if (STAT_ICONS.has(upgrade.stat)):
		return STAT_ICONS[upgrade.stat]
	if (upgrade.target == Enums.UpgradeTarget.BASE):
		return ICON_ECONOMY
	return ICON_UNIT

func _build_nodes(canvas : Control) -> void:
	for item : Variant in Global.CATALOG.research:
		var upgrade : UpgradeStats = item
		var button : Button = Button.new()
		button.mouse_entered.connect(_hover_start.bind(upgrade))
		button.mouse_exited.connect(_hover_end.bind(upgrade))
		button.position = _node_position(upgrade)
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.pressed.connect(_buy.bind(upgrade))

		var margin : MarginContainer = MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side : String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 6)
		button.add_child(margin)
		var col : VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(col)

		var head : HBoxContainer = HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(head)
		var well : PanelContainer = PanelContainer.new()
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.custom_minimum_size = Vector2(ICON_WELL, ICON_WELL)
		well.add_theme_stylebox_override("panel", _style(WELL, STEEL))
		var icon : Texture2D = _icon_for(upgrade)
		var stage : Control = Control.new()
		stage.name = "Stage"
		stage.clip_contents = true
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(stage)
		var screen : ColorRect = ColorRect.new()
		screen.name = "Screen"
		screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var screen_material : ShaderMaterial = ShaderMaterial.new()
		screen_material.shader = DISPLAY_SHADER
		screen.material = screen_material
		screen.resized.connect(func() -> void: screen_material.set_shader_parameter("rect_size", screen.size))
		stage.add_child(screen)
		screen.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var glyph : TextureRect = _silhouette(icon, CYAN, maxi(1, ICON_DRAW / int(icon.get_size().x)))
		glyph.name = "Glyph"
		var center : CenterContainer = CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(center)
		center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		center.add_child(glyph)
		head.add_child(well)

		var meta : VBoxContainer = VBoxContainer.new()
		meta.add_theme_constant_override("separation", 4)
		meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meta.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_child(meta)
		var level : Label = _label("")
		level.name = "Level"
		meta.add_child(level)
		var pips : HBoxContainer = HBoxContainer.new()
		pips.name = "Pips"
		pips.add_theme_constant_override("separation", 2)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta.add_child(pips)
		for i : int in upgrade.max_level:
			var pip : ColorRect = ColorRect.new()
			pip.custom_minimum_size = Vector2(6 if upgrade.max_level <= 6 else 3, 4)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips.add_child(pip)

		var name_label : Label = _label(upgrade.name_key)
		name_label.name = "Name"
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.max_lines_visible = 2
		name_label.clip_text = true
		name_label.custom_minimum_size.y = 20
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(name_label)

		var cost : HBoxContainer = HBoxContainer.new()
		cost.name = "Cost"
		cost.add_theme_constant_override("separation", 3)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(cost)

		canvas.add_child(button)
		node_buttons[upgrade] = button
		for req_item : Variant in upgrade.requires:
			var req : UpgradeStats = req_item
			lines.links.append({
				"from": Rect2(_node_position(req), NODE_SIZE),
				"to": Rect2(_node_position(upgrade), NODE_SIZE),
				"req": req,
				"color": _branch_color(upgrade),
				"active": false,
			})

func _buy(upgrade : UpgradeStats) -> void:
	if (Global.player_stats.buy_upgrade(upgrade)):
		UiSfx.play(&"upgrade_installed")
		Global.save_game()
		_refresh()

func _state_of(upgrade : UpgradeStats) -> NodeState:
	var stats : PlayerStats = Global.player_stats
	if (stats.get_upgrade_level(upgrade) >= upgrade.max_level):
		return NodeState.MAXED
	if (!_requirements_met(upgrade)):
		return NodeState.LOCKED
	if (!stats.can_buy_upgrade(upgrade)):
		return NodeState.UNAFFORDABLE
	return NodeState.AVAILABLE

func _skin(button : Button, state : NodeState, tint : Color) -> void:
	var face : Color = PANEL
	var edge : Color = STEEL
	match state:
		NodeState.AVAILABLE:
			face = Color("#1c2a32")
			edge = tint
		NodeState.UNAFFORDABLE:
			face = Color("#1a2227")
			edge = tint.darkened(0.45)
		NodeState.MAXED:
			face = tint.darkened(0.8)
			edge = tint
		NodeState.LOCKED:
			face = Color("#10181d")
			edge = Color("#27343b")
	button.add_theme_stylebox_override("normal", _style(face, edge, 2 if state == NodeState.AVAILABLE else 1))
	button.add_theme_stylebox_override("hover", _style(face.lightened(0.1), edge.lightened(0.2), 2))
	button.add_theme_stylebox_override("pressed", _style(face.darkened(0.25), edge, 2))
	button.add_theme_stylebox_override("disabled", _style(face, edge))
	var focus : StyleBoxFlat = _style(Color.TRANSPARENT, CYAN)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)

func _refresh() -> void:
	var stats : PlayerStats = Global.player_stats
	gear_value.text = str(stats.gear)
	coin_value.text = str(stats.boss_coin)
	for upgrade : UpgradeStats in node_buttons:
		var button : Button = node_buttons[upgrade]
		var state : NodeState = _state_of(upgrade)
		var tint : Color = _branch_color(upgrade)
		_skin(button, state, tint)
		button.disabled = state == NodeState.MAXED
		var main : Color = TEXT
		var accent : Color = tint
		match state:
			NodeState.LOCKED:
				main = DIM
				accent = Color("#4a5a62")
			NodeState.UNAFFORDABLE:
				accent = tint.darkened(0.3)
		var level : int = stats.get_upgrade_level(upgrade)
		var col : VBoxContainer = button.get_child(0).get_child(0)
		var head : HBoxContainer = col.get_child(0)
		var well : Control = head.get_child(0)
		var glyph : TextureRect = well.get_node("Stage").get_child(1).get_child(0)
		var glyph_material : ShaderMaterial = glyph.material as ShaderMaterial
		glyph_material.set_shader_parameter("tint", accent)
		var screen_material : ShaderMaterial = well.get_node("Stage/Screen").material as ShaderMaterial
		screen_material.set_shader_parameter("line_color", accent)
		screen_material.set_shader_parameter("band_strength", 0.0 if state == NodeState.LOCKED else 1.0)
		var meta : VBoxContainer = head.get_child(1)
		var level_label : Label = meta.get_node("Level")
		level_label.text = PixelText.fit("LV %d/%d" % [level, upgrade.max_level], 8)
		level_label.add_theme_color_override("font_color", main)
		var pips : HBoxContainer = meta.get_node("Pips")
		for i : int in pips.get_child_count():
			(pips.get_child(i) as ColorRect).color = accent if i < level else WELL.lightened(0.18)
		var name_label : Label = col.get_node("Name")
		name_label.add_theme_color_override("font_color", main)
		_fill_cost(col.get_node("Cost"), upgrade, level, state, tint)
	for link : Dictionary in lines.links:
		link["active"] = stats.get_upgrade_level(link["req"]) >= 1
	lines.queue_redraw()
	if (tip != null and hovered != null):
		_show_tip()

func _fill_cost(cost : HBoxContainer, upgrade : UpgradeStats, level : int, state : NodeState, tint : Color) -> void:
	for child : Node in cost.get_children():
		cost.remove_child(child)
		child.queue_free()
	if (state == NodeState.MAXED):
		cost.add_child(_silhouette(ICON_CHECK, tint))
		cost.add_child(_label("research.max", tint))
		return
	var color : Color = DIM if state == NodeState.LOCKED else (AMBER.darkened(0.4) if state == NodeState.UNAFFORDABLE else AMBER)
	var coin_color : Color = DIM if state == NodeState.LOCKED else (BOSS.darkened(0.4) if state == NodeState.UNAFFORDABLE else BOSS)
	cost.add_child(_label(str(upgrade.gears_for_level(level + 1)), color))
	cost.add_child(_silhouette(GEAR_ICON, color))
	var coins : int = upgrade.boss_coins_for_level(level + 1)
	if (coins > 0):
		cost.add_child(_label("+%d" % coins, coin_color))
		cost.add_child(_silhouette(ICON_BOSS, coin_color))

func _requirements_met(upgrade : UpgradeStats) -> bool:
	for req_item : Variant in upgrade.requires:
		var req : UpgradeStats = req_item
		if (Global.player_stats.get_upgrade_level(req) < 1):
			return false
	return true
