class_name ComponentMachine
extends Node

@onready
var radar_component : Radar = $Radar
@onready
var movable_component : Movable = $Movable
@onready
var health_component : Health = $Health

func get_movable() -> Movable:
	return movable_component
	
func get_radar() -> Radar:
	return radar_component
	
func get_health() -> Health:
	return health_component
