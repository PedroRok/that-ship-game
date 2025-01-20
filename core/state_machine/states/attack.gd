extends State

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

var on_radar_enemy : Node2D

func enter() -> void:
	var enemy : Node = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	set_guns_enemy(enemy)
	pass
	
func exit() -> void:
	set_guns_enemy(null)
	pass

func set_guns_enemy(enemy : Node2D) -> void:
	on_radar_enemy = enemy
	for gun in parent.get_guns():
		gun.enemy = enemy
	
func process_input(_event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	super(delta)
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, 'death')
		return
		
	# Enemy verification
	var enemy_in_radar : Node2D = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	if (!enemy_in_radar):
		Transitioned.emit(self, 'move')
		return
	
	if (on_radar_enemy != enemy_in_radar):
		set_guns_enemy(enemy_in_radar)
	
	for gun in parent.get_guns():
		gun.shoot_gun(Vector2(parent.team_stats.direction, 0))
	
	return
