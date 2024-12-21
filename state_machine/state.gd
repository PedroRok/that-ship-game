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

var component_machine : ComponentMachine

func enter() -> void:
	pass
	
func exit() -> void:
	pass
	
func process_input(event: InputEvent) -> State:
	return null
	
func process_frame(delta: float) -> State:
	return null
	
func process_physics(delta: float) -> State:
	parent.rotation = -parent.linear_velocity.x / move_speed * max_tilt_angle
	if (parent.linear_velocity.x == 0.):
		parent.rotation = lerp(parent.rotation, 0., deceleration * delta)
	parent.linear_velocity.x = lerp(parent.linear_velocity.x, 0., deceleration * delta)
	return null

func get_movement_dir() -> float:
	return component_machine.get_movable().get_movement_direction()
	
func has_enemy_on_sight() -> bool:
	return false
