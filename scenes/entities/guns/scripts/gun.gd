class_name Gun
extends Node2D

@export
var time_to_shoot : int = 50
@export 
var bullet : PackedScene = preload("res://scenes/entities/bullets/bullet.tscn")
@export
var audio : AudioStreamPlayer2D

@export
var end_barrel : Marker2D

var current_time_to_shoot : int = 0;

signal fired_bullet(bullet : Bullet, direction : Vector2, position : Vector2, rotation : float)

var enemy : Node2D

signal gun_fired(bullet_instance : Bullet, global_position: Vector2, direction : Vector2, rotation : float)

func shoot_gun(direction: Vector2) -> void:
	if !end_barrel:
		push_error("Trying to shoot without a gun barrel")
		return
	if current_time_to_shoot > 0:
		current_time_to_shoot -= 1
		return
	current_time_to_shoot = time_to_shoot
	if enemy:
		var bullet_instance : Bullet = bullet.instantiate()
		bullet_instance.target = enemy
		if direction.x > 0:
			direction = direction.rotated(rotation)
		else:
			direction = -direction.rotated(rotation)
		fired_bullet.emit(bullet_instance, end_barrel.global_position, direction, rotation)
		play_effects()
	else:
		push_error("Trying to shoot without enemy defined")
		
	
	
func play_effects() -> void:
	if audio:
		audio.pitch_scale = randf_range(0.8, 1.2)
		var distance_based_on_zoom : float = (end_barrel.global_position.distance_to(Global.center_camera_pos)/ 1000)
		audio.play(distance_based_on_zoom/ (Global.camera_zoom))
