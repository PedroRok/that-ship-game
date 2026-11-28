class_name DepthLauncherGun
extends Gun

func _init() -> void:
	sfx_event = &"depth_launcher_fire"
	hits_air = false
	hits_surface = false
	hits_submerged = true

func can_target(_target : Node2D) -> bool:
	return false

func _physics_process(_delta : float) -> void:
	var carrier : Entity = get_parent() as Entity
	if (disabled or !carrier or carrier.destroyed or !carrier.enabled):
		return
	if (current_time_to_shoot > 0):
		current_time_to_shoot -= 1
		return
	var victim : Entity = _nearest_submerged(carrier)
	if (!victim):
		return
	current_time_to_shoot = time_to_shoot
	_launch(victim)

func _nearest_submerged(carrier : Entity) -> Entity:
	var best : Entity = null
	var best_distance : float = range_override
	for entity : Entity in BattleContext.of(self).entities:
		if (!entity.enabled or entity.destroyed or !entity.is_submerged() or entity.team_stats.team_id == carrier.team_stats.team_id):
			continue
		var distance : float = absf(entity.get_center_pos().x - global_position.x)
		if (distance <= best_distance):
			best = entity
			best_distance = distance
	return best

func _launch(victim : Entity) -> void:
	var flight : float = RunData.DEPTH_LAUNCH_SECONDS
	var start : Vector2 = end_barrel.global_position
	var goal : float = victim.get_center_pos().x + BulletDepthBomb.lead_x(victim) + victim.linear_velocity.x * flight
	for offset : float in [-RunData.DEPTH_LAUNCH_SPREAD, 0.0, RunData.DEPTH_LAUNCH_SPREAD]:
		_lob(victim, start, goal + offset - start.x)
	play_effects()

func _lob(victim : Entity, start : Vector2, distance : float) -> void:
	var flight : float = RunData.DEPTH_LAUNCH_SECONDS
	var drag : float = BulletDepthBomb.WATER_DRAG
	var forward : float = signf(distance) * drag * (sqrt(flight * flight + 2.0 * absf(distance) / drag) - flight)
	var upward : float = (BulletBomb.WATER_Y - start.y - 0.5 * BulletBomb.GRAVITY * flight * flight) / flight
	var bomb : Bullet = bullet.instantiate()
	bomb.target = victim
	bomb.hits_submerged = true
	bomb.damage = bomb.damage.duplicate()
	bomb.damage.damage *= damage_scale
	fired_bullet.emit(bomb, start, Vector2(forward, upward), 0.0)
