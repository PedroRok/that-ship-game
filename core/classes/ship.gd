@tool
class_name Ship
extends RigidBody2D

@export
var team_stats : TeamStats

@export
var boat_stats : BoatStats

@export
var guns: Array[Gun]

signal bullet_fired(bullet : Bullet, direction : Vector2, position : Vector2, rotation : float)

func get_guns() -> Array[Gun]:
	return guns

func add_new_gun(new_gun : Gun) -> void:
	if (guns.size() >= boat_stats.gun_slots.size()):
		push_error("Trying to add new weapong when is already full")
		return
		
	new_gun.connect("fired_bullet", Callable(self, "handle_bullet_fired"))
	
	add_child(new_gun)
	var gun_slot : GunSlot = boat_stats.gun_slots[guns.size()]
	new_gun.position = gun_slot.position
	
	if team_stats.direction < 0:
		new_gun.position.x = -gun_slot.position.x 
		new_gun.rotate(PI);
	new_gun.current_time_to_shoot = guns.size() * 5
	guns.append(new_gun)

func get_center_pos() -> Vector2:
	return global_position + boat_stats.center

func handle_bullet_fired(bullet : Bullet, direction : Vector2, position : Vector2, rotation : float) -> void:
	bullet.team = team_stats.team_id
	bullet_fired.emit(bullet, direction, position, rotation)
	pass
