class_name Ship
extends RigidBody2D

@export
var team_stats : TeamStats

@export
var boat_stats : BoatStats

func get_gun() -> Gun:
	return null

func set_team(team : TeamStats):
	team_stats = team
	
func set_stats(stats : BoatStats):
	boat_stats = stats
