class_name BombRun
extends RefCounted

enum Phase { APPROACH, DROP, RETURN }

const RUN_ALTITUDE : float = 160.0
const BASE_RUN_ALTITUDE : float = 120.0
const MAX_PITCH : float = 0.45
const PITCH_DISTANCE : float = 80.0
const BOMBS : int = 5
const BOSS_BOMBS : int = 8
const DROP_INTERVAL : int = 10
const RETREAT_MARGIN : float = 15.0
const TURN_RATE : float = 3.0
const BOMB_CARRY : float = 0.8
const BOMB_DROP_SPEED : float = 30.0

var phase : Phase = Phase.APPROACH
var _left : int = 0
var _wait : int = 0

func reset() -> void:
	phase = Phase.APPROACH
	_left = 0
	_wait = 0

func step(state : AirState, plane : AirEntity, target : Node2D) -> void:
	var aim_x : float = target.get_center_pos().x + BulletDepthBomb.lead_x(target)
	var ahead : float = (aim_x - plane.global_position.x) * state.mirror_sign()
	var altitude : float = BASE_RUN_ALTITUDE if target is Base else RUN_ALTITUDE
	var heading : float = state.to_heading(plane.rotation)
	var pitch : float = clampf((altitude - plane.global_position.y) / PITCH_DISTANCE, -MAX_PITCH, MAX_PITCH)
	var wanted : float = pitch
	var count : int = BOSS_BOMBS if plane.entity_stats.is_boss else BOMBS
	match phase:
		Phase.APPROACH:
			if (cos(heading) > 0.9):
				if (ahead < 0.0):
					phase = Phase.RETURN
				elif (ahead <= _release_distance(plane, target, count)):
					phase = Phase.DROP
					_left = count
					_wait = 0
		Phase.DROP:
			wanted = 0.0
			if (_wait > 0):
				_wait -= 1
			else:
				_drop(plane, target)
				_left -= 1
				_wait = DROP_INTERVAL
				if (_left <= 0):
					phase = Phase.RETURN
		Phase.RETURN:
			wanted = PI - pitch
			if (ahead >= _release_distance(plane, target, count) + RETREAT_MARGIN or (cos(heading) < 0.0 and plane.base_danger())):
				phase = Phase.APPROACH
	var difference : float = absf(state.angle_difference(heading, wanted))
	state.steer(heading, wanted, clampf(difference * 8.0, 0.01, TURN_RATE), phase == Phase.RETURN)
	plane.linear_velocity = Vector2.from_angle(plane.rotation) * plane.entity_stats.speed

func _release_distance(plane : AirEntity, target : Node2D, count : int) -> float:
	var height : float = maxf(minf(target.get_center_pos().y, BulletBomb.WATER_Y) - plane.global_position.y, 0.0)
	var fall : float = (sqrt(BOMB_DROP_SPEED * BOMB_DROP_SPEED + 2.0 * BulletBomb.GRAVITY * height) - BOMB_DROP_SPEED) / BulletBomb.GRAVITY
	var moving : Entity = target as Entity
	var target_speed : float = moving.linear_velocity.x * signf(cos(plane.rotation)) if moving else 0.0
	var spacing : float = (plane.entity_stats.speed - target_speed) * float(DROP_INTERVAL) / float(Engine.physics_ticks_per_second)
	var drift : float = 0.0
	if (moving and moving.is_submerged()):
		target_speed = 0.0
		drift = BulletDepthBomb.water_drift(plane.entity_stats.speed * BOMB_CARRY)
	return (plane.entity_stats.speed * BOMB_CARRY - target_speed) * fall + drift + spacing * float(count - 1) * 0.5

func _drop(plane : AirEntity, target : Node2D) -> void:
	for gun : Gun in plane.get_guns():
		var bomb_gun : BombGun = gun as BombGun
		if (bomb_gun and !bomb_gun.disabled and bomb_gun.can_target(target)):
			bomb_gun.drop(target)
