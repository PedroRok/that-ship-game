class_name Base
extends Node

@export
var team_stats : TeamStats

@onready
var base_center : Node2D = $BaseCenter

func get_center_pos() -> Vector2:
	return base_center.global_position
