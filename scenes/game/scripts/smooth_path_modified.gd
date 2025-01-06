class_name SmoothPath
extends Path2D

@export var spline_length : int = 10

@export var width : int = 8

func straighten(value : float) -> void:
	if not value: return
	for i in curve.get_point_count():
		curve.set_point_in(i, Vector2())
		curve.set_point_out(i, Vector2())

func smooth(value : bool) -> void:
	if not value: return
	
	var point_count : int = curve.get_point_count()
	for i in point_count:
		var spline : Vector2 = _get_spline(i)
		curve.set_point_in(i, -spline)
		curve.set_point_out(i, spline)

func _get_spline(i : int) -> Vector2:
	var last_point : Vector2 = _get_point(i - 1)
	var next_point : Vector2 = _get_point(i + 1)
	var spline : Vector2 = last_point.direction_to(next_point) * spline_length
	return spline

func _get_point(i : int) -> Vector2:
	var point_count : int = curve.get_point_count()
	i = wrapi(i, 0, point_count - 1)
	return curve.get_point_position(i)

func _draw() -> void:
	var points : PackedVector2Array = curve.get_baked_points()
	if points:
		draw_polyline(points, Color.AQUA, width, true)
