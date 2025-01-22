extends AirState

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

@export
var distance_warn_component : DistanceWarnComponent

func enter() -> void:
	var enemy : Node = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	set_guns_enemy(enemy)
	pass
	
func exit() -> void:
	set_guns_enemy(null)
	pass

func process_physics(delta: float) -> void:
	# Verifica prioridades
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, "AirDeath")
		return
	
	if distance_warn_component.enemy_hitbox.size() > 1 || distance_warn_component.is_too_low:
		Transitioned.emit(self, "manuver")
		return
	
	var target : Node2D = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	if not target:
		Transitioned.emit(self, "airmove")
		return
	
	# Pega o alvo mais próximo
	if target:
		# Calcula direção para o alvo
		var to_target : Vector2 = target.get_center_pos() - parent.global_position
		var target_angle : float = to_target.angle()
		var current_angle : float = parent.rotation
		
		# Rotaciona em direção ao alvo
		parent.angular_velocity = get_rotation_direction(current_angle, target_angle) * 2.0
		
		# Se estiver apontando aproximadamente para o alvo, atira
		if abs(angle_difference(current_angle, target_angle)) < 0.1:  # ~5.7 graus
			#parent.fire_gun()
			pass
			
	if (on_radar_enemy != target):
		set_guns_enemy(target)
	
	for gun in parent.get_guns():
		gun.shoot_gun(Vector2(parent.team_stats.direction, 0))
		gun.projectile_rotation_spawn = parent.rotation
	# Mantém movimento constante
	var direction : Vector2 = Vector2(cos(parent.rotation), sin(parent.rotation))
	parent.linear_velocity = direction * parent.entity_stats.speed
