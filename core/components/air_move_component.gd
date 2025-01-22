extends AirState

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

@export
var distance_warn_component : DistanceWarnComponent

func enter() -> void:
	parent.team_stats.direction = parent.team_stats.direction
	pass

func process_physics(delta: float) -> void:
	super(delta)
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, "AirDeath")
		return
		
	if distance_warn_component.enemy_hitbox.size() > 1 || distance_warn_component.is_too_low:
		Transitioned.emit(self, "manuver")
		
	if radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction):
		Transitioned.emit(self, "AirAttack")
		return
		
	var target_angle : float = -0.1
	var current_angle : float = fmod(parent.rotation + PI, PI * 2) - PI  # Normaliza entre -PI e PI
	
	# Aplica rotação para manter horizontal
	var angle_diff : float = angle_difference(current_angle, target_angle)
	if abs(angle_diff) > 0.01:  # Pequena margem de erro
		parent.angular_velocity = sign(angle_diff) * 3
	else:
		parent.angular_velocity = 0
	
	# Mantém movimento constante
	var direction : Vector2 = Vector2(cos(parent.rotation), sin(parent.rotation))
	parent.linear_velocity = direction * parent.entity_stats.speed
