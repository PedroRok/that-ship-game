class_name BoatStats
extends Resource

@export
var health: float = 10
@export
var speed: float = 400
@export
var deceleration: float = 0.5
@export
var max_tilt_angle: float = 0.2
@export_range(0, 1)
var knockback_resistance: float = 0
@export
var sprite: Texture2D

@export
var gun_slots : Array[GunSlot]
