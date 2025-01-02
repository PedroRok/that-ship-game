class_name Ship
extends RigidBody2D

@export
var team_stats : TeamStats

@export
var boat_stats : BoatStats

@export
var guns: Array[Gun] 
	

func get_guns() -> Array[Gun]:
	return guns

func add_new_gun(new_gun : Gun):
	if (guns.size() >= boat_stats.gun_slots.size()):
		push_error("Trying to add new weapong when is already full")
		return
	add_child(new_gun)
	var gun_slot = boat_stats.gun_slots[guns.size()] as GunSlot
	new_gun.position = gun_slot.position
	
	if team_stats.direction < 0:
		new_gun.position.x = -gun_slot.position.x 
		new_gun.rotate(PI);
		
	new_gun.team = team_stats.team_id
	guns.append(new_gun)
