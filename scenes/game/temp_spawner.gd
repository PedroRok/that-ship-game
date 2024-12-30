extends Node2D

@onready
var small_boat = preload("res://scenes/entities/small-boat/small_boat.tscn")
@onready
var small_boat_resource = preload("res://core/resources/boats/small_boat.tres")
@onready
var team_resource = preload("res://core/resources/teams/team_right.tres")

func _ready() -> void:
	_on_spawner_timeout()

func _on_spawner_timeout() -> void:
	var boat  = small_boat.instantiate() as SmallBoat
	if boat:
		boat.set_team(team_resource)
		boat.set_stats(small_boat_resource)
		add_child(boat)
		boat.global_position = position
	pass # Replace with function body.
