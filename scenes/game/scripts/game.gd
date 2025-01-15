class_name GameRound
extends Node2D

var player_stats : PlayerStats

@export
var camera : GameCam
	
@export
var ally_base : Base

@export
var enemy_base : Base

func _ready() -> void:
	ally_base.death_event.connect(Callable(self, "base_death_event"))


func base_death_event(team_stats: TeamStats):
	if (team_stats.team_id == 1):
		
