class_name EntityStats
extends Resource


@export_group("Game Properties")
@export
var health: float = 10
@export
var radar_distance: int = 100
@export
var speed: float = 400

@export_group("Object Properties")
@export
var name: String
@export
var price: int = 5
@export
var produce_cd: int = 5

@export_category("Entity Object")
@export
var sprite: Texture2D
@export
var center: Vector2
@export
var gun_slots : Array[GunSlot]

@export_group("Rect Properties")
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
