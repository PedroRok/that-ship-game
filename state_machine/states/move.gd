extends State

@export
var attack_state: State
@export
var death_state: State

func enter() -> void:
	component_machine.get_movable().direction = parent.direction
	pass
	
func process_input(event: InputEvent) -> State:
	return null

func process_physics(delta: float) -> State:
	super(delta)
	
	if (component_machine.get_health().actual_health <= 0):
		return death_state
	
	var target_velocity_x = get_movement_dir() * move_speed
	parent.linear_velocity.x = lerp(parent.linear_velocity.x, target_velocity_x, deceleration * delta)
	if (component_machine.get_radar().check_radar(parent.team, get_movement_dir())):
		return attack_state
		
	return null
