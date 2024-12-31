class_name Ship
extends RigidBody2D

@export
var team_stats : TeamStats

@export
var boat_stats : BoatStats

var guns: Array[Gun] = []

func _ready() -> void:
	for node in get_children():
		if node is Gun:
			var gun = node as Gun
			guns.append(gun)
	pass
	

func get_guns() -> Array[Gun]:
	return guns

func set_team(team : TeamStats):
	team_stats = team
	
func set_stats(stats : BoatStats):
	boat_stats = stats
