class_name ResearchMenu
extends Control

const CELL : Vector2 = Vector2(138, 112)
const NODE_SIZE : Vector2 = Vector2(126, 88)
const ORIGIN : Vector2 = Vector2(8, 36)

const BRANCHES : Array[Dictionary] = [
	{"title": "ECONOMY", "col": 0},
	{"title": "BASE", "col": 2},
	{"title": "UNITS", "col": 3},
	{"title": "WEAPONS", "col": 5},
	{"title": "SKILLS", "col": 7},
]

class TreeLines extends Control:
	var links : Array[Dictionary] = []

	func _draw() -> void:
		for link : Dictionary in links:
			var color : Color = Color(0.45, 0.85, 0.5) if link["active"] else Color(0.4, 0.4, 0.45)
			var from_rect : Rect2 = link["from"]
			var to_rect : Rect2 = link["to"]
			var points : PackedVector2Array
			if (is_equal_approx(from_rect.position.y, to_rect.position.y)):
				var y : float = from_rect.get_center().y
				var start_x : float = from_rect.end.x if to_rect.position.x > from_rect.position.x else from_rect.position.x
				var end_x : float = to_rect.position.x if to_rect.position.x > from_rect.position.x else to_rect.end.x
				points = PackedVector2Array([Vector2(start_x, y), Vector2(end_x, y)])
			else:
				var start : Vector2 = Vector2(from_rect.get_center().x, from_rect.end.y)
				var end : Vector2 = Vector2(to_rect.get_center().x, to_rect.position.y)
				var mid_y : float = (start.y + end.y) / 2.0
				points = PackedVector2Array([start, Vector2(start.x, mid_y), Vector2(end.x, mid_y), end])
			draw_polyline(points, color, 3.0)

var info_label : Label
var lines : TreeLines
var node_buttons : Dictionary = {}

func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size

	var bg : ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin : MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side : String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root : VBoxContainer = VBoxContainer.new()
	margin.add_child(root)
	root.add_child(_build_top_bar())

	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var canvas : Control = Control.new()
	canvas.custom_minimum_size = ORIGIN + Vector2(9, 4) * CELL + Vector2(0, 8)
	scroll.add_child(canvas)

	lines = TreeLines.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(lines)

	_build_branch_labels(canvas)
	_build_nodes(canvas)
	_refresh()

func _build_top_bar() -> HBoxContainer:
	var bar : HBoxContainer = HBoxContainer.new()
	var title : Label = Label.new()
	title.text = "RESEARCH"
	title.custom_minimum_size.x = 200
	bar.add_child(title)
	info_label = Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(info_label)
	var back : Button = Button.new()
	back.text = "BACK TO SHOP"
	back.custom_minimum_size = Vector2(220, 36)
	back.pressed.connect(func() -> void: Global.change_scene(Global.Menu.SHOP))
	bar.add_child(back)
	return bar

func _build_branch_labels(canvas : Control) -> void:
	for branch : Dictionary in BRANCHES:
		var label : Label = Label.new()
		label.text = branch["title"]
		label.add_theme_font_size_override("font_size", 8)
		label.position = Vector2(ORIGIN.x + branch["col"] * CELL.x, 8)
		canvas.add_child(label)

func _node_position(upgrade : UpgradeStats) -> Vector2:
	return ORIGIN + upgrade.tree_position * CELL

func _build_nodes(canvas : Control) -> void:
	for item : Variant in Global.CATALOG.research:
		var upgrade : UpgradeStats = item
		var button : Button = Button.new()
		button.position = _node_position(upgrade)
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.tooltip_text = upgrade.description_key
		button.pressed.connect(_buy.bind(upgrade))
		var box : VBoxContainer = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 6)
		button.add_child(box)
		for i : int in 3:
			var line : Label = Label.new()
			line.name = "Line%d" % i
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.add_theme_font_size_override("font_size", 8)
			line.add_theme_color_override("font_color", Color(0.08, 0.09, 0.12))
			box.add_child(line)
		canvas.add_child(button)
		node_buttons[upgrade] = button
		for req_item : Variant in upgrade.requires:
			var req : UpgradeStats = req_item
			lines.links.append({
				"from": Rect2(_node_position(req), NODE_SIZE),
				"to": Rect2(_node_position(upgrade), NODE_SIZE),
				"req": req,
				"active": false,
			})

func _buy(upgrade : UpgradeStats) -> void:
	if (Global.player_stats.buy_upgrade(upgrade)):
		Global.save_game()
		_refresh()

func _refresh() -> void:
	var stats : PlayerStats = Global.player_stats
	info_label.text = "Gears: %d    Boss coins: %d" % [stats.gear, stats.boss_coin]
	for upgrade : UpgradeStats in node_buttons:
		var button : Button = node_buttons[upgrade]
		var box : VBoxContainer = button.get_child(0)
		var level : int = stats.get_upgrade_level(upgrade)
		(box.get_node("Line0") as Label).text = upgrade.name_key
		(box.get_node("Line1") as Label).text = "Lv %d/%d" % [level, upgrade.max_level]
		var cost_text : String
		if (level >= upgrade.max_level):
			cost_text = "MAX"
			button.self_modulate = Color(0.6, 1.0, 0.6)
		else:
			cost_text = "%d gears" % upgrade.gears_for_level(level + 1)
			var coins : int = upgrade.boss_coins_for_level(level + 1)
			if (coins > 0):
				cost_text += " +%d coin" % coins
			if (!_requirements_met(upgrade)):
				button.self_modulate = Color(0.45, 0.45, 0.5)
			elif (!stats.can_buy_upgrade(upgrade)):
				button.self_modulate = Color(1.0, 0.7, 0.7)
			else:
				button.self_modulate = Color.WHITE
		(box.get_node("Line2") as Label).text = cost_text
	for link : Dictionary in lines.links:
		link["active"] = stats.get_upgrade_level(link["req"]) >= 1
	lines.queue_redraw()

func _requirements_met(upgrade : UpgradeStats) -> bool:
	for req_item : Variant in upgrade.requires:
		var req : UpgradeStats = req_item
		if (Global.player_stats.get_upgrade_level(req) < 1):
			return false
	return true
