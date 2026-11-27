class_name AirState
extends State

const TURN_MARGIN : float = 30.0
const RETURN_DISTANCE : float = 220.0
const REVERSAL_START : float = PI * 0.5
const REVERSAL_END : float = 0.6

var on_radar_enemy : Node2D

func turn_back_at_limit() -> bool:
	var plane : AirEntity = parent as AirEntity
	if (!plane):
		return false
	if (retreat_step()):
		return true
	var role : BoatStats = plane.entity_stats as BoatStats
	if (role and role.air_hunter and !_has_target()):
		return _screen(plane)
	if (plane.loiters()):
		return !_has_target() and _loiter(plane)
	if (patrol_context() and !_has_target()):
		return _turn_in_patrol(plane)
	var ahead : float = plane.distance_to_limit()
	if (ahead < TURN_MARGIN):
		plane.turning_back = true
	elif (ahead > RETURN_DISTANCE):
		plane.turning_back = false
	if (!plane.turning_back):
		return false
	var current_angle : float = to_heading(parent.rotation)
	steer(current_angle, -PI + 0.25, 3.0, true)
	parent.linear_velocity = Vector2(cos(parent.rotation), sin(parent.rotation)) * parent.entity_stats.speed
	return true

func _loiter(plane : AirEntity) -> bool:
	if (plane.global_position.x > plane.loiter_max_x):
		plane.turning_back = false
	elif (plane.global_position.x < plane.loiter_min_x):
		plane.turning_back = true
	var pitch : float = clampf((RunData.BOMBER_LOITER_ALTITUDE - plane.global_position.y) / 100.0, -0.45, 0.45)
	steer(to_heading(plane.rotation), PI - pitch if plane.turning_back else pitch, 3.0, true)
	plane.linear_velocity = Vector2(cos(plane.rotation), sin(plane.rotation)) * plane.entity_stats.speed
	return true

func _screen(plane : AirEntity) -> bool:
	var dir : float = mirror_sign()
	var context : BattleContext = BattleContext.of(plane)
	var home : float = NAN
	var away : float = NAN
	for base : Base in context.bases:
		if (base.team_stats.team_id == plane.team_stats.team_id):
			home = base.global_position.x * dir
		else:
			away = base.global_position.x * dir
	if (is_nan(home) or is_nan(away)):
		return false
	var front : float = -INF
	var danger : float = INF
	for other : Entity in context.entities:
		if (other == plane or !other.enabled or other.destroyed):
			continue
		var position_x : float = other.global_position.x * dir
		if (other.team_stats.team_id != plane.team_stats.team_id):
			if (other is ShipEntity):
				danger = minf(danger, position_x - _anti_air_reach(other))
			continue
		var role : BoatStats = other.entity_stats as BoatStats
		if (role and !role.air_hunter):
			front = maxf(front, position_x)
	var base_low : float = home + RunData.HUNTER_BASE_GAP
	var high : float = minf(minf(front + RunData.HUNTER_LEAD, danger - RunData.HUNTER_AA_MARGIN), away)
	high = maxf(high, base_low + RunData.HUNTER_MIN_SPAN)
	var low : float = maxf(base_low, high - RunData.HUNTER_PATROL_SPAN)
	var own : float = plane.global_position.x * dir
	if (own > high):
		plane.turning_back = true
	elif (own < low):
		plane.turning_back = false
	steer(to_heading(plane.rotation), patrol_heading(), 3.0, true)
	plane.linear_velocity = Vector2.from_angle(plane.rotation) * plane.entity_stats.speed
	return true

func _anti_air_reach(ship : Entity) -> float:
	var reach : float = -INF
	for gun : Gun in ship.get_guns():
		if (gun.hits_air and !gun.disabled):
			reach = maxf(reach, gun.effective_range())
	return reach

func retreat_step() -> bool:
	var plane : AirEntity = parent as AirEntity
	if (!plane or !plane.update_retreat()):
		return false
	var pitch : float = clampf((RunData.BOMBER_HOME_ALTITUDE - plane.global_position.y) / 100.0, -0.45, 0.45)
	steer(to_heading(parent.rotation), PI - pitch, 3.0, true)
	parent.linear_velocity = Vector2(cos(parent.rotation), sin(parent.rotation)) * parent.entity_stats.speed
	return true

