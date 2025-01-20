class_name BoatStats
extends EntityStats

@export_subgroup("Ship Water Properties")
@export
var deceleration: float = 0.5
@export
var max_tilt_angle: float = 0.2
@export_range(0, 1)
var knockback_resistance: float = 0

@export_group("Rect Properties")
@export_subgroup("Water Colision Shape")
@export
var water_colision_shape : RectangleShape2D
@export
var water_colision_pos : Vector2
