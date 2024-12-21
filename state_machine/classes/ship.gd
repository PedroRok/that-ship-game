class_name Ship
extends RigidBody2D

@export
var direction : int = 1

@export
var team : int = 0

@export
var life : int = 10

func get_gun() -> Gun:
	return null
	
func handle_hit():
	prints(life)
	life -= 1
