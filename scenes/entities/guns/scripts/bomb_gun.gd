class_name BombGun
extends Gun

var fixed_angle : bool = true

func _init() -> void:
	hits_air = false
	hits_surface = true
	hits_submerged = false

func can_target(target : Node2D) -> bool:
	var entity : Entity = target as Entity
	if (!entity):
		return true
	return !entity.is_submerged() and !(entity.entity_stats is AirPlaneState)

func shoot_gun(_direction : Vector2) -> void:
	if (current_time_to_shoot > 0):
		current_time_to_shoot -= 1
		return
	if (!enemy or !can_target(enemy)):
		return
	var plane : Entity = get_parent() as Entity
	var vx : float = plane.linear_velocity.x if plane else 0.0
	var target_x : float = enemy.get_center_pos().x if enemy.has_method("get_center_pos") else enemy.global_position.x
	var ahead : float = (target_x - global_position.x) * signf(vx if vx != 0.0 else 1.0)
	if (ahead < -8.0 or ahead > 48.0):
		return
	current_time_to_shoot = time_to_shoot
	var bomb : Bullet = bullet.instantiate()
	bomb.target = enemy
	bomb.damage = bomb.damage.duplicate()
	bomb.damage.damage *= damage_scale
	fired_bullet.emit(bomb, end_barrel.global_position, Vector2(vx * 0.8, 30.0), 0.0)
	play_effects()
