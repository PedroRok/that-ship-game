class_name ComponentMachine
extends Node

@onready
var radar_component : Radar = $Radar
@onready
var movable_component : Movable = $Movable


func get_movable() -> Movable:
	return movable_component
	
func get_radar() -> Radar:
	return radar_component
