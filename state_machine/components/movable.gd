class_name Movable
extends Node

@export
var direction : int = 1

# When a wall is touched, move in the opposite direction
func get_movement_direction() -> float:
	return direction
