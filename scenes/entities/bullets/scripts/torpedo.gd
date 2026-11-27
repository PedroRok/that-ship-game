class_name BulletTorpedo
extends Bullet

const WATER_Y : float = 366.0
const MIN_DEPTH_Y : float = 367.0
const MAX_DEPTH_Y : float = 480.0

var dir_x : float = 1.0

const TURN_RATE : float = 0.07

var heading : float = 0.0

var _tracked : bool = false

func set_direction(new_direction : Vector2) -> void:
	dir_x = 1.0 if new_direction.x >= 0.0 else -1.0
	heading = 0.0 if dir_x > 0.0 else PI
	direction = Vector2.from_angle(heading) * bullet_stats.speed
	rotation = heading

func _target_alive() -> bool:
	if (!is_instance_valid(target) or !target.has_method("get_center_pos")):
		return false
	var entity : Entity = target as Entity
	return !entity or (entity.enabled and !entity.destroyed)

func _physics_process(_delta : float) -> void:
	var speed : float = bullet_stats.speed
	var wanted : Vector2 = Vector2.from_angle(heading)
	if (_target_alive()):
		_tracked = true
		var goal : Vector2 = target.get_center_pos()
		goal.y = clampf(goal.y, MIN_DEPTH_Y, MAX_DEPTH_Y)
		wanted = goal - global_position
	elif (!_tracked):
		wanted = Vector2(dir_x, 0.0)
	elif (global_position.y <= MIN_DEPTH_Y + 2.0 and sin(heading) < 0.0):
		wanted = Vector2(cos(heading), 0.0)
	var wanted_angle : float = wanted.angle()
	if (global_position.y < WATER_Y + 1.0):
		wanted_angle = Vector2(cos(heading), 1.6).angle()
	elif (global_position.y > MAX_DEPTH_Y and sin(heading) > 0.0):
		wanted_angle = Vector2(cos(heading), 0.0).angle()
	heading += clampf(angle_difference(heading, wanted_angle), -TURN_RATE, TURN_RATE)
	direction = Vector2.from_angle(heading) * speed
	global_position += direction
	rotation = heading
	if (bullet_stats.killTime <= 0):
		queue_free()
	bullet_stats.killTime -= 1
