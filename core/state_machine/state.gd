class_name State
extends Node

@export
var move_speed: float = 400
@export 
var deceleration: float = 1.0
# Ângulo máximo de inclinação em radianos (ex.: 0.2 rad = ~11.5 graus)
@export 
var max_tilt_angle: float = 0.2

var parent : Ship

signal Transitioned

func enter() -> void:
	pass
	
func exit() -> void:
	pass
	
func process_input(event: InputEvent) -> void:
	return
	
func process_frame(delta: float) -> void:
	return
	
func process_physics(delta: float) -> void:
	parent.rotation = lerp(parent.rotation, -parent.linear_velocity.x / move_speed * max_tilt_angle, deceleration * delta)
	if (parent.linear_velocity.x == 0.):
		parent.rotation = lerp(parent.rotation, 0., deceleration * delta)
	parent.linear_velocity.x = lerp(parent.linear_velocity.x, 0., deceleration * delta)
	return
