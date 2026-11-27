extends AirState

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

@export
var distance_warn_component : DistanceWarnComponent

var pass_until : float = 0.0
var _clock : float = 0.0
var _bomb_run : BombRun = BombRun.new()
var _escaping : bool = false
var _boost : float = 1.0
var _smoke_left : float = 0.0

func enter() -> void:
	_bomb_run.reset()
	_escaping = false
	_boost = 1.0
	var enemy : Node = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	set_guns_enemy(enemy)
	pass
	
func exit() -> void:
	set_guns_enemy(null)
	pass

func process_physics(delta: float) -> void:
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, "AirDeath")
		return
	
	if ((parent as AirEntity).is_bomber()):
		_process_bomber()
		return

	if distance_warn_component.enemy_hitbox.size() > 1 || distance_warn_component.is_too_low:
		Transitioned.emit(self, "manuver")
		return
	
	var target : Node2D = engage_target(radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction))
	if not target or !(parent as AirEntity).can_engage():
		Transitioned.emit(self, "airmove")
		return
	
	if (turn_back_at_limit()):
		return
	
	if (avoid_base_climb()):
		for gun in parent.get_guns():
			gun.shoot_gun(Vector2(1, 0))
			gun.projectile_rotation_spawn = parent.rotation
		return
	_clock += delta
	var now : float = _clock
	if (now < pass_until):
		var climb_angle : float = to_heading(parent.rotation)
		var climb_to : float = -PI + 0.5 if patrol_context() and cos(climb_angle) < 0.0 else -0.5
		steer(climb_angle, climb_to, 2.0)
		for gun in parent.get_guns():
			gun.shoot_gun(Vector2(1, 0))
			gun.projectile_rotation_spawn = parent.rotation
		parent.linear_velocity = Vector2(cos(parent.rotation), sin(parent.rotation)) * _flight_speed(delta)
		return
	var trigger : float = 34.0 if target is Entity else 95.0
	if (target.get_center_pos().distance_to(parent.global_position) < trigger):
		pass_until = now + 1.5

	if target:
		var to_target : Vector2 = target.get_center_pos() - parent.global_position
		var rate : float = 2.0
		var role : BoatStats = parent.entity_stats as BoatStats
		if (role and role.air_hunter):
			var plan : Array = _hunter_plan(to_target)
			to_target = plan[0]
			rate = plan[1]
		var target_angle : float = to_heading(to_target.angle())
		var current_angle : float = to_heading(parent.rotation)
		
		steer(current_angle, target_angle, rate)
		
		if abs(angle_difference(current_angle, target_angle)) < 0.1:
			pass
			
	if (on_radar_enemy != target):
		set_guns_enemy(target)
	
	for gun in parent.get_guns():
		gun.shoot_gun(Vector2(1, 0))
		gun.projectile_rotation_spawn = parent.rotation
	var direction : Vector2 = Vector2(cos(parent.rotation), sin(parent.rotation))
	parent.linear_velocity = direction * _flight_speed(delta)

func _threat() -> Entity:
	for other : Entity in BattleContext.of(parent).entities:
		var plane : AirEntity = other as AirEntity
		if (!plane or !plane.enabled or plane.destroyed or !plane.rotates_with_body()
				or plane.team_stats.team_id == parent.team_stats.team_id):
			continue
		var offset : Vector2 = parent.global_position - plane.global_position
		if (offset.length() > RunData.HUNTER_THREAT_RANGE
				or absf(Vector2.from_angle(plane.rotation).angle_to(offset)) > deg_to_rad(RunData.HUNTER_THREAT_CONE)):
			continue
		for gun : Gun in plane.get_guns():
			if (!(gun is BombGun) and gun.can_target(parent)):
				return plane
	return null

func _hunter_plan(direct : Vector2) -> Array:
	var forward : Vector2 = Vector2.from_angle(parent.rotation)
	var distance : float = direct.length()
	if (_escaping and distance > RunData.HUNTER_RETURN_DISTANCE):
		_escaping = false
	elif (!_escaping and distance < RunData.HUNTER_BREAK_DISTANCE and forward.dot(direct) < distance * 0.5):
		_escaping = true
	if (_escaping):
		var climb : float = -RunData.HUNTER_BREAK_CLIMB
		if (parent.global_position.y <= RunData.HUNTER_BREAK_ALTITUDE):
			climb = RunData.HUNTER_BREAK_CLIMB
		return [Vector2(signf(forward.x) if forward.x != 0.0 else 1.0, climb), 2.0]
	var threat : Entity = _threat()
	if (threat and absf(forward.angle_to(direct)) >= deg_to_rad(RunData.HUNTER_AIM_ANGLE)):
		var course : Vector2 = Vector2.from_angle(threat.rotation)
		var side : float = signf(course.cross(parent.global_position - threat.global_position))
		return [course.rotated((side if side != 0.0 else 1.0) * deg_to_rad(RunData.HUNTER_EVADE_ANGLE)), 3.0]
	return [direct, 2.5]

func _flight_speed(delta : float) -> float:
	var goal : float = RunData.HUNTER_BOOST_MULT if _escaping else 1.0
	_boost = move_toward(_boost, goal, RunData.HUNTER_BOOST_ACCEL * delta)
	if (_escaping):
		_smoke_left -= delta
		if (_smoke_left <= 0.0):
			_smoke_left = RunData.HUNTER_SMOKE_INTERVAL
			AirPuff.smoke(parent, parent.global_position - Vector2.from_angle(parent.rotation) * 9.0)
	return parent.entity_stats.speed * _boost

func _process_bomber() -> void:
	if (retreat_step()):
		_bomb_run.reset()
		return
	var target : Node2D = engage_target(radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction))
	if (!target):
		Transitioned.emit(self, "airmove")
		return
	if (on_radar_enemy != target):
		set_guns_enemy(target)
	_bomb_run.step(self, parent as AirEntity, target)
