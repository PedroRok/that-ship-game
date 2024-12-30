extends Node2D

@onready
var small_boat = preload("res://scenes/entities/small-boat/small_boat.tscn")
@onready
var small_boat_resource = preload("res://core/resources/boats/small_boat.tres")
@onready
var team_resource = preload("res://core/resources/teams/team_left.tres")
func _ready() -> void:
	EventBus.connect("spawn_ship", Callable(self, "handle_ship_spawn"))
	pass
	
func handle_ship_spawn():
	var boat  = small_boat.instantiate() as SmallBoat
	if boat:
		boat.set_team(team_resource)
		boat.set_stats(small_boat_resource)
		add_child(boat)
		boat.global_position = position
	pass
