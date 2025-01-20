extends State

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

@export
var particle_component : ParticlesComponent

func enter() -> void:
	parent.team_stats.direction = parent.team_stats.direction
	particle_component.trail.delta_speed(0, 0)
	pass

func exit() -> void:
	particle_component.trail.delta_speed(0, 0)
	
func process_input(_event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	super(delta)
	particle_component.trail.delta_speed(parent.team_stats.direction, parent.linear_velocity.x)
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, "death")
		return
	
	var target_velocity_x : float = parent.team_stats.direction * parent.entity_stats.speed
	parent.linear_velocity.x = lerp(parent.linear_velocity.x, target_velocity_x, parent.entity_stats.deceleration * delta)
	if (radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)):
		Transitioned.emit(self, "attack")
		return
