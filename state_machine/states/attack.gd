extends State

@export
var time_to_shot: int = 100

func enter() -> void:
	prints("attacking", parent.team)
	pass

func process_input(event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	super(delta)
	
	if (component_machine.get_health().actual_health <= 0):
		Transitioned.emit(self, 'death')
		return
	
	if (!component_machine.get_radar().check_radar(parent.team, get_movement_dir())):
		Transitioned.emit(self, 'move')
		return
	
	if (time_to_shot > 0):
		time_to_shot -= 1
	
	if (time_to_shot == 0):
		time_to_shot = 100
		parent.get_gun().shoot_gun(Vector2(get_movement_dir(), 0))
	
	return
