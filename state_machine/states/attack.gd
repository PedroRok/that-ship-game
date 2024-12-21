extends State

@export
var move_state: State

func enter() -> void:
	prints("attacking", parent.team)
	pass

func process_input(event: InputEvent) -> State:
	return null

func process_physics(delta: float) -> State:
	super(delta)
	if (!component_machine.get_radar().check_radar(parent.team, get_movement_dir())):
		return move_state
	
	return null
