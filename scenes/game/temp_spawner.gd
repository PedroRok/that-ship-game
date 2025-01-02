extends Node2D

@onready
var manager = $"../ShipsManager"

@onready
var team_right = preload("res://core/resources/teams/team_right.tres")

func _ready() -> void:
	_on_spawner_timeout()

func _on_spawner_timeout() -> void:
	manager.handle_ship_spawn_by_type(position, manager.ShipsTypes.SMALL, team_right)
	pass # Replace with function body.
