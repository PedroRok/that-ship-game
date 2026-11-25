extends "res://core/state_machine/states/air_death.gd"

const GLIDE_GRAVITY : float = 38.0
const MIN_GLIDE_SPEED : float = 26.0
const FALL_TILT : float = 0.45

func enter() -> void:
	initial_velocity = parent.linear_velocity
	var dir : float = 1.0 if parent.team_stats.direction >= 0 else -1.0
	if (absf(initial_velocity.x) < MIN_GLIDE_SPEED):
		initial_velocity.x = dir * MIN_GLIDE_SPEED
	initial_velocity.y = maxf(initial_velocity.y, 0.0)
	parent.angular_velocity = 0.0
	parent.collision_layer = 12
	parent.collision_mask = 12
	parent.entity_destroy.emit(parent.global_position, parent.entity_stats, parent.team_stats)
	death_deespawn_delay = 500
	decay_rate = 0.998

func process_physics(delta : float) -> void:
	death_deespawn_delay -= 1
	if (death_deespawn_delay == 0):
		_finish()
	if (death_deespawn_delay == -180):
		parent.free()
		return
	var heli : AirEntity = parent as AirEntity
	heli.animated_blades.speed_scale = lerpf(heli.animated_blades.speed_scale, 0.0, delta * 1.5)
	if (hitbox_component.is_on_water):
		decay_rate = 0.95
	initial_velocity.x *= decay_rate
	initial_velocity.y = minf(initial_velocity.y + GLIDE_GRAVITY * delta, 140.0)
	_sink_in_water()
	parent.linear_velocity = initial_velocity
	var dir : float = signf(initial_velocity.x) if initial_velocity.x != 0.0 else 1.0
	parent.rotation = lerp_angle(parent.rotation, dir * FALL_TILT, 2.0 * delta)
	parent.angular_velocity = 0.0
