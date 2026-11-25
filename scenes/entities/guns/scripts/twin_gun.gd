class_name TwinGun
extends SimpleGun

@export
var barrel_spacing : float = 1.6

func _fire(direction : Vector2) -> void:
	var heading : float = projectile_rotation_spawn
	var perpendicular : Vector2 = Vector2.from_angle(heading + PI * 0.5)
	for side : float in [-0.5, 0.5]:
		var bullet_instance : Bullet = _make_bullet()
		var dir : Vector2 = direction.rotated(heading) if direction.x > 0 else direction.rotated(-heading)
		fired_bullet.emit(bullet_instance, end_barrel.global_position + perpendicular * side * barrel_spacing, dir, heading)
	play_effects()
