class_name AirEntity
extends Entity

@export
var animated_sprite : AnimatedSprite2D

@export
var animated_blades : AnimatedSprite2D

var gun : PackedScene = preload("res://scenes/entities/guns/simple_gun.tscn")

var is_dead : bool = false

func _ready() -> void:
	super._ready()
	animated_blades.play()
	for guns in get_guns():
		guns.fixed_angle = true
	
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var rotation_speed : float = 3.0  # Ajuste este valor para controlar a velocidade de rotação
	
	if (animated_sprite && !is_dead):
		animated_sprite.frame = map_rotation_to_value()
		check_direction_and_flip()
	pass

func get_actual_rotation_angle() -> float:
	return fmod(rotation_degrees + 360, 360)

func map_rotation_to_value() -> int:
	var rotation_dgr : float = get_actual_rotation_angle()
	var value : int = 5 * abs(sin(deg_to_rad(rotation_dgr)))
	return value
	
func check_direction_and_flip() -> void:
	var rotation_dgr : float = fmod(rotation_degrees + 360, 360)
	var is_facing_down : int = rotation_dgr > 90 and rotation_dgr < 270
	animated_sprite.flip_v = is_facing_down 
