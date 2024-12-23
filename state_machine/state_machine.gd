extends Node

@export
var starting_state: State

var current_state: State

var states : Dictionary = {}

func init(parent: Ship, component_machine : ComponentMachine) -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.parent = parent
			child.component_machine = component_machine
			child.Transitioned.connect(change_state)
	
	if starting_state:
		starting_state.enter()
		current_state = starting_state
	

func change_state(state : State, new_state_name : String) -> void:
	if state != current_state:
		return

	var new_state = states.get(new_state_name.to_lower())
	if !new_state:
		push_warning('"' +state.name + '" is Trying to go to a unknow state')
		return
	if current_state:
		current_state.exit()
		
	new_state.enter()
	current_state = new_state
	

func process_physics(delta: float) -> void:
	if current_state:
		current_state.process_physics(delta)

func process_input(event: InputEvent) -> void:
	if current_state:
		current_state.process_input(event)

func process_frame(delta: float) -> void:
	if current_state:
		current_state.process_frame(delta)
