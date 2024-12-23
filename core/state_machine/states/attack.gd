extends State

@export
var movable_component : MovableComponent

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

@export
var time_to_shot: int = 100

var actual_time_to_shoot: int

func enter() -> void:
	actual_time_to_shoot = time_to_shot
	pass

func process_input(event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	super(delta)
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, 'death')
		return
	
	if (!radar_component.check_radar(parent.team, movable_component.get_movement_direction())):
		Transitioned.emit(self, 'move')
		return
	
	if (actual_time_to_shoot > 0):
		actual_time_to_shoot -= 1
	
	if (actual_time_to_shoot == 0):
		actual_time_to_shoot = time_to_shot
		parent.get_gun().shoot_gun(Vector2(movable_component.get_movement_direction(), 0))
	
	return
