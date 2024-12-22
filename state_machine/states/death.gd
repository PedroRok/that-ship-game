extends State

func enter() -> void:
	parent.collision_layer = 2
	#parent.gravity_scale = parent.gravity_scale *4
	pass
	
func process_input(event: InputEvent) -> State:
	return null

func process_physics(delta: float) -> State:
	#super(delta)
	parent.rotation = lerp(parent.rotation, parent.rotation * 1.3, deceleration * delta)
	
	#prints(parent.gravity_scale)
	return null
