extends State

@export
var move_state: State
@export
var death_state: State

var time_to_shot: int = 100

func enter() -> void:
	prints("attacking", parent.team)
	pass

func process_input(event: InputEvent) -> State:
	return null

func process_physics(delta: float) -> State:
	super(delta)
	
	if (component_machine.get_health().actual_health <= 0):
		return death_state
	
	if (!component_machine.get_radar().check_radar(parent.team, get_movement_dir())):
		return move_state
	
	if (time_to_shot > 0):
		time_to_shot -= 1
	
	if (time_to_shot == 0):
		time_to_shot = 100
		parent.get_gun().shoot_gun(Vector2(get_movement_dir(), 0))
	
	return null
