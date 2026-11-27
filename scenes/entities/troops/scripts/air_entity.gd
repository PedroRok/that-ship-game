class_name AirEntity
extends Entity

@export
var animated_sprite : AnimatedSprite2D

@export
var animated_blades : AnimatedSprite2D

var gun : PackedScene = preload("res://scenes/entities/guns/simple_gun.tscn")

var is_dead : bool = false

var flare_cooldown : float = 0.0
var evade_left : float = 0.0
var evade_dir : float = 0.0

var retreat_enabled : bool = false
var retreat_stage : int = 0
var retreating : bool = false

var loiter_min_x : float = NAN
var loiter_max_x : float = NAN

func _update_flares(delta : float) -> void:
	flare_cooldown = maxf(flare_cooldown - delta, 0.0)
	evade_left = maxf(evade_left - delta, 0.0)
	var role : BoatStats = entity_stats as BoatStats
	if (flare_cooldown > 0.0 or !role or role.is_boss or !role.uses_flares):
		return
	var forward : Vector2 = Vector2.from_angle(rotation)
	var chasing : Array[BulletMissile] = []
	var close : bool = false
	for node : Node in get_tree().get_nodes_in_group(BulletMissile.GROUP):
		var missile : BulletMissile = node as BulletMissile
		if (!missile or missile.team == team_stats.team_id or missile.target != self or !missile.hits_air):
			continue
		var offset : Vector2 = missile.global_position - get_center_pos()
		if (offset.length() > RunData.FLARE_REACH):
			continue
		chasing.append(missile)
		if (offset.length() <= RunData.FLARE_TRIGGER_DISTANCE):
			close = true
			evade_dir = -signf(offset.x) if offset.x != 0.0 else -signf(forward.x)
	if (!close):
		return
	flare_cooldown = RunData.FLARE_COOLDOWN
	evade_left = RunData.HELI_EVADE_SECONDS
	AirPuff.flares(self, get_center_pos(), forward)
	for missile : BulletMissile in chasing:
		if (randf() >= RunData.FLARE_HIT_CHANCE):
			missile.decoy(RunData.FLARE_DEFLECTION if randf() < 0.5 else -RunData.FLARE_DEFLECTION)

func loiters() -> bool:
	return !is_nan(loiter_max_x)

func may_attack(target : Node2D) -> bool:
	return !loiters() or (!(target is Base) and target.global_position.x <= loiter_max_x)

func update_retreat() -> bool:
	if (!retreat_enabled or is_dead):
		return false
	var health : HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
	if (health == null or health.actual_health <= 0.0):
		return false
	if (!retreating):
		if (retreat_stage >= RunData.BOMBER_RETREAT_AT.size()
				or health.actual_health > health.default_health * RunData.BOMBER_RETREAT_AT[retreat_stage]):
			return false
		retreating = true
	var dir : float = 1.0 if team_stats.direction > 0 else -1.0
	for node : Node in BattleContext.of(self).bases:
		var base : Base = node as Base
		if (base and base.team_stats.team_id == team_stats.team_id
				and (global_position.x - base.global_position.x) * dir <= RunData.BOMBER_HOME_DISTANCE):
			health.actual_health = minf(health.default_health,
					health.actual_health + health.default_health * RunData.BOMBER_RETREAT_HEAL[retreat_stage])
			retreat_stage += 1
			retreating = false
			break
	return retreating

func rotates_with_body() -> bool:
	return true

var near_blades : AnimatedSprite2D
var far_inner_blades : AnimatedSprite2D
var near_inner_blades : AnimatedSprite2D

func _setup_visuals() -> void:
	var stats : AirPlaneState = entity_stats as AirPlaneState
	if (!stats):
		return
	if (stats.body_frames.size() == 5):
		var body : SpriteFrames = SpriteFrames.new()
		for tex : Texture2D in stats.body_frames:
			body.add_frame(&"default", tex)
		animated_sprite.sprite_frames = body
	if (stats.blade_frames.is_empty() and animated_blades):
		animated_blades.visible = false
	if (stats.blade_frames.size() == 7):
		var blades : SpriteFrames = SpriteFrames.new()
		blades.set_animation_speed(&"default", 20.0)
		for tex : Texture2D in stats.blade_frames:
			blades.add_frame(&"default", tex)
		animated_blades.sprite_frames = blades
	if (stats.prop_far.size() == 5 and stats.prop_near.size() == 5):
		near_blades = animated_blades.duplicate() as AnimatedSprite2D
		add_child(near_blades)
		near_blades.play()

