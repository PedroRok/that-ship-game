class_name HealthBar
extends Node2D

const COLOR_BORDER : Color = Color("090b0c")
const COLOR_BACK : Color = Color("1b2127")
const COLOR_HIGH : Color = Color("6fcf7a")
const COLOR_MID : Color = Color("e6c84a")
const COLOR_LOW : Color = Color("d9534f")

var entity : Entity
var health : HealthComponent
var bar_width : float = 20.0
var bar_height : float = 3.0
var y_offset : float = -16.0
var _drawn_ratio : float = -1.0

func setup(target : Entity, health_component : HealthComponent) -> void:
	entity = target
	health = health_component
	top_level = true
	z_index = 1700
	var stats : EntityStats = entity.entity_stats
	var sprite_w : float = 24.0
	var sprite_h : float = 16.0
	if (stats.sprite):
		sprite_w = stats.sprite.get_width()
		sprite_h = stats.sprite.get_height()
	bar_width = clampf(roundf(sprite_w * 0.5), 14.0, 40.0)
	if (stats.is_boss):
		bar_width = clampf(bar_width * 1.6, 30.0, 60.0)
		bar_height = 4.0
	y_offset = -(sprite_h * 0.5 + 7.0)
	if (stats is AirPlaneState):
		y_offset = -16.0

func _process(_delta : float) -> void:
	if (!is_instance_valid(entity)):
		queue_free()
		return
	var depth : Variant = entity.get("dive_offset")
	global_position = entity.global_position + Vector2(0, y_offset + (float(depth) if depth != null else 0.0))
	global_rotation = 0.0
	visible = health.actual_health > 0.0 and entity.enabled
	var ratio : float = clampf(health.actual_health / maxf(health.default_health, 0.01), 0.0, 1.0)
	if (ratio != _drawn_ratio):
		_drawn_ratio = ratio
		queue_redraw()

func _draw() -> void:
	if (!health):
		return
	var ratio : float = clampf(health.actual_health / maxf(health.default_health, 0.01), 0.0, 1.0)
	var w : float = bar_width
	var h : float = bar_height
	var origin : Vector2 = Vector2(roundf(-w * 0.5), 0.0)
	draw_rect(Rect2(origin - Vector2(1, 1), Vector2(w + 2, h + 2)), COLOR_BORDER)
	draw_rect(Rect2(origin, Vector2(w, h)), COLOR_BACK)
	var fill : Color = COLOR_HIGH
	if (ratio < 0.3):
		fill = COLOR_LOW
	elif (ratio < 0.6):
		fill = COLOR_MID
	var fill_w : float = roundf(w * ratio)
	if (ratio > 0.0):
		fill_w = maxf(fill_w, 1.0)
	draw_rect(Rect2(origin, Vector2(fill_w, h)), fill)
	draw_rect(Rect2(origin, Vector2(fill_w, 1)), fill.lightened(0.35))
