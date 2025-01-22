@tool
class_name Entity
extends RigidBody2D

@export
var team_stats : TeamStats

@export
var entity_stats : EntityStats

@export
var guns: Array[Gun]

@onready
var state_machine : StateMachine = $StateMachine

var enabled : bool = true

signal bullet_fired(bullet : Bullet, direction : Vector2, position : Vector2, rotation : float)

signal entity_destroy(pos : Vector2, ship_stats : EntityStats, team_stats : TeamStats)

func get_guns() -> Array[Gun]:
	return guns
	
var occupied_slots : Array[int]

func _ready() -> void:
	if state_machine:
		state_machine.init(self)
	for gun_slot_index in range(entity_stats.gun_slots.size()):
		var gun_slot : GunSlot = entity_stats.gun_slots[gun_slot_index]
		# TEMPORARY
		var gun_type : Enums.Guns = gun_slot.allowed_types[0]
		var gun_scene : PackedScene = Enums.guns.get(gun_type)
		add_gun(gun_scene.instantiate(), gun_slot)
		

func add_new_gun(new_gun : Gun) -> void:
	if (guns.size() >= entity_stats.gun_slots.size()):
		push_error("Trying to add new weapong when is already full")
		return

	var selected_gun_slot : GunSlot = null
	for gun_slot_index in range(entity_stats.gun_slots.size()):
		var gun_slot : GunSlot = entity_stats.gun_slots[gun_slot_index]
		if (gun_slot.allowed_types.has(new_gun.gun_type) and !occupied_slots.has(gun_slot_index)):
			selected_gun_slot = gun_slot
			occupied_slots.append(gun_slot_index)
			break
		
	if (selected_gun_slot == null):
		push_error("Trying to add new weapong when is already full and dont have slots to add")
		return
		
	add_gun(new_gun, selected_gun_slot)
		
		
func add_gun(gun : Gun, gun_slot : GunSlot) -> void:
	gun.connect("fired_bullet", Callable(self, "handle_bullet_fired"))
	gun._set_show_base_texture(gun_slot.with_base)
	add_child(gun)
	gun.position = gun_slot.position
	
	if team_stats.direction < 0:
		gun.position.x = -gun_slot.position.x 
		gun.flip()
	gun.current_time_to_shoot = guns.size() * 5
	guns.append(gun)

func get_center_pos() -> Vector2:
	return global_position + entity_stats.center

func handle_bullet_fired(bullet : Bullet, direction : Vector2, position : Vector2, rotation : float) -> void:
	bullet.team = team_stats.team_id
	bullet_fired.emit(bullet, direction, position, rotation)
	pass

func _unhandled_input(event: InputEvent) -> void:
	if state_machine:
		state_machine.process_input(event)

func _physics_process(delta: float) -> void:
	if state_machine && !Engine.is_editor_hint():
		state_machine.process_physics(delta)

func _process(delta: float) -> void:
	if state_machine && !Engine.is_editor_hint():
		state_machine.process_frame(delta)
