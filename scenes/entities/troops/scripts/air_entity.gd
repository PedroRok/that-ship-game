class_name AirEntity
extends Entity

@export
var animated_sprite : AnimatedSprite2D

@export
var animated_blades : AnimatedSprite2D

var gun : PackedScene = preload("res://scenes/entities/guns/simple_gun.tscn")

var is_dead : bool = false

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
	animated_blades.play()
	for guns in get_guns():
		guns.fixed_angle = true
	
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
	if (!Engine.is_editor_hint() and !is_dead and is_nan(entry_x) and !_on_runway):
		_avoid_bases()
	var rotation_speed : float = 3.0
	
	if (animated_sprite && !is_dead):
		animated_sprite.frame = map_rotation_to_value()
		check_direction_and_flip()
		_update_props()
	pass

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
