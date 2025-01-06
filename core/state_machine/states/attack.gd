extends State

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

func enter() -> void:
	var enemy : Node = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	for gun in parent.get_guns():
		gun.enemy = enemy
	pass
	
func exit() -> void:
	for gun in parent.get_guns():
		gun.enemy = null
	pass
	
func process_input(_event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	super(delta)
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, 'death')
		return
	
	if (!radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)):
		Transitioned.emit(self, 'move')
		return
	
	for gun in parent.get_guns():
		gun.shoot_gun(Vector2(parent.team_stats.direction, 0))
	
	return
