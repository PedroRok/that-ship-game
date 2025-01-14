class_name PlayerStats
extends Resource

@export
var start_screw : int = 10
@export
var gear : int = 10
@export
var owned_ships : Array[BoatStats]

var round : int = 0

func has_boat(boat_name : String) -> bool:
	for stats : BoatStats in owned_ships:
		if (boat_name == stats.name):
			return true
	return false
	
func can_buy(gears_needed : int) -> bool:
	if (gear >= gears_needed):
		return true
	return false

func add_boat(boat : BoatStats) -> void:
	owned_ships.append(boat)

func buy(gear_needed : int, boat : BoatStats) -> bool:
	if (has_boat(boat.name)):
		return false
	if (!can_buy(gear_needed)):
		return false
	add_boat(boat)
	gear -= gear_needed
	return true
