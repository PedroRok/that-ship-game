class_name BulletTorpedo
extends Bullet

const WATER_Y : float = 366.0
const MIN_DEPTH_Y : float = 367.0
const MAX_DEPTH_Y : float = 480.0
const SURFACE_AUDIO_DEPTH : float = 8.0

var dir_x : float = 1.0

const TURN_RATE : float = 0.07
const BUBBLE_EVERY : int = 4
const BUBBLE_REACH : float = 3.0
const HIT_SPLASH_RADIUS : float = 18.0
const HIT_SPLASH_GRAINS : int = 150
const HIT_BUBBLES : int = 40

var heading : float = 0.0

var _tracked : bool = false
var _ticks : int = 0

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
	_trail_particles()
	if (bullet_stats.killTime <= 0):
		queue_free()
	bullet_stats.killTime -= 1

func _trail_particles() -> void:
	if (global_position.y < WATER_Y):
		return
	_ticks += 1
	GrainParticles.torpedo_wake(get_parent(), global_position, Vector2.from_angle(heading))
	if (_ticks % BUBBLE_EVERY == 0):
		GrainParticles.bubbles(get_parent(), global_position, BUBBLE_REACH, 1)

func _impact_particles(underwater : bool) -> void:
	if (!underwater):
		GrainParticles.splash(get_parent(), global_position, HIT_SPLASH_RADIUS, HIT_SPLASH_GRAINS)
	GrainParticles.bubbles(get_parent(), global_position, HIT_SPLASH_RADIUS, HIT_BUBBLES)
