class_name RotaryGun
extends Gun

@export
var barrel_texture : Sprite2D
@export
var barrel_frames : Array[Texture2D]
@export
var barrel_offsets : Array[float] = [0.0]
@export
var max_elevation : float = 1.3
@export
var spread : float = 0.05

var fixed_angle : bool = false
var _frame : int = 0

func _facing() -> float:
	var entity : Entity = get_parent() as Entity
	return entity.facing() if entity else 1.0

func _aim_vector() -> Vector2:
	return enemy.get_center_pos() - end_barrel.global_position

func can_aim() -> bool:
	var aim : Vector2 = _aim_vector()
	if (aim.x * _facing() < -6.0):
		return false
	return absf(atan2(aim.y, maxf(absf(aim.x), 0.001))) <= max_elevation

func shoot_gun(_direction : Vector2) -> void:
	if (disabled or !enemy or !end_barrel or !can_target(enemy)):
		return
	if (target_distance(enemy) > effective_range() or !can_aim()):
		return
	if (current_time_to_shoot > 0):
		current_time_to_shoot -= 1
		return
	current_time_to_shoot = time_to_shoot
	var base_angle : float = _aim_vector().angle()
	var perpendicular : Vector2 = Vector2.from_angle(base_angle + PI * 0.5)
	for offset : float in barrel_offsets:
		var angle : float = base_angle + randf_range(-spread, spread)
		var bullet_instance : Bullet = _make_bullet()
		fired_bullet.emit(bullet_instance, end_barrel.global_position + perpendicular * offset, Vector2.from_angle(angle), angle)
	play_effects()
	if (barrel_texture and !barrel_frames.is_empty()):
		_frame = (_frame + 1) % barrel_frames.size()
		barrel_texture.texture = barrel_frames[_frame]