func _update_props() -> void:
	var stats : AirPlaneState = entity_stats as AirPlaneState
	if (!stats or !near_blades or stats.prop_far.size() != 5):
		return
	var frame : int = clampi(animated_sprite.frame, 0, 4)
	var flip : float = -1.0 if animated_sprite.flip_v else 1.0
	animated_blades.position = Vector2(stats.prop_far[frame].x, stats.prop_far[frame].y * flip)
	near_blades.position = Vector2(stats.prop_near[frame].x, stats.prop_near[frame].y * flip)

func _ready() -> void:
	super._ready()
	_setup_visuals()
	apply_team_outline(animated_sprite)
	if (animated_blades and animated_blades.sprite_frames):
		animated_blades.play()
	_prepare_guns()

func is_bomber() -> bool:
	if (!rotates_with_body() or get_guns().is_empty()):
		return false
	for gun : Gun in get_guns():
		if (!(gun is BombGun)):
			return false
	return true

func can_engage() -> bool:
	var guns_list : Array[Gun] = get_guns()
	if (guns_list.is_empty()):
		return true
	for gun : Gun in guns_list:
		if (!(gun is HomingMissileGun) or (gun as HomingMissileGun).is_ready()):
			return true
	return false

func _prepare_guns() -> void:
	for gun : Gun in get_guns():
		gun.set("fixed_angle", true)

const CEILING_Y : float = 62.0
const CEILING_BUFFER : float = 4.0
const TURN_RATE : float = 3.0
const MAX_TURN_RATE : float = 9.0
const LEVEL_RATE : float = 6.0
const FLOOR_CLEARANCE : float = 28.0

var reversal_sign : float = 0.0
var reversal_rate : float = 0.0
var reversal_frame : int = -10

func turn_radius(rate : float = TURN_RATE) -> float:
	return entity_stats.speed / rate

func is_reversing() -> bool:
	return Engine.get_physics_frames() - reversal_frame <= 1

func room_above() -> float:
	return global_position.y - CEILING_Y - CEILING_BUFFER

func room_below(forward_x : float) -> float:
	var floor_y : float = ShipEntity.WATER_LEVEL - FLOOR_CLEARANCE
	for x : float in [global_position.x, global_position.x + forward_x]:
		for base : Base in BattleContext.of(self).bases:
			var dir : float = 1.0 if base.team_stats.direction > 0 else -1.0
			var depth : float = (x - base.global_position.x) * dir
			if (depth > -15.0 and depth < CLIFF_WIDTH + 15.0):
				floor_y = minf(floor_y, _cliff_top(depth) - FLOOR_CLEARANCE)
	return floor_y - global_position.y

func _level_before_ceiling(delta : float) -> void:
	if (is_reversing() or sin(rotation) >= 0.0):
		return
	var allowed : float = acos(clampf(1.0 - maxf(room_above(), 0.0) / turn_radius(), -1.0, 1.0))
	allowed = minf(allowed, PI * 0.5)
	if (asin(clampf(-sin(rotation), 0.0, 1.0)) <= allowed):
		return
	var limit : float = -allowed if cos(rotation) >= 0.0 else PI + allowed
	rotation = rotate_toward(rotation, limit, LEVEL_RATE * delta)
	linear_velocity = Vector2.from_angle(rotation) * linear_velocity.length()

func _hold_below_ceiling() -> void:
	if (global_position.y < CEILING_Y):
		global_position.y = CEILING_Y
		linear_velocity.y = maxf(linear_velocity.y, 0.0)

const CLIFF_WIDTH : float = 140.0

func _cliff_top(depth : float) -> float:
	return 160.0 + clampf(depth, 0.0, CLIFF_WIDTH) / CLIFF_WIDTH * 70.0

func base_danger() -> bool:
	var forward : Vector2 = Vector2(cos(rotation), sin(rotation))
	for node : Node in BattleContext.of(self).bases:
		if (!is_instance_valid(node)):
			continue
		var base : Base = node as Base
		if (!base):
			continue
		var dir : float = 1.0 if base.team_stats.direction > 0 else -1.0
		for look : float in [0.0, 45.0, 90.0]:
			var p : Vector2 = global_position + forward * look
			var depth : float = (p.x - base.global_position.x) * dir
			if (depth > -15.0 and depth < CLIFF_WIDTH + 15.0 and p.y > _cliff_top(depth) - 28.0):
				return true
	return false

