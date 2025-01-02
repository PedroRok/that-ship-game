extends Node2D

@onready
var small_boat = preload("res://scenes/entities/small-boat/small_boat.tscn")
@onready
var small_boat_resource = preload("res://core/resources/boats/small_boat.tres")
@onready
var team_resource = preload("res://core/resources/teams/team_right.tres")
@onready
var gun = preload("res://scenes/entities/guns/gun.tscn")

func _ready() -> void:
	_on_spawner_timeout()

func _on_spawner_timeout() -> void:
	var boat  = small_boat.instantiate() as SmallBoat
	if boat:
		boat.team_stats = team_resource
		boat.boat_stats = small_boat_resource
		add_child(boat)
		for slots in boat.boat_stats.gun_slots:
			boat.add_new_gun(gun.instantiate())
			pass
		boat.global_position = position
	pass # Replace with function body.