func steer(current : float, target : float, rate : float, reversing : bool = false) -> void:
	var plane : AirEntity = parent as AirEntity
	var difference : float = angle_difference(current, target)
	var active : bool = plane.is_reversing()
	var needed : float = REVERSAL_END if active else REVERSAL_START
	if (absf(difference) <= needed or (!active and !reversing and absf(difference) <= REVERSAL_START)):
		parent.angular_velocity = signf(difference) * rate * mirror_sign()
		return
	if (!active):
		_choose_reversal(plane, current, rate)
	plane.reversal_frame = Engine.get_physics_frames()
	parent.angular_velocity = plane.reversal_sign * plane.reversal_rate * mirror_sign()

func _choose_reversal(plane : AirEntity, heading : float, rate : float) -> void:
	var up_sign : float = -1.0 if cos(heading) >= 0.0 else 1.0
	var forward_x : float = signf(cos(plane.rotation)) * plane.turn_radius(rate)
	var up_room : float = plane.room_above()
	var down_room : float = plane.room_below(forward_x)
	var needed : float = plane.turn_radius(rate) * 2.0
	var go_up : bool = up_room >= needed or (down_room < needed and up_room >= down_room)
	var room : float = maxf(up_room if go_up else down_room, 1.0)
	plane.reversal_sign = up_sign if go_up else -up_sign
	plane.reversal_rate = clampf(plane.entity_stats.speed * 2.0 / room, rate, AirEntity.MAX_TURN_RATE)

func _has_target() -> bool:
	var radar : RadarComponent = parent.get_node_or_null("RadarComponent") as RadarComponent
	return radar != null and radar.check_radar(parent.team_stats.team_id, parent.team_stats.direction) != null

func patrol_context() -> BattleContext:
	var context : BattleContext = BattleContext.of(parent)
	return context if context and context.has_patrol() else null

func _turn_in_patrol(plane : AirEntity) -> bool:
	var context : BattleContext = patrol_context()
	var offset : float = (plane.global_position.x - context.patrol_x) * mirror_sign()
	if (offset > RunData.PATROL_RADIUS):
		plane.turning_back = true
	elif (offset < -RunData.PATROL_RADIUS):
		plane.turning_back = false
	var heading : float = to_heading(plane.rotation)
	var leaving : bool = offset * cos(heading) > 0.0
	if (!context.outside_patrol(plane) or !leaving):
		return false
	var back : float = -PI + 0.15 if offset > 0.0 else -0.15
	steer(heading, back, 3.0)
	parent.linear_velocity = Vector2(cos(parent.rotation), sin(parent.rotation)) * parent.entity_stats.speed
	return true

func patrol_heading() -> float:
	var plane : AirEntity = parent as AirEntity
	var altitude : float = RunData.PATROL_ALTITUDE + float(plane.get_instance_id() % 4) * RunData.PATROL_ALTITUDE_STEP
	var pitch : float = clampf((altitude - plane.global_position.y) / 100.0, -0.45, 0.45)
	return PI - pitch if plane.turning_back else pitch

func engage_target(target : Node2D) -> Node2D:
	return target

func mirror_sign() -> float:
	return 1.0 if parent.team_stats.direction >= 0 else -1.0

func to_heading(world_angle : float) -> float:
	return world_angle if parent.team_stats.direction >= 0 else PI - world_angle

func avoid_base_climb() -> bool:
	var plane : AirEntity = parent as AirEntity
	if (!plane or !plane.base_danger()):
		return false
	var current_angle : float = to_heading(parent.rotation)
	parent.angular_velocity = get_rotation_direction(current_angle, -1.1) * 3.0 * mirror_sign()
	parent.linear_velocity = Vector2(cos(parent.rotation), sin(parent.rotation)) * parent.entity_stats.speed
	return true

func get_rotation_direction(current: float, target: float) -> float:
	var difference : float = angle_difference(current, target)
	return sign(difference)

func angle_difference(from: float, to: float) -> float:
	var difference : float = to - from
	while difference > PI:
		difference -= 2 * PI
	while difference < -PI:
		difference += 2 * PI
	return difference


func set_guns_enemy(enemy : Node2D) -> void:
	on_radar_enemy = enemy
	for gun in parent.get_guns():
		gun.enemy = enemy
		if (!(gun is BombGun) and !(gun is HomingMissileGun)):
			gun.time_to_shoot = 12
