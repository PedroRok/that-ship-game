class_name Gun
extends Node2D

var team : int = -1

signal fired_bullet(bullet : Bullet, position : Vector2, direction : Vector2)

@onready 
var bullet = preload("res://scenes/entities/guns/bullet.tscn")

@onready 
var audio = $AudioStreamPlayer2D

@onready
var end_barrel = $EndBarrel

func shoot_gun(direction: Vector2):
	var bullet_instance = bullet.instantiate()
	bullet_instance.team = team
	EventBus.bullet_fired(bullet_instance, end_barrel.global_position, direction)
	audio.pitch_scale = randf_range(0.5, 1.5)
	#audio.play(0)
