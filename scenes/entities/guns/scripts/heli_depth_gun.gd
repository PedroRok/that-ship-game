class_name HeliDepthGun
extends DepthBombGun

const DROP_WINDOW : float = 14.0

func shoot_gun(_direction : Vector2) -> void:
	if (disabled):
		return
	if (current_time_to_shoot > 0):
		current_time_to_shoot -= 1
		return
	if (!enemy or !can_target(enemy)):
		return
	var target_pos : Vector2 = enemy.get_center_pos() if enemy.has_method("get_center_pos") else enemy.global_position
	if (absf(target_pos.x - global_position.x) > DROP_WINDOW or target_pos.y < global_position.y):
		return
	current_time_to_shoot = time_to_shoot
	var carrier : Entity = get_parent() as Entity
	var vx : float = carrier.linear_velocity.x if carrier else 0.0
	var bomb : Bullet = bullet.instantiate()
	bomb.target = enemy
	bomb.damage = bomb.damage.duplicate()
	bomb.damage.damage *= damage_scale
	fired_bullet.emit(bomb, end_barrel.global_position, Vector2(vx * 0.5, 12.0), 0.0)
	play_effects()
