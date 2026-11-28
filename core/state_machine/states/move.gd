extends ShipState

const SUPPORT_BASE_STANDOFF : float = 260.0
const SUPPORT_ALLY_GAP : float = 50.0

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

func enter() -> void:
	parent.team_stats.direction = parent.team_stats.direction
	pass

func process_input(_event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	super(delta)
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, "death")
		return
	
	var target_velocity_x : float = parent.team_stats.direction * parent.entity_stats.speed
	if (_is_anti_air_support() and _should_hold()):
		target_velocity_x = 0.0
	if (parent.entity_stats.name == "escort"):
		target_velocity_x *= _escort_pace()
	parent.linear_velocity.x = lerp(parent.linear_velocity.x, target_velocity_x, parent.entity_stats.deceleration * delta)
	if (!parent.guns.is_empty() and radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)):
		Transitioned.emit(self, "attack")
		return

func _escort_pace() -> float:
	if (!is_nan(parent.entry_x)):
		return 1.0
	var facing : float = signf(parent.team_stats.direction)
	var own : float = parent.global_position.x * facing
	var nearest_enemy : float = INF
	var ship_front : float = -INF
	var air_front : float = -INF
	for other : Entity in BattleContext.of(parent).entities:
		if (other == parent or !other.enabled or other.destroyed):
			continue
		var position_x : float = other.global_position.x * facing
		if (other.team_stats.team_id != parent.team_stats.team_id):
			if (position_x > own):
				nearest_enemy = minf(nearest_enemy, position_x)
			continue
		var boat : BoatStats = other.entity_stats as BoatStats
		if (other.guns.is_empty() or (boat and boat.can_submerge)):
			continue
		if (other.entity_stats is AirPlaneState):
			air_front = maxf(air_front, position_x)
		else:
			ship_front = maxf(ship_front, position_x)
	if (nearest_enemy == INF):
		return 1.0
	var uncovered : bool = maxf(ship_front, air_front) <= own
	if (uncovered and nearest_enemy - own < RunData.ESCORT_ENEMY_STANDOFF - RunData.ESCORT_RETREAT_SLACK
			and own > _escort_floor(facing)):
		return -RunData.ESCORT_RETREAT_SPEED
	var limit : float = maxf(nearest_enemy - RunData.ESCORT_ENEMY_STANDOFF,
			maxf(ship_front - RunData.ESCORT_ALLY_GAP, air_front - RunData.ESCORT_AIR_GAP))
	return 0.0 if own >= limit else 1.0

func _escort_floor(facing : float) -> float:
	for base : Base in BattleContext.of(parent).bases:
		if (base.team_stats.team_id == parent.team_stats.team_id):
			return base.global_position.x * facing + RunData.ESCORT_RETREAT_FLOOR
	return -INF

func _is_anti_air_support() -> bool:
	if (parent.guns.is_empty()):
		return false
	for gun : Gun in parent.guns:
		if (gun.hits_surface):
			return false
	return true

func _should_hold() -> bool:
	if (!is_nan(parent.entry_x)):
		return false
	var context : BattleContext = BattleContext.of(parent)
	var team : int = parent.team_stats.team_id
	for base : Base in context.bases:
		if (base.team_stats.team_id != team and base.distance_from(parent.global_position) <= SUPPORT_BASE_STANDOFF):
			return true
	var facing : float = signf(parent.team_stats.direction)
	var front : float = -INF
	for other : Entity in context.entities:
		if (other == parent or !other.enabled or other.destroyed or other.team_stats.team_id != team):
			continue
		if (!(other is ShipEntity) or !_fights_surface(other)):
			continue
		front = maxf(front, other.global_position.x * facing)
	return front != -INF and parent.global_position.x * facing >= front - SUPPORT_ALLY_GAP

func _fights_surface(other : Entity) -> bool:
	for gun : Gun in other.guns:
		if (gun.hits_surface):
			return true
	return false
