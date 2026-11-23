class_name BulletTorpedo
extends Bullet

const WATER_Y : float = 366.0
const MIN_DEPTH_Y : float = 367.0
const MAX_DEPTH_Y : float = 480.0

var dir_x : float = 1.0

func set_direction(new_direction : Vector2) -> void:
	dir_x = 1.0 if new_direction.x >= 0.0 else -1.0
	direction = Vector2(dir_x * bullet_stats.speed, 0.0)
	rotation = direction.angle()

func _physics_process(_delta : float) -> void:
	var speed : float = bullet_stats.speed
	var wanted_y : float = clampf(global_position.y, MIN_DEPTH_Y, MAX_DEPTH_Y)
	if (is_instance_valid(target) and target.has_method("get_center_pos")):
		wanted_y = clampf(target.get_center_pos().y, MIN_DEPTH_Y, MAX_DEPTH_Y)
	var vy : float = clampf((wanted_y - global_position.y) * 0.1, -1.0, 1.0)
	if (global_position.y < WATER_Y + 1.0):
		vy = maxf(vy, 1.6)
	direction = Vector2(dir_x * speed, vy)
	global_position += direction
	rotation = direction.angle() if dir_x > 0.0 else direction.angle()
	if (bullet_stats.killTime <= 0):
		queue_free()
	bullet_stats.killTime -= 1
