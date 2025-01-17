class_name BoatStats
extends Resource

@export_group("Object Properties")
@export
var name: String
@export
var price: int = 5
@export
var produce_cd: int = 5


@export_group("Game Properties")
@export
var health: float = 10
@export
var radar_distance: int = 100
@export_range(0, 1)
var knockback_resistance: float = 0

@export_subgroup("Water Properties")
@export
var speed: float = 400
@export
var deceleration: float = 0.5
@export
var max_tilt_angle: float = 0.2

@export_category("Ship Entity Object")

@export
var sprite: Texture2D
@export
var center: Vector2
@export
var gun_slots : Array[GunSlot]

@export_group("Rect Properties")
@export_subgroup("Water Colision Shape")
@export
var water_colision_shape : RectangleShape2D
@export
var water_colision_pos : Vector2

@export_subgroup("Hitbox Colision Shape")
@export
var hitbox_colision_shape : RectangleShape2D
@export
var hitbox_colision_pos : Vector2

@export_subgroup("Particles Shape")
@export
var particles_shape : RectangleShape2D
@export
var particles_pos : Vector2