func _avoid_bases() -> void:
	for node : Node in BattleContext.of(self).bases:
		if (!is_instance_valid(node)):
			continue
		var base : Base = node as Base
		if (!base):
			continue
		var dir : float = 1.0 if base.team_stats.direction > 0 else -1.0
		var depth : float = (global_position.x - base.global_position.x) * dir
		if (depth < 0.0 or depth > CLIFF_WIDTH):
			continue
		var top_y : float = 160.0 + (depth / CLIFF_WIDTH) * 70.0
		if (global_position.y > top_y - 6.0):
			global_position.y = top_y - 6.0
			if (linear_velocity.y > 0.0):
				linear_velocity.y = 0.0

var turning_back : bool = false

func distance_to_limit() -> float:
	var dir : float = 1.0 if team_stats.direction > 0 else -1.0
	for node : Node in BattleContext.of(self).bases:
		if (!is_instance_valid(node)):
			continue
		var base : Base = node as Base
		if (base and base.team_stats.team_id != team_stats.team_id):
			return (base.base_center.global_position.x - global_position.x) * dir
	return INF

func _hold_inside_limit() -> void:
	var ahead : float = distance_to_limit()
	if (ahead >= 0.0):
		return
	var dir : float = 1.0 if team_stats.direction > 0 else -1.0
	global_position.x += ahead * dir
	if (linear_velocity.x * dir > 0.0):
		linear_velocity.x = 0.0

const TAKEOFF_TIME : float = 0.9
const TAKEOFF_PITCH : float = 0.45

var _on_runway : bool = false
var _takeoff_left : float = 0.0
var _runway_speed : float = 0.0
var _runway_accel : float = 0.0

func is_on_runway() -> bool:
	return _on_runway

func begin_takeoff(clear_x : float) -> void:
	_on_runway = true
	begin_entry(clear_x, true)
	var length : float = maxf(absf(clear_x - global_position.x), 1.0)
	_runway_speed = 0.0
	_runway_accel = entity_stats.speed * entity_stats.speed / (2.0 * length)

func _takeoff_step(delta : float) -> void:
	var dir : float = 1.0 if team_stats.direction > 0 else -1.0
	var heading : float = 0.0 if dir > 0 else PI
	if (_on_runway):
		if (is_nan(entry_x)):
			_on_runway = false
			_takeoff_left = TAKEOFF_TIME
		else:
			rotation = heading
			angular_velocity = 0.0
			_runway_speed = minf(_runway_speed + _runway_accel * delta, entity_stats.speed)
			linear_velocity = Vector2(dir * _runway_speed, 0.0)
			return
	if (_takeoff_left > 0.0):
		_takeoff_left -= delta
		rotation = lerp_angle(rotation, heading - dir * TAKEOFF_PITCH, 6.0 * delta)
		angular_velocity = 0.0
		linear_velocity = Vector2(cos(rotation), sin(rotation)) * entity_stats.speed

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if (!Engine.is_editor_hint() and !is_dead):
		_takeoff_step(delta)
		if (rotates_with_body() and !_on_runway):
			_level_before_ceiling(delta)
		_hold_below_ceiling()
		_update_flares(delta)
	if (!Engine.is_editor_hint() and !is_dead and is_nan(entry_x) and !_on_runway):
		_avoid_bases()
		_hold_inside_limit()
	var rotation_speed : float = 3.0
	
	if (animated_sprite && !is_dead):
		_update_body_frame()

func _update_body_frame() -> void:
	animated_sprite.frame = map_rotation_to_value()
	check_direction_and_flip()
	_update_props()
	_mirror_guns()

var _guns_mirrored : bool = false

func _mirror_guns() -> void:
	var down : bool = animated_sprite.flip_v
	if (down == _guns_mirrored):
		return
	_guns_mirrored = down
	for gun : Gun in get_guns():
		gun.position.y = -gun.position.y
		gun.scale.y = -gun.scale.y

func get_actual_rotation_angle() -> float:
	return fmod(rotation_degrees + 360, 360)

func map_rotation_to_value() -> int:
	var rotation_dgr : float = get_actual_rotation_angle()
	var value : int = 5 * abs(sin(deg_to_rad(rotation_dgr)))
	return value
	
func check_direction_and_flip() -> void:
	var rotation_dgr : float = fmod(rotation_degrees + 360, 360)
	var is_facing_down : int = rotation_dgr > 90 and rotation_dgr < 270
	animated_sprite.flip_v = is_facing_down 
