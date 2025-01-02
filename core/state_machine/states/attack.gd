extends State

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

@export
var time_to_shot: int = 100

var actual_time_to_shoot: int = 0

func enter() -> void:
	var enemy = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	for gun in parent.get_guns():
		gun.enemy = enemy
	pass
	
func exit() -> void:
	for gun in parent.get_guns():
		gun.enemy = null
	pass
	
func process_input(event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	super(delta)
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, 'death')
		return
	
	if (!radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)):
		Transitioned.emit(self, 'move')
		return
	
	if (actual_time_to_shoot > 0):
		actual_time_to_shoot -= 1
	
	if (actual_time_to_shoot == 0):
		actual_time_to_shoot = time_to_shot
		for gun in parent.get_guns():
			gun.shoot_gun(Vector2(parent.team_stats.direction, 0))
	
	return
