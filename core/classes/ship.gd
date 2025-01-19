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

signal ship_destroy(pos : Vector2, ship_stats : BoatStats, team_stats : TeamStats)

func get_guns() -> Array[Gun]:
	return guns
	
var occupied_slots : Array[int]

func add_new_gun(new_gun : Gun) -> void:
	if (guns.size() >= boat_stats.gun_slots.size()):
		push_error("Trying to add new weapong when is already full")
		return

	var selected_gun_slot : GunSlot = null
	for gun_slot_index in range(boat_stats.gun_slots.size()):
		var gun_slot : GunSlot = boat_stats.gun_slots[gun_slot_index]
		if (gun_slot.allowed_types.has(new_gun.gun_type) and !occupied_slots.has(gun_slot_index)):
			print("appended" + str(gun_slot_index))
			print(gun_slot.position)
			selected_gun_slot = gun_slot
			occupied_slots.append(gun_slot_index)
			break
		
	if (selected_gun_slot == null):
		push_error("Trying to add new weapong when is already full and dont have slots to add")
		return
		
	new_gun.connect("fired_bullet", Callable(self, "handle_bullet_fired"))
	new_gun._set_show_base_texture(selected_gun_slot.with_base)
	add_child(new_gun)
	new_gun.position = selected_gun_slot.position
	
	if team_stats.direction < 0:
		new_gun.position.x = -selected_gun_slot.position.x 
		new_gun.flip()
	new_gun.current_time_to_shoot = guns.size() * 5
	guns.append(new_gun)

func get_center_pos() -> Vector2:
	return global_position + boat_stats.center

func handle_bullet_fired(bullet : Bullet, direction : Vector2, position : Vector2, rotation : float) -> void:
	bullet.team = team_stats.team_id
	bullet_fired.emit(bullet, direction, position, rotation)
	pass
