class_name State
extends Node

var parent : Entity 

signal Transitioned

func enter() -> void:
	pass
	
func exit() -> void:
	pass
	
func process_input(_event: InputEvent) -> void:
	return
	
func process_frame(_delta: float) -> void:
	return
	
var current_speed : float = 0.0
	
func process_physics(delta: float) -> void:
	parent.rotation = lerp(parent.rotation, -parent.linear_velocity.x / parent.entity_stats.speed * parent.entity_stats.max_tilt_angle, parent.entity_stats.deceleration * delta)
	if (parent.linear_velocity.x == 0.):
		parent.rotation = lerp(parent.rotation, 0., parent.entity_stats.deceleration * delta)
	parent.linear_velocity.x = lerp(parent.linear_velocity.x, 0., parent.entity_stats.deceleration * delta)
	return
