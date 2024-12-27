class_name State
extends Node

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
	
var current_speed = 0.0
	
func process_physics(delta: float) -> void:
	parent.rotation = lerp(parent.rotation, -parent.linear_velocity.x / parent.boat_stats.speed * parent.boat_stats.max_tilt_angle, parent.boat_stats.deceleration * delta)
	if (parent.linear_velocity.x == 0.):
		parent.rotation = lerp(parent.rotation, 0., parent.boat_stats.deceleration * delta)
	parent.linear_velocity.x = lerp(parent.linear_velocity.x, 0., parent.boat_stats.deceleration * delta)
	return
