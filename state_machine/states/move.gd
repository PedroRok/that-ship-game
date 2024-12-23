extends State

func enter() -> void:
	component_machine.get_movable().direction = parent.direction
	pass
	
func process_input(event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	super(delta)
	
	if (component_machine.get_health().actual_health <= 0):
		Transitioned.emit(self, "death")
		return
	
	var target_velocity_x = get_movement_dir() * move_speed
	parent.linear_velocity.x = lerp(parent.linear_velocity.x, target_velocity_x, deceleration * delta)
	if (component_machine.get_radar().check_radar(parent.team, get_movement_dir())):
		Transitioned.emit(self, "attack")
		return
