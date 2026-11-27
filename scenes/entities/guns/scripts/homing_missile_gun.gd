class_name HomingMissileGun
extends Gun

@export
var plane_heading : bool = false
@export
var cone : float = 0.55
@export
var burst_count : int = 1
@export
var burst_gap : int = 10

var _burst_left : int = 0

func _heading() -> Vector2:
	if (plane_heading):
		return Vector2.from_angle(projectile_rotation_spawn)
	var entity : Entity = get_parent() as Entity
	var facing : float = entity.facing() if entity else 1.0
	return Vector2(facing, 0.4).normalized()

func shoot_gun(_direction : Vector2) -> void:
	if (disabled or !enemy or !end_barrel or !can_target(enemy)):
		return
	if (target_distance(enemy) > effective_range()):
		return
	var aim : Vector2 = enemy.get_center_pos() - end_barrel.global_position
	if (aim.length() < 4.0 or _heading().dot(aim.normalized()) < cone):
		return
	if (current_time_to_shoot > 0):
		return
	if (_burst_left <= 0):
		_burst_left = burst_count
	_burst_left -= 1
	current_time_to_shoot = burst_gap if _burst_left > 0 else time_to_shoot
	var missile : Bullet = _make_bullet()
	if (missile is BulletMissile):
		(missile as BulletMissile).launch_forward = true
	var dir : Vector2 = (_heading() + aim.normalized()).normalized()
	fired_bullet.emit(missile, end_barrel.global_position, dir, dir.angle())
	play_effects()
	_stagger_twins()

func _stagger_twins() -> void:
	var carrier : Entity = get_parent() as Entity
	if (!carrier):
		return
	for gun : Gun in carrier.get_guns():
		if (gun != self and gun.gun_type == gun_type):
			gun.current_time_to_shoot = maxi(gun.current_time_to_shoot, time_to_shoot >> 1)

func _physics_process(_delta : float) -> void:
	if (current_time_to_shoot > 0):
		current_time_to_shoot -= 1

func is_ready() -> bool:
	return _burst_left > 0 or current_time_to_shoot <= 0
