class_name BoatStats
extends EntityStats

@export_subgroup("Ship Water Properties")
@export
var deceleration: float = 0.5
@export
var max_tilt_angle: float = 0.2
@export_range(0, 1)
var knockback_resistance: float = 0

@export_group("Combat Role")
@export
var surface_damage_mult : float = -1.0
@export
var base_damage_override : float = -1.0
@export
var prefers_air : bool = false
@export
var prefers_submerged : bool = false
@export
var air_hunter : bool = false
@export
var uses_flares : bool = true
@export
var retreats_from_ships : bool = false
@export
var fire_interval_mult : float = 1.0
@export
var build_time_mult : float = 1.0
@export
var damage_mult : float = 1.0

@export_group("Submarine")
@export
var can_submerge : bool = false
@export
var submerged_sprite : Texture2D
@export
var dive_distance : float = 110.0
@export
var hide_guns : bool = false
@export
var surfaces_for_air : bool = false
@export
var box_radar : bool = false

@export_group("Rect Properties")
@export_subgroup("Water Colision Shape")
@export
var water_colision_shape : RectangleShape2D
@export
var water_colision_pos : Vector2
