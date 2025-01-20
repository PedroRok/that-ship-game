class_name Base
extends Node2D

@export
var team_stats : TeamStats

@onready
var base_center : Node2D = $BaseCenter

@onready
var art : Node2D

@export
var health_component : BaseHealthComponent

@export
var ship_constructor : ShipConstructor

var enabled : bool = true

signal death_event(team_stats : TeamStats)

signal spawn_ship_event(spawn_pos : Vector2, boat_stats : BoatStats, team_stats : TeamStats)

func _ready() -> void:
	health_component.death_event.connect(Callable(self, "_death_event"))
	if (ship_constructor):
		ship_constructor.ship_build_finish.connect(Callable(self, "_ship_build_finish"))

func get_center_pos() -> Vector2:
	return base_center.global_position

func _death_event() -> void:
	death_event.emit(team_stats)
	
func start_build_ship(ship : BoatStats) -> bool:
	print("start build")
	if (ship_constructor.is_building()): return false
	ship_constructor.build_ship(ship)
	return true

func _ship_build_finish(ship : BoatStats) -> void:
	spawn_ship_event.emit(ship_constructor.global_position, ship, team_stats)
	
func get_spawn_point() -> Vector2:
	return ship_constructor.global_position
	
	
	
