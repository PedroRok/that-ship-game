class_name Base
extends Node

@export
var team_stats : TeamStats

@onready
var base_center : Node2D = $BaseCenter

@onready
var art : Node2D

@export
var health_component : BaseHealthComponent

signal death_event(team_stats : TeamStats)

func _ready() -> void:
	health_component.death_event.connect(Callable(self, "_death_event"))

func get_center_pos() -> Vector2:
	return base_center.global_position

func _death_event() -> void:
	death_event.emit(team_stats)
