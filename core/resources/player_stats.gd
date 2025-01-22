class_name PlayerStats
extends Resource

@export
var start_screw : int = 10
@export
var gear : int = 10

var round_num : int = 0

var round_group_num : int = 0

@export
var unlocked_entities : Array[EntityStats]

@export
var gun_upgrades: Array[GunStats]

func has_boat(boat_name : String) -> bool:
	for stats : EntityStats in unlocked_entities:
		if (boat_name == stats.name):
			return true
	return false
	
func can_buy(gears_needed : int) -> bool:
	if (gear >= gears_needed):
		return true
	return false

func add_entity(entity : EntityStats) -> void:
	unlocked_entities.append(entity)

func buy(gear_needed : int, boat : BoatStats) -> bool:
	if (has_boat(boat.name)):
		return false
	if (!can_buy(gear_needed)):
		return false
	add_entity(boat)
	gear -= gear_needed
	return true
