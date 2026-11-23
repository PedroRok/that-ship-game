class_name ObjectiveMarkers
extends Control

const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")
const MARGIN : float = 30.0
const ARROWS : Dictionary = {
	"target": preload("res://assets/ui/hud/arrow_target_v01.png"),
	"enemy": preload("res://assets/ui/hud/arrow_enemy_v01.png"),
	"ally": preload("res://assets/ui/hud/arrow_ally_v01.png"),
}
const COLORS : Dictionary = {
	"target": Color("#ecc078"), "enemy": Color("#dfa0a2"), "ally": Color("#78dddd"),
}

var provider : Callable
var _targets : Array[Dictionary] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta : float) -> void:
	_targets.clear()
	if (provider.is_valid()):
		for entry : Variant in provider.call():
			_targets.append(entry)
	queue_redraw()

func _draw() -> void:
	var screen : Rect2 = Rect2(Vector2.ZERO, get_viewport_rect().size)
	var inner : Rect2 = screen.grow(-MARGIN)
	var transform : Transform2D = get_viewport().get_canvas_transform()
	var centre : Vector2 = screen.get_center()
	for target : Dictionary in _targets:
		var on_screen : Vector2 = transform * (target["pos"] as Vector2)
		if (screen.grow(-8.0).has_point(on_screen)):
			continue
		var direction : Vector2 = (on_screen - centre).normalized()
		var edge : Vector2 = _clamp_to_rect(centre, direction, inner)
		var kind : String = str(target["kind"])
		var arrow : Texture2D = ARROWS[kind]
		draw_set_transform(edge, direction.angle(), Vector2.ONE)
		draw_texture(arrow, -arrow.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var text : String = str(target["label"])
		var width : float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var label_pos : Vector2 = edge - direction * 34.0
		label_pos.x = clampf(label_pos.x - width * 0.5, 8.0, screen.size.x - width - 8.0)
		label_pos.y = clampf(label_pos.y + 4.0, 12.0, screen.size.y - 8.0)
		draw_string(FONT, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLORS[kind])

func _clamp_to_rect(origin : Vector2, direction : Vector2, rect : Rect2) -> Vector2:
	var scale_x : float = INF
	var scale_y : float = INF
	if (absf(direction.x) > 0.0001):
		scale_x = ((rect.end.x if direction.x > 0.0 else rect.position.x) - origin.x) / direction.x
	if (absf(direction.y) > 0.0001):
		scale_y = ((rect.end.y if direction.y > 0.0 else rect.position.y) - origin.y) / direction.y
	return origin + direction * minf(scale_x, scale_y)
