class_name EnemyCommander
extends RefCounted

var base : AutoBase
var objective : int = RunData.Objective.DESTROY_BASE
var base_rate : float = 0.9
var bank : float = 0.0
var alert : int = 0
var rate_mult : float = 1.0
var counter_share : float = RunData.ALERT_COUNTER_SHARE[0]
var front : float = 0.0
var field_value : float = 0.0
var enemy_value : float = 0.0
var allies : int = 0
var enemies : int = 0
var opening_strike : bool = false
var opening_unit : String = ""
var slow_left : float = 0.0
var slow_cut : bool = false
var counter_bonus : float = 0.0

var _opening_pending : bool = false
var _targets : Array[Dictionary] = []
var _calm_time : float = 0.0
var _reserve_used : bool = false
var _live_subs : int = 0
var _planned : BoatStats
var _planned_age : float = 0.0
var _hit_cache : Dictionary = {}
var _rng : RandomNumberGenerator = RandomNumberGenerator.new()

func setup(enemy_base : AutoBase, new_objective : int, rate : float, seed_value : int) -> void:
	base = enemy_base
	objective = new_objective
	base_rate = rate
	bank = rate * RunData.SUPPLY_START_SECONDS
	_rng.seed = seed_value

func roll_opening(allowed : bool) -> void:
	if (allowed and _rng.randf() < RunData.OPENING_STRIKE_CHANCE):
		start_opening()

func start_opening() -> void:
	opening_strike = true
	_opening_pending = true
	bank = minf(base_rate * RunData.OPENING_STRIKE_SECONDS, RunData.SUPPLY_MAX_BANK)

static func rate_for(floor_index : int, is_boss_node : bool) -> float:
	if (is_boss_node):
		return RunData.ENEMY_SUPPLY_BOSS
	return RunData.ENEMY_SUPPLY_RATE[clampi(floor_index, 0, RunData.ENEMY_SUPPLY_RATE.size() - 1)]

static func position_weight(progress : float) -> float:
	var clamped : float = clampf(progress, 0.0, 1.0)
	return RunData.THREAT_MIN_WEIGHT + (1.0 - RunData.THREAT_MIN_WEIGHT) * clamped * clamped

func sample(delta : float, context : BattleContext, ally_x : float, enemy_x : float, enemy_base_fraction : float) -> void:
	_targets.clear()
	allies = 0
	enemies = 0
	_live_subs = 0
	front = 0.0
	field_value = 0.0
	enemy_value = 0.0
	var mid : float = 0.0
	var near : float = 0.0
	var span : float = enemy_x - ally_x
	for unit : Entity in context.entities:
		if (!is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.entity_stats == null):
			continue
		var stats : EntityStats = unit.entity_stats
		var boat : BoatStats = stats as BoatStats
		var price : float = float(boat.price if boat else 0)
		if (unit.team_stats.team_id == 1):
			if (stats.name == "escort"):
				continue
			allies += 1
			var progress : float = clampf((unit.global_position.x - ally_x) / span, 0.0, 1.0) if span != 0.0 else 0.0
			front = maxf(front, progress)
			field_value += price
			if (progress >= RunData.ALERT_MID_PROGRESS):
				mid += price
			if (progress >= RunData.ALERT_NEAR_PROGRESS):
				near += price
			_targets.append({"class": int(stats.unit_class), "weight": price * position_weight(progress),
				"air": stats is AirPlaneState, "sub": unit.is_submerged() or (boat != null and boat.can_submerge)})
		else:
			enemies += 1
			enemy_value += price
			if (boat and boat.can_submerge):
				_live_subs += 1
	_update_alert(delta, wanted_alert(mid, near, enemy_base_fraction))

static func wanted_alert(mid_value : float, near_value : float, enemy_base_fraction : float) -> int:
	if (near_value >= RunData.ALERT_NEAR_VALUE or enemy_base_fraction < RunData.ALERT_BASE_FRACTION):
		return 2
	if (mid_value >= RunData.ALERT_MID_VALUE):
		return 1
	return 0

func _update_alert(delta : float, wanted : int) -> void:
	if (wanted >= alert):
		alert = wanted
		_calm_time = 0.0
		if (alert > 0 and (_opening_pending or slow_left > 0.0)):
			slow_cut = true
			slow_left = 0.0
	else:
		_calm_time += delta
		if (_calm_time >= RunData.ALERT_HOLD_SECONDS):
			alert = wanted
			_calm_time = 0.0
	if (alert == 2 and !_reserve_used):
		_reserve_used = true
		bank = minf(bank + RunData.ALERT_RESERVE, RunData.SUPPLY_MAX_BANK)
	rate_mult = RunData.ALERT_SUPPLY_MULT[alert]
	counter_share = minf(RunData.ALERT_COUNTER_SHARE[alert] + counter_bonus, 0.9)

