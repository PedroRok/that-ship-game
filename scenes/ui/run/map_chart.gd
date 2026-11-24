class_name MapChart
extends Control

signal node_activated(id : int)

const CHART_SIZE : Vector2 = Vector2(824, 328)
const COLUMN_X : Array[int] = [85, 244, 404, 563, 736]
const ROW_Y : Array[int] = [75, 165, 255]
const NODE_SIZE : float = 48.0

const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")
const ROUTE_TRAVELED : Color = Color("#78dddd")
const ROUTE_TRAVELED_BASE : Color = Color("#1b686e")
const ROUTE_FOCUS : Color = Color("#ecc078")
const ROUTE_AVAILABLE : Color = Color("#6b99a4")
const ROUTE_LOCKED : Color = Color("#3c5b66")

var run : RunState
var buttons : Dictionary = {}
var routes : Control

func setup(new_run : RunState) -> void:
	run = new_run
	custom_minimum_size = CHART_SIZE
	size = CHART_SIZE
	var background : TextureRect = TextureRect.new()
	background.texture = load("res://assets/ui/run_map/radar_chart_v01.png") as Texture2D
	background.stretch_mode = TextureRect.STRETCH_KEEP
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var compass : TextureRect = TextureRect.new()
	compass.texture = load("res://assets/ui/run_map/compass_n_v01.png") as Texture2D
	compass.position = Vector2(CHART_SIZE.x - 90, 28)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(compass)
	routes = Control.new()
	routes.name = "Routes"
	routes.size = CHART_SIZE
	routes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	routes.draw.connect(_draw_all)
	add_child(routes)
	var headers : Array[String] = ["01", "02", "03", "04", "BOSS"]
	for col : int in headers.size():
		var label : Label = Label.new()
		label.text = str(headers[col]).to_upper()
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color("#7795a1"))
		label.position = Vector2(COLUMN_X[col] - 20, 8)
		label.size = Vector2(40, 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	var overlay : Control = Control.new()
	overlay.name = "Nodes"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	for entry : Dictionary in run.map.nodes:
		var button : MapNodeButton = MapNodeButton.new()
		var id : int = int(entry["id"])
		button.setup(run, id)
		button.position = node_center(id) - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
		button.activated.connect(func(node_id : int) -> void: node_activated.emit(node_id))
		overlay.add_child(button)
		buttons[id] = button
	refresh()

func node_center(id : int) -> Vector2:
	var entry : Dictionary = run.map.get_node(id)
	var col : int = int(entry["col"])
	var row : int = int(entry["row"])
	return Vector2(COLUMN_X[col], ROW_Y[row])

func refresh() -> void:
	for id : int in buttons:
		(buttons[id] as MapNodeButton).refresh()
	routes.queue_redraw()

func _route_kind(from_id : int, to_id : int) -> String:
	var from_index : int = run.history.find(from_id)
	if (from_index >= 0 and from_index + 1 < run.history.size() and run.history[from_index + 1] == to_id):
		return "traveled"
	var origin_ok : bool = (run.current_node < 0 and run.map.column_of(from_id) == 0) or from_id == run.current_node
	if (origin_ok and run.is_reachable(to_id)):
		return "focus" if to_id == run.focus_node else "available"
	return "locked"

func _draw_all() -> void:
	if (run == null):
		return
	var order : Array[String] = ["locked", "available", "focus", "traveled"]
	for kind : String in order:
		for from_id : Variant in run.map.edges:
			for to_id : int in run.map.next_ids(int(from_id)):
				if (_route_kind(int(from_id), to_id) == kind):
					_draw_route(node_center(int(from_id)), node_center(to_id), kind)

func _draw_route(from_pos : Vector2, to_pos : Vector2, kind : String) -> void:
	var direction : Vector2 = (to_pos - from_pos).normalized()
	var start : Vector2 = from_pos + direction * 26.0
	var finish : Vector2 = to_pos - direction * 26.0
	match kind:
		"traveled":
			routes.draw_line(start, finish, ROUTE_TRAVELED_BASE, 5.0)
			routes.draw_line(start, finish, ROUTE_TRAVELED, 3.0)
		"focus":
			_dashed(start, finish, ROUTE_FOCUS, 3.0, 8.0, 6.0)
		"available":
			_dashed(start, finish, ROUTE_AVAILABLE, 2.0, 6.0, 6.0)
		_:
			_dashed(start, finish, ROUTE_LOCKED, 1.0, 4.0, 6.0)

func _dashed(from_pos : Vector2, to_pos : Vector2, color : Color, width : float, dash : float, gap : float) -> void:
	var length : float = from_pos.distance_to(to_pos)
	var direction : Vector2 = (to_pos - from_pos) / maxf(length, 0.001)
	var travelled : float = 0.0
	while (travelled < length):
		var segment_end : float = minf(travelled + dash, length)
		routes.draw_line(from_pos + direction * travelled, from_pos + direction * segment_end, color, width)
		travelled += dash + gap
