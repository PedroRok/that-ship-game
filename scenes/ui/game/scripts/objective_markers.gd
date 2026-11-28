class_name ObjectiveMarkers
extends Control

const SIDE_MARGIN : float = 32.0
const TOP_LIMIT : float = 80.0
const BOTTOM_LIMIT : float = 508.0
const EXPAND_SECONDS : float = 3.5
const ARROW_PIXELS : int = 14
const ARROW_SCALE : int = 2
const DISPLAY_SIZE : Vector2 = Vector2(128, 48)

var provider : Callable
var expand_seconds : float = EXPAND_SECONDS
var _markers : Dictionary = {}
var _ages : Dictionary = {}
var _arrows : Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta : float) -> void:
	var screen : Rect2 = Rect2(Vector2.ZERO, get_viewport_rect().size)
	var inner : Rect2 = screen.grow(-SIDE_MARGIN)
	var transform : Transform2D = get_viewport().get_canvas_transform()
	var centre : Vector2 = screen.get_center()
	var shown : Dictionary = {}
	var targets : Array = provider.call() if provider.is_valid() else []
	for target : Dictionary in targets:
		var on_screen : Vector2 = transform * (target["pos"] as Vector2)
		if (screen.grow(-8.0).has_point(on_screen)):
			continue
		var key : Variant = target.get("id", target["label"])
		shown[key] = true
		_ages[key] = float(_ages.get(key, 0.0)) + delta
		var direction : Vector2 = (on_screen - centre).normalized()
		var octant : Vector2i = Vector2i(Vector2.from_angle(snappedf(direction.angle(), PI / 4.0)).round())
		var expanded : bool = float(_ages[key]) <= expand_seconds and target.get("unit") != null
		var state : Array = [octant, expanded]
		var entry : Dictionary = _markers.get(key, {})
		if (entry.is_empty() or entry["state"] != state):
			if (!entry.is_empty()):
				(entry["node"] as Control).queue_free()
			entry = {"node": _build(target, octant, expanded), "state": state}
			_markers[key] = entry
			add_child(entry["node"] as Control)
		var marker : Control = entry["node"]
		marker.reset_size()
		var place : Vector2 = _clamp_to_rect(centre, direction, inner) - marker.size * 0.5
		place.x = clampf(place.x, SIDE_MARGIN, screen.size.x - SIDE_MARGIN - marker.size.x)
		place.y = clampf(place.y, TOP_LIMIT, BOTTOM_LIMIT - marker.size.y)
		marker.position = place.floor()
	for key : Variant in _markers.keys():
		if (!shown.has(key)):
			((_markers[key] as Dictionary)["node"] as Control).queue_free()
			_markers.erase(key)

func _color_of(kind : String) -> Color:
	match kind:
		"ally":
			return BattleAlert.ALLY
		"target":
			return BattleAlert.OBJECTIVE
	return BattleAlert.THREAT

func _build(target : Dictionary, octant : Vector2i, expanded : bool) -> Control:
	var kind : String = str(target["kind"])
	var color : Color = _color_of(kind)
	var row : HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var module : PanelContainer = PanelContainer.new()
	module.mouse_filter = Control.MOUSE_FILTER_IGNORE
	module.add_theme_stylebox_override("panel", BattleAlert.box(color, 6 if expanded else 10))
	module.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var column : VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	module.add_child(column)
	column.add_child(BattleAlert.title_label(Loc.t(str(target["label"])), 8, color))
	if (expanded):
		var stats : EntityStats = target["unit"]
		var palette : DisplayPalette = DisplayPalette.of_unit(stats) if kind == "ally" else DisplayPalette.of_threat()
		column.add_child(BattleAlert.display(stats, palette, DISPLAY_SIZE))
	var arrow : TextureRect = TextureRect.new()
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.texture = _arrow(octant, color)
	arrow.custom_minimum_size = Vector2.ONE * ARROW_PIXELS * ARROW_SCALE
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_SCALE
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(module)
	row.add_child(arrow)
	if (octant.x < 0):
		row.move_child(arrow, 0)
	return row

func _arrow(octant : Vector2i, color : Color) -> Texture2D:
	var key : Array = [octant, color]
	if (_arrows.has(key)):
		return _arrows[key]
	var image : Image = Image.create_empty(ARROW_PIXELS, ARROW_PIXELS, false, Image.FORMAT_RGBA8)
	var way : Vector2 = Vector2(octant).normalized()
	var half : float = ARROW_PIXELS * 0.5
	for y : int in ARROW_PIXELS:
		for x : int in ARROW_PIXELS:
			var point : Vector2 = Vector2(x + 0.5 - half, y + 0.5 - half)
			var along : float = point.dot(way)
			var across : float = absf(point.cross(way))
			if (along >= -4.0 and along <= 6.0 and across <= (6.0 - along) * 0.7):
				image.set_pixel(x, y, color)
			elif (along >= -5.0 and along <= 7.0 and across <= (7.5 - along) * 0.7):
				image.set_pixel(x, y, Color("#090f15"))
	_arrows[key] = ImageTexture.create_from_image(image)
	return _arrows[key]

func _clamp_to_rect(origin : Vector2, direction : Vector2, rect : Rect2) -> Vector2:
	var scale_x : float = INF
	var scale_y : float = INF
	if (absf(direction.x) > 0.0001):
		scale_x = ((rect.end.x if direction.x > 0.0 else rect.position.x) - origin.x) / direction.x
	if (absf(direction.y) > 0.0001):
		scale_y = ((rect.end.y if direction.y > 0.0 else rect.position.y) - origin.y) / direction.y
	return origin + direction * minf(scale_x, scale_y)