func tick(delta : float) -> void:
	if (base == null or !base.active or base.ships.is_empty()):
		return
	if (_opening_pending):
		_build_opening()
		return
	var slow : float = RunData.OPENING_SLOW_MULT if slow_left > 0.0 else 1.0
	slow_left = maxf(slow_left - delta, 0.0)
	bank = minf(bank + base_rate * rate_mult * slow * delta, RunData.SUPPLY_MAX_BANK)
	base.build_pending_bosses()
	_planned_age += delta
	if (_planned == null or _planned_age > RunData.PLAN_SECONDS or (_planned.air_hunter and !_player_has_air())):
		_planned = _pick()
		_planned_age = 0.0
	if (_planned == null or float(_planned.price) > bank):
		return
	if (base.over_limits(Base.dock_type_of(_planned))):
		_planned = null
		return
	if (base.start_build_ship(base.scaled_copy(_planned))):
		bank -= float(_planned.price)
		_planned = null

func _build_opening() -> void:
	var affordable : Array[BoatStats] = []
	for unit : BoatStats in _pool():
		if (float(unit.price) <= bank):
			affordable.append(unit)
	if (affordable.is_empty()):
		_opening_pending = false
		return
	var chosen : BoatStats = affordable[_rng.randi() % affordable.size()]
	if (!base.start_build_ship(base.scaled_copy(chosen))):
		return
	_opening_pending = false
	opening_unit = chosen.name
	bank = 0.0
	slow_left = 0.0 if slow_cut else RunData.OPENING_SLOW_SECONDS

func _pool() -> Array[BoatStats]:
	var result : Array[BoatStats] = []
	for item : Variant in base.ships:
		var unit : BoatStats = item
		if (!unit.is_boss and !base.over_limits(Base.dock_type_of(unit)) and (!unit.air_hunter or _player_has_air())):
			result.append(unit)
	return result

func _player_has_air() -> bool:
	for target : Dictionary in _targets:
		if (bool(target["air"])):
			return true
	return false

func _pick() -> BoatStats:
	var pool : Array[BoatStats] = _pool()
	if (pool.is_empty()):
		return null
	if (objective == RunData.Objective.HUNT_SUBMARINE and _live_subs == 0):
		var subs : Array[BoatStats] = []
		for unit : BoatStats in pool:
			if (unit.can_submerge):
				subs.append(unit)
		if (!subs.is_empty()):
			return subs[_rng.randi() % subs.size()]
	if (!_targets.is_empty() and _rng.randf() < counter_share):
		var counter : BoatStats = _pick_counter(pool)
		if (counter):
			return counter
	return pool[_rng.randi() % pool.size()]

func _pick_counter(pool : Array[BoatStats]) -> BoatStats:
	var scores : Array[float] = []
	var total : float = 0.0
	for unit : BoatStats in pool:
		var score : float = counter_score(unit, _targets)
		score = score * score * score
		scores.append(score)
		total += score
	if (total <= 0.0):
		return null
	var roll : float = _rng.randf() * total
	for index : int in range(pool.size()):
		roll -= scores[index]
		if (roll <= 0.0):
			return pool[index]
	return pool[pool.size() - 1]

func counter_score(unit : BoatStats, targets : Array[Dictionary]) -> float:
	var hits : Dictionary = _hits(unit)
	var score : float = 0.0
	var weights : float = 0.0
	for target : Dictionary in targets:
		var weight : float = float(target["weight"])
		weights += weight
		var kind : String = "sub" if bool(target["sub"]) else ("air" if bool(target["air"]) else "surface")
		if (bool(hits[kind])):
			score += weight * Global.counter_multiplier(unit.unit_class, int(target["class"]) as Enums.UnitClass)
	return score / weights if weights > 0.0 else 0.0

func _hits(unit : BoatStats) -> Dictionary:
	if (_hit_cache.has(unit.name)):
		return _hit_cache[unit.name]
	var result : Dictionary = {"air": false, "surface": false, "sub": false}
	for slot : GunSlot in unit.gun_slots:
		var gun_type : int = slot.default_gun_type()
		if (gun_type < 0):
			continue
		var scene : PackedScene = Enums.gun_scene(gun_type)
		if (scene == null):
			continue
		var gun : Gun = scene.instantiate() as Gun
		if (gun == null):
			continue
		result["air"] = bool(result["air"]) or gun.hits_air
		result["surface"] = bool(result["surface"]) or (gun.hits_surface and unit.surface_damage_mult != 0.0)
		result["sub"] = bool(result["sub"]) or gun.hits_submerged
		gun.free()
	_hit_cache[unit.name] = result
	return result
