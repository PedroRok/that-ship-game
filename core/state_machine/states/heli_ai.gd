extends AirState

const ACCEL : float = 90.0
const MIN_ALTITUDE : float = 70.0
const MAX_ALTITUDE : float = 300.0
const BOB_AMPLITUDE : float = 5.0
const BASE_APPROACH : float = 60.0

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

var _clock : float = 0.0
var _phase : float = 0.0

func enter() -> void:
	_phase = randf() * TAU
	set_target(radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction))

func exit() -> void:
	set_target(null)

func set_target(target : Node2D) -> void:
	on_radar_enemy = target
	for gun : Gun in parent.get_guns():
		gun.enemy = target

func standoff_for(target : Node2D) -> float:
	var best : float = INF
	for gun : Gun in parent.get_guns():
		if (gun is BombGun or !gun.can_target(target)):
			continue
		best = minf(best, gun.effective_range())
	if (best == INF):
		return 0.0
	return best * 0.65

func process_physics(delta : float) -> void:
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, "AirDeath")
		return
	var heli : HelicopterEntity = parent as HelicopterEntity
	var stats : HelicopterStats = parent.entity_stats as HelicopterStats
	var dir : float = 1.0 if parent.team_stats.direction >= 0 else -1.0
	var target : Node2D = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	if (target != on_radar_enemy):
		set_target(target)
	_clock += delta
	var speed : float = parent.entity_stats.speed
	var wanted_vx : float = dir * speed
	var wanted_y : float = stats.cruise_height
	var attack_bias : float = 0.0
	if (target):
		var target_pos : Vector2 = target.get_center_pos()
		var ahead : float = (target_pos.x - parent.global_position.x) * dir
		var standoff : float = standoff_for(target)
		if (target is Base):
			standoff = maxf(standoff, BASE_APPROACH)
		var error : float = ahead - standoff
		wanted_vx = dir * clampf(error * 1.4, -speed * 0.6, speed)
		wanted_vx += dir * sin(_clock * 0.9 + _phase) * speed * stats.strafe
		wanted_y = target_pos.y - stats.hover_offset
		if (target is Entity and (target as Entity).entity_stats is AirPlaneState):
			wanted_y = target_pos.y + 14.0
		attack_bias = dir * 0.07 * clampf(1.0 - absf(error) / 90.0, 0.0, 1.0)
	wanted_y = clampf(wanted_y, MIN_ALTITUDE, MAX_ALTITUDE) + sin(_clock * 1.3 + _phase) * BOB_AMPLITUDE
	var velocity : Vector2 = parent.linear_velocity
	velocity.x = move_toward(velocity.x, wanted_vx, ACCEL * delta)
	velocity.y = clampf((wanted_y - parent.global_position.y) * 1.6, -speed * 0.7, speed * 0.7)
	parent.linear_velocity = velocity
	heli.tilt_towards(velocity.x, attack_bias, delta)
	for gun : Gun in parent.get_guns():
		if (gun.enemy):
			gun.shoot_gun(Vector2(dir, 0.0))
