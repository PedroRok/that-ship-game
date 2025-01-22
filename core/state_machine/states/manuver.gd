extends AirState

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

@export
var distance_warn_component : DistanceWarnComponent

var can_change : bool = false

func enter() -> void:
	parent.team_stats.direction = parent.team_stats.direction
	can_change = false
	timer_started = false
	pass
	
func can_change_to() -> void:
	can_change = true

func process_physics(delta: float) -> void:
	super(delta)
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, "AirDeath")
		return
	
	if distance_warn_component.get_overlapping_bodies().size() < 2 && can_change && !distance_warn_component.is_too_low:
		Transitioned.emit(self, "AirMove")
		return
		
		
	var target : Node2D = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	if (on_radar_enemy != target):
		set_guns_enemy(target)
	
	for gun in parent.get_guns():
		gun.shoot_gun(Vector2(parent.team_stats.direction, 0))
		gun.projectile_rotation_spawn = parent.rotation
		
		
	# Lógica de manobra evasiva
	if distance_warn_component.is_too_low:
		var target_angle : float = -PI/4  # 45 graus para cima
		var current_angle : float = parent.rotation
		parent.angular_velocity = get_rotation_direction(current_angle, target_angle) * 3.0
		start_timer(3)
	elif distance_warn_component.get_overlapping_bodies().size() >= 2:
		# Lógica original de manobra para evitar obstáculos
		var obstacle : Node2D = distance_warn_component.get_overlapping_bodies()[1]
		var avoid_direction : Vector2 = (parent.global_position - obstacle.global_position).normalized()
		var target_angle : float = avoid_direction.angle()
		var current_angle : float = parent.rotation
		parent.angular_velocity = get_rotation_direction(current_angle, target_angle) * 3.0
		start_timer(2)
	else:
		start_timer(1)
	
	# Mantém movimento constante
	var direction : Vector2 = Vector2(cos(parent.rotation), sin(parent.rotation))
	parent.linear_velocity = direction * parent.entity_stats.speed
	

var timer_started : bool = false

func start_timer(time : int) -> void:
	if (!timer_started):
		get_tree().create_timer(time).timeout.connect(Callable(self, "can_change_to"))
		
		timer_started = true
	
