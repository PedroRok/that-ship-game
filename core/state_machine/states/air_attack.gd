extends AirState

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

@export
var distance_warn_component : DistanceWarnComponent

var pass_until : float = 0.0
var _clock : float = 0.0

func enter() -> void:
	var enemy : Node = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	set_guns_enemy(enemy)
	pass
	
func exit() -> void:
	set_guns_enemy(null)
	pass

func process_physics(delta: float) -> void:
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, "AirDeath")
		return
	
	if distance_warn_component.enemy_hitbox.size() > 1 || distance_warn_component.is_too_low:
		Transitioned.emit(self, "manuver")
		return
	
	var target : Node2D = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	if not target or !(parent as AirEntity).can_engage():
		Transitioned.emit(self, "airmove")
		return
	
	if (avoid_base_climb()):
		for gun in parent.get_guns():
			gun.shoot_gun(Vector2(1, 0))
			gun.projectile_rotation_spawn = parent.rotation
		return
	_clock += delta
	var now : float = _clock
	if (now < pass_until):
		var climb_angle : float = to_heading(parent.rotation)
		parent.angular_velocity = get_rotation_direction(climb_angle, -0.5) * 2.0 * mirror_sign()
		for gun in parent.get_guns():
			gun.shoot_gun(Vector2(1, 0))
			gun.projectile_rotation_spawn = parent.rotation
		parent.linear_velocity = Vector2(cos(parent.rotation), sin(parent.rotation)) * parent.entity_stats.speed
		return
	var trigger : float = 34.0 if target is Entity else 95.0
	if (target.get_center_pos().distance_to(parent.global_position) < trigger):
		pass_until = now + 1.5

	if target:
		var to_target : Vector2 = target.get_center_pos() - parent.global_position
		var target_angle : float = to_heading(to_target.angle())
		var current_angle : float = to_heading(parent.rotation)
		
		parent.angular_velocity = get_rotation_direction(current_angle, target_angle) * 2.0 * mirror_sign()
		
		if abs(angle_difference(current_angle, target_angle)) < 0.1:
			pass
			
	if (on_radar_enemy != target):
		set_guns_enemy(target)
	
	for gun in parent.get_guns():
		gun.shoot_gun(Vector2(1, 0))
		gun.projectile_rotation_spawn = parent.rotation
	var direction : Vector2 = Vector2(cos(parent.rotation), sin(parent.rotation))
	parent.linear_velocity = direction * parent.entity_stats.speed
