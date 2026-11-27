class_name HelicopterEntity
extends AirEntity

const LIFT_SPEED : float = 34.0
const MAX_TILT : float = 0.2

var _lift_target_y : float = 0.0
var _lifting : bool = false
var _bob_phase : float = 0.0
var _launch_dir : float = 1.0

func rotates_with_body() -> bool:
	return false

func _prepare_guns() -> void:
	pass

func _setup_visuals() -> void:
	var stats : HelicopterStats = entity_stats as HelicopterStats
	if (!stats):
		return
	var body : SpriteFrames = SpriteFrames.new()
	body.add_frame(&"default", stats.body_frames[0] if !stats.body_frames.is_empty() else stats.sprite)
	animated_sprite.sprite_frames = body
	if (!stats.rotor_frames.is_empty()):
		var rotor : SpriteFrames = SpriteFrames.new()
		rotor.set_animation_speed(&"default", stats.rotor_fps)
		for tex : Texture2D in stats.rotor_frames:
			rotor.add_frame(&"default", tex)
		animated_blades.sprite_frames = rotor
		animated_blades.position = Vector2.ZERO
	_bob_phase = randf() * TAU
	animated_sprite.flip_h = team_stats.direction < 0
	animated_blades.flip_h = animated_sprite.flip_h

func _update_props() -> void:
	pass

func _update_body_frame() -> void:
	var left : bool = facing() < 0.0
	animated_sprite.flip_h = left
	animated_blades.flip_h = left

func begin_takeoff(clear_x : float) -> void:
	_on_runway = true
	_launch_dir = 1.0 if team_stats.direction > 0 else -1.0
	var stats : HelicopterStats = entity_stats as HelicopterStats
	_lift_target_y = global_position.y - (stats.hover_offset if stats else 50.0) - 24.0
	_lifting = true
	begin_entry(clear_x, false)

func _takeoff_step(delta : float) -> void:
	if (!_on_runway):
		return
	if (is_nan(entry_x)):
		_on_runway = false
		_lifting = false
		return
	var speed : float = entity_stats.speed
	if (_lifting):
		if (global_position.y <= _lift_target_y):
			_lifting = false
		linear_velocity = Vector2(_launch_dir * speed * 0.12, -LIFT_SPEED)
	else:
		linear_velocity = Vector2(_launch_dir * speed * 0.7, 0.0)
	rotation = lerp_angle(rotation, _launch_dir * 0.08, 4.0 * delta)
	angular_velocity = 0.0

func tilt_towards(velocity_x : float, attack_bias : float, delta : float) -> void:
	var speed : float = maxf(entity_stats.speed, 1.0)
	var wanted : float = clampf(velocity_x / speed, -1.0, 1.0) * MAX_TILT + attack_bias
	rotation = lerp_angle(rotation, wanted, 4.0 * delta)
	angular_velocity = 0.0
