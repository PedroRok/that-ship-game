class_name BuildBar
extends Node2D

const COLOR_BORDER : Color = Color("090b0c")
const COLOR_BACK : Color = Color("1b2127")
const COLOR_FILL : Color = Color("4aa3ff")

var constructor : ShipConstructor
var bar_width : float = 20.0
var bar_height : float = 3.0
var y_offset : float = -16.0

func _ready() -> void:
	top_level = true
	z_index = 1700
	visible = false

func setup_for(stats : EntityStats) -> void:
	var sprite_w : float = 24.0
	var sprite_h : float = 16.0
	if (stats.sprite):
		sprite_w = stats.sprite.get_width()
		sprite_h = stats.sprite.get_height()
	bar_width = clampf(roundf(sprite_w * 0.5), 14.0, 40.0)
	bar_height = 3.0
	y_offset = -(sprite_h * 0.5 + 7.0)
	if (stats is AirPlaneState):
		y_offset = -16.0

func _process(_delta : float) -> void:
	var building : bool = constructor != null and constructor.is_building() and !constructor.boat_stats.is_boss
	visible = building
	if (!building):
		return
	global_position = constructor.global_position + Vector2(0, y_offset)
	global_rotation = 0.0
	queue_redraw()

func _draw() -> void:
	var ratio : float = clampf(float(constructor.material.get_shader_parameter("build_progress")), 0.0, 1.0)
	var origin : Vector2 = Vector2(roundf(-bar_width * 0.5), 0.0)
	draw_rect(Rect2(origin - Vector2(1, 1), Vector2(bar_width + 2, bar_height + 2)), COLOR_BORDER)
	draw_rect(Rect2(origin, Vector2(bar_width, bar_height)), COLOR_BACK)
	var fill_w : float = roundf(bar_width * ratio)
	if (ratio > 0.0):
		fill_w = maxf(fill_w, 1.0)
	draw_rect(Rect2(origin, Vector2(fill_w, bar_height)), COLOR_FILL)
	draw_rect(Rect2(origin, Vector2(fill_w, 1)), COLOR_FILL.lightened(0.35))
