class_name Gun
extends Node2D

@export
var time_to_shoot : int = 50

var team : int = -1

signal fired_bullet(bullet : Bullet, position : Vector2, direction : Vector2)

@onready 
var bullet = preload("res://scenes/entities/guns/bullet.tscn")

@onready 
var audio = $AudioStreamPlayer2D

@onready
var end_barrel = $EndBarrel

var enemy : Node2D

func _physics_process(delta: float) -> void:
	if enemy:
		look_at(enemy.global_position)

func shoot_gun(direction: Vector2):
	if enemy:
		var bullet_instance = bullet.instantiate()
		bullet_instance.team = team
		EventBus.bullet_fired(bullet_instance, end_barrel.global_position, direction, rotation)
		audio.pitch_scale = randf_range(0.5, 1.5)
	else:
		push_error("Trying to shoot without enemy defined")
	#audio.play(0)
