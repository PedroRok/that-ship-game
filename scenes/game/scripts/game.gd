class_name GameRound
extends Node2D

var player_stats : PlayerStats

var gears_collected_in_round : int = 0

@export
var camera : GameCam
	
@export
var ally_base : Base

@export
var enemy_base : Base

const WIN_SCREEN = preload("res://scenes/ui/game/win_screen/win_screen.tscn")

@onready
var canvas_layer : CanvasLayer = $CanvasLayer

func _ready() -> void:
	ally_base.death_event.connect(Callable(self, "base_death_event"))
	enemy_base.death_event.connect(Callable(self, "base_death_event"))


func base_death_event(team_stats: TeamStats) -> void:
	if (team_stats.team_id != 1):
		var win_screen : Node = WIN_SCREEN.instantiate()
		win_screen.gears_fixed_gived = 10
		win_screen.gears_winned_in_round = gears_collected_in_round
		Global.player_stats.gear += 10
		canvas_layer.call_deferred("add_child", win_screen) 
