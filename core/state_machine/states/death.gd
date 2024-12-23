extends State


var death_rotation_speed : float

func enter() -> void:
	parent.collision_layer = 2
	#parent.gravity_scale = parent.gravity_scale *4
	death_rotation_speed = randf_range(1.25, 1.4)
	death_rotation_speed = -death_rotation_speed
	pass
	
func process_input(event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	#super(delta)
	
	parent.rotation = lerp(parent.rotation, parent.rotation * death_rotation_speed, deceleration * delta)
	#prints(parent.gravity_scale)
	return
