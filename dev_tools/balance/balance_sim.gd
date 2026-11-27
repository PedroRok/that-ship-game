class_name BalanceSim
extends RefCounted

const DT : float = 0.1
const SPEED_NAVAL : float = 0.12
const SPEED_SUB : float = 0.21
const SPEED_AIR : float = 0.96
const SPEED_BOSS_NAVAL : float = 0.5
const AIR_UPTIME : float = 0.5
const BASE_HALF_WIDTH : float = 60.0
const START_OFFSET : float = 40.0
const DECISION_SECONDS : float = 0.5
const START_SCREWS : int = 10
const QUEUE_BASE : int = 3
const ESCORT_NAME : String = "escort"
const BOSS_HEALTH_MULT : float = 3.0
const BOSS_WAVE_EXTRA : int = 2
const OPEN_ENDED_LIMIT : float = 900.0
const TURRET_GUN : int = Enums.Guns.SMALL_GUN
const COUNTS_HUNT : String = "hunt"

class SimUnit extends RefCounted:
	var profile : BalanceUnit
	var ally : bool = false
	var x : float = 0.0
	var start_x : float = 0.0
	var hp : float = 1.0
	var max_hp : float = 1.0
	var speed : float = 0.0
	var radar : float = 0.0
	var cooldowns : Array[float] = []
	var submerged : bool = false
	var boss : bool = false
	var escort : bool = false
	var alive : bool = true

class SimBuild extends RefCounted:
	var profile : BalanceUnit
	var hp : float = 1.0
	var boss : bool = false
	var escort : bool = false

class SimDock extends RefCounted:
	var type : int = 0
	var current : SimBuild
	var time_left : float = 0.0
	var queue : Array[SimBuild] = []
	var next_fire : float = 0.0
	var built : int = 0

static var _profiles : Dictionary = {}

var _scn : BalanceScenario
var _rng : RandomNumberGenerator = RandomNumberGenerator.new()
var _director : ThreatDirector = ThreatDirector.new()
var _units : Array[SimUnit] = []
var _ally_docks : Dictionary = {}
var _enemy_docks : Dictionary = {}
var _loadout : Array[BalanceUnit] = []
var _pool : Array[BalanceUnit] = []
var _pending_boss : SimBuild
var _extra_boss_done : bool = false
var _turret_gun : Dictionary = {}
var _turrets : int = 0
var _turret_cd : Array[float] = []

var _t : float = 0.0
var _wave : int = -1
var _stat_mult : float = 1.0
var _spawn_interval : float = 5.0
var _production_mult : float = 1.0
var _health_mult : float = 1.0
var _distance : float = 2000.0
var _ally_hp : float = 100.0
var _ally_max : float = 100.0
var _enemy_hp : float = 40.0
var _enemy_max : float = 40.0
var _screws : float = 0.0
var _income_clock : float = 0.0
var _decision_clock : float = 0.0
var _director_clock : float = 0.0
var _defend_left : float = 0.0
var _defend_target : float = 0.0
var _ally_hold : float = 0.0
var _enemy_hold : float = 0.0
var _time_limit : float = 0.0
var _hunted : int = 0
var _boss_down : bool = false
var _done : bool = false
var _won : bool = false
var _reason : String = ""
var _escort_unit : SimUnit

var _peak_enemies : int = 0
var _enemy_sum : float = 0.0
var _samples : int = 0
var _enemy_spawned : int = 0
var _enemy_spawned_by : Dictionary = {}
var _ally_spawned : int = 0
var _contested_time : float = 0.0
var _screws_spent : int = 0
var _peak_by_kind : Dictionary = {}
var _kills : int = 0
var _shots : Array[Dictionary] = []

static func profile_of(stats : BoatStats) -> BalanceUnit:
	var key : String = stats.name
	if (!_profiles.has(key)):
		_profiles[key] = BalanceUnit.from_stats(stats)
	return _profiles[key]

static func clear_cache() -> void:
	_profiles.clear()

func run(scenario : BalanceScenario) -> Dictionary:
	begin(scenario)
	while (!step()):
		pass
	return _result()

func begin(scenario : BalanceScenario) -> void:
	_scn = scenario
	_rng.seed = scenario.seed_value
	_setup()

func step() -> bool:
	if (_done):
		return true
	var limit : float = _time_limit if _time_limit > 0.0 else OPEN_ENDED_LIMIT
	_tick()
	if (!_done and _t >= limit + 1.0):
		_finish(false, "timeout")
	return _done

func is_done() -> bool:
	return _done

func result() -> Dictionary:
	return _result()

func snapshot() -> Dictionary:
	var list : Array[Dictionary] = []
	for unit : SimUnit in _units:
		list.append({"x": unit.x, "ally": unit.ally, "hp": unit.hp / maxf(unit.max_hp, 0.01), "air": unit.profile.is_air,
			"sub": unit.profile.can_submerge, "submerged": unit.submerged, "boss": unit.boss, "escort": unit.escort,
			"id": unit.profile.id})
	var objective_text : String = "enemy base"
	match _scn.objective:
		RunData.Objective.DEFEND:
			objective_text = "hold %.0fs vs %.0fs, %.0fs left, contested %.0fs" % [_ally_hold, _enemy_hold, _defend_left, _contested_time]
		RunData.Objective.HUNT_SUBMARINE:
			objective_text = "subs sunk %d/%d" % [_hunted, RunData.HUNT_TARGET]
		RunData.Objective.ESCORT:
			objective_text = "escort alive" if _escort_unit and _escort_unit.alive else "escort lost"
		RunData.Objective.SHOOT_DOWN_BOMBER, RunData.Objective.DEFEAT_BOSS:
			objective_text = "boss down" if _boss_down else "boss alive"
	_prune_shots()
	return {"shots": _shots.duplicate(), "units": list, "t": _t, "distance": _distance, "ally_hp": maxf(_ally_hp, 0.0) / maxf(_ally_max, 1.0),
		"enemy_hp": maxf(_enemy_hp, 0.0) / maxf(_enemy_max, 1.0), "screws": _screws, "wave": _wave,
		"threat": _director.threat, "objective_text": objective_text, "time_limit": _time_limit,
		"done": _done, "won": _won, "reason": _reason, "enemy_spawned": _enemy_spawned, "ally_spawned": _ally_spawned,
		"loadout": _loadout.map(func(unit : BalanceUnit) -> String: return unit.id),
		"beacon": _distance * 0.5 if _scn.objective == RunData.Objective.DEFEND else -1.0}

func _setup() -> void:
	var entry : Dictionary = _scn.entry()
	var col : int = clampi(_scn.floor_index, 0, RunData.ENEMY_SPAWN_INTERVAL.size() - 1)
	var span : Array = RunData.BATTLE_DISTANCE[_scn.objective]
	_distance = lerpf(float(span[0]), float(span[1]), _scn.distance_t)
	_ally_max = _scn.progress.modify(Enums.UpgradeTarget.BASE, &"base_health", float(RunData.BASE_MAX_HP))
	_ally_hp = _ally_max * _scn.ally_hp_fraction
	var tier : BaseTier = RunBattleConfig.tier_for(entry)
	_enemy_max = float(tier.base_health)
	_enemy_hp = _enemy_max
	_production_mult = tier.production_interval_mult
	_turrets = tier.turret_count
	_turret_gun = BalanceUnit.gun_entry(TURRET_GUN)
	for index : int in range(_turrets):
		_turret_cd.append(0.0)
	_health_mult = RunData.ENEMY_HEALTH_MULT[col] * _scn.enemy_health_mult
	if (_scn.elite):
		_health_mult *= RunData.ELITE_HEALTH_MULT
	for stats : BoatStats in RunBattleConfig.pool_for(entry):
		_pool.append(profile_of(stats))
	var boss_stats : BoatStats = RunBattleConfig.boss_for(entry)
	if (boss_stats):
		_pending_boss = _boss_build(boss_stats)
	if (_scn.objective == RunData.Objective.DEFEND):
		_defend_left = RunData.DEFEND_LIMIT_SECONDS * _scn.time_mult
		_defend_target = RunData.DEFEND_HOLD_SECONDS * _scn.time_mult
		_time_limit = 0.0
	else:
		_time_limit = float(RunData.TIME_LIMITS.get(_scn.objective, 0.0)) * _scn.time_mult
	for dock_type : int in [BaseDock.Type.NAVAL, BaseDock.Type.AIR, BaseDock.Type.SUB]:
		var ally_dock : SimDock = SimDock.new()
		ally_dock.type = dock_type
		_ally_docks[dock_type] = ally_dock
		var enemy_dock : SimDock = SimDock.new()
		enemy_dock.type = dock_type
		_enemy_docks[dock_type] = enemy_dock
	_loadout = pick_loadout(_scn.progress)
	_screws = _scn.progress.modify(Enums.UpgradeTarget.BASE, &"start_screw", float(START_SCREWS))
	if (_scn.objective == RunData.Objective.ESCORT):
		_spawn_escort()

func _boss_build(stats : BoatStats) -> SimBuild:
	var build : SimBuild = SimBuild.new()
	build.profile = profile_of(stats)
	build.hp = stats.health * BOSS_HEALTH_MULT
	build.boss = true
	return build

func _spawn_escort() -> void:
	var stats : BoatStats = RunBattleConfig.escort_stats()
	var profile : BalanceUnit = profile_of(stats)
	var build : SimBuild = SimBuild.new()
	build.profile = profile
	build.hp = _scn.progress.modify(Enums.UpgradeTarget.ENTITY, &"health", stats.health, ESCORT_NAME)
	build.escort = true
	_escort_unit = _spawn(build, true)

static func pick_loadout(progress : BalanceProgress) -> Array[BalanceUnit]:
	var options : Array[BalanceUnit] = []
	for unit_name : String in progress.unlocked:
		var stats : BoatStats = Global.CATALOG.find_unit(unit_name)
		if (stats):
			options.append(profile_of(stats))
	options.sort_custom(func(a : BalanceUnit, b : BalanceUnit) -> bool: return static_value(a) > static_value(b))
	var chosen : Array[BalanceUnit] = []
	for unit : BalanceUnit in options:
		if (chosen.size() < PlayerStats.MAX_LOADOUT):
			chosen.append(unit)
	for kind : String in ["air", "sub"]:
		var covered : bool = false
		for unit : BalanceUnit in chosen:
			if (unit.hits(kind)):
				covered = true
		if (covered):
			continue
		for unit : BalanceUnit in options:
			if (unit.hits(kind) and !chosen.has(unit)):
				chosen.pop_back()
				chosen.append(unit)
				break
	return chosen

static func static_value(unit : BalanceUnit) -> float:
	var power : float = maxf(unit.dps("surface"), maxf(unit.dps("air"), unit.dps("sub")))
	return unit.health * power / maxf(float(unit.price), 1.0)

func _tick() -> void:
	_t += DT
	_update_wave()
	_income()
	_decide()
	_enemy_docks_tick()
	_docks_tick(_ally_docks, true)
	_docks_tick(_enemy_docks, false)
	_combat()
	_objective_tick()
	_director_tick()
	_sample()

func _update_wave() -> void:
	var wave : int = int(_t / RunData.WAVE_DURATION)
	if (wave == _wave):
		return
	_wave = wave
	_stat_mult = _health_mult * pow(RunData.WAVE_RAMP_HEALTH, wave)
	var col : int = clampi(_scn.floor_index, 0, RunData.ENEMY_SPAWN_INTERVAL.size() - 1)
	_spawn_interval = maxf(2.5, RunData.ENEMY_SPAWN_INTERVAL[col] * pow(RunData.WAVE_RAMP_INTERVAL, wave))
	if (wave == BOSS_WAVE_EXTRA and _scn.extra_boss and !_extra_boss_done):
		_extra_boss_done = true
		_pending_boss = _boss_build(RunBattleConfig.extra_boss())
	for dock_type : int in _enemy_docks:
		var dock : SimDock = _enemy_docks[dock_type]
		dock.next_fire = _t + _dock_interval(dock_type)
		_enemy_dock_fire(dock)

func _dock_interval(dock_type : int) -> float:
	var mult : float = 1.0
	if (dock_type != BaseDock.Type.NAVAL):
		mult = 1.5
	return maxf(_spawn_interval * _production_mult * _director.interval_mult * mult, 0.1)

func _enemy_docks_tick() -> void:
	for dock_type : int in _enemy_docks:
		var dock : SimDock = _enemy_docks[dock_type]
		if (_t >= dock.next_fire):
			dock.next_fire = _t + _dock_interval(dock_type)
			_enemy_dock_fire(dock)

func _enemy_dock_fire(dock : SimDock) -> void:
	if (_pool.is_empty()):
		return
	if (_pending_boss == null and _over_limits(dock.type)):
		return
	if (_director.skip_chance > 0.0 and _pending_boss == null and _rng.randf() < _director.skip_chance):
		return
	if (_pending_boss and Base.dock_type_of(_pending_boss.profile.stats) == dock.type):
		if (dock.current == null):
			_start_build(dock, _pending_boss, 1.0)
			_pending_boss = null
		return
	var candidates : Array[BalanceUnit] = []
	for profile : BalanceUnit in _pool:
		if (Base.dock_type_of(profile.stats) == dock.type):
			candidates.append(profile)
	if (candidates.is_empty() or dock.current != null):
		return
	var pick : BalanceUnit = candidates[_rng.randi() % candidates.size()]
	var build : SimBuild = SimBuild.new()
	build.profile = pick
	build.hp = pick.health * _stat_mult
	_start_build(dock, build, 1.0)

func _over_limits(dock_type : int) -> bool:
	var cap : int = _scn.spawn_cap
	if (cap <= 0):
		cap = RunData.ENEMY_LIVE_CAP[clampi(_scn.floor_index, 0, RunData.ENEMY_LIVE_CAP.size() - 1)]
	var live : int = 0
	var subs : int = 0
	var boss_alive : bool = false
	for unit : SimUnit in _units:
		if (unit.ally or !unit.alive):
			continue
		live += 1
		if (unit.profile.can_submerge):
			subs += 1
		if (unit.boss):
			boss_alive = true
	if (live >= cap):
		return true
	if (_scn.objective == RunData.Objective.HUNT_SUBMARINE and dock_type == BaseDock.Type.SUB and subs >= RunData.HUNT_SUB_CAP):
		return true
	return boss_alive and _rng.randf() < RunData.BOSS_SPAWN_SKIP

func _start_build(dock : SimDock, build : SimBuild, mult : float) -> void:
	dock.current = build
	dock.time_left = build.profile.build_time * mult

func _docks_tick(docks : Dictionary, ally : bool) -> void:
	for dock_type : int in docks:
		var dock : SimDock = docks[dock_type]
		if (dock.current == null and ally and !dock.queue.is_empty()):
			var mult : float = _scn.progress.modify(Enums.UpgradeTarget.BASE, &"build_time", 1.0)
			_start_build(dock, dock.queue.pop_front(), mult)
		if (dock.current == null):
			continue
		dock.time_left -= DT
		if (dock.time_left > 0.0):
			continue
		var finished : SimBuild = dock.current
		dock.current = null
		dock.built += 1
		_spawn(finished, ally)
		if (ally):
			_ally_spawned += 1
		else:
			_enemy_spawned += 1
			var key : String = finished.profile.id
			_enemy_spawned_by[key] = int(_enemy_spawned_by.get(key, 0)) + 1

func _spawn(build : SimBuild, ally : bool) -> SimUnit:
	var unit : SimUnit = SimUnit.new()
	unit.profile = build.profile
	unit.ally = ally
	unit.hp = build.hp
	unit.max_hp = build.hp
	unit.boss = build.boss
	unit.escort = build.escort
	unit.speed = build.profile.speed
	unit.radar = build.profile.radar
	if (ally):
		var progress : BalanceProgress = _scn.progress
		var unit_name : String = ESCORT_NAME if build.escort else build.profile.id
		if (!build.escort):
			unit.hp = progress.modify(Enums.UpgradeTarget.ENTITY, &"health", build.hp, unit_name)
			unit.max_hp = unit.hp
		unit.speed = progress.modify(Enums.UpgradeTarget.ENTITY, &"speed", build.profile.speed, unit_name)
		unit.radar = progress.modify(Enums.UpgradeTarget.ENTITY, &"radar_distance", build.profile.radar, unit_name)
		unit.x = START_OFFSET
	else:
		unit.x = _distance - START_OFFSET
	unit.start_x = unit.x
	for gun : Dictionary in build.profile.guns:
		unit.cooldowns.append(0.0)
	_units.append(unit)
	return unit

func _income() -> void:
	var period : float = _scn.progress.modify(Enums.UpgradeTarget.BASE, &"screw_income_time", 1.0)
	_income_clock += DT
	while (_income_clock >= period):
		_income_clock -= period
		_screws += 1.0

func _queue_room(dock : SimDock) -> bool:
	var stat : StringName = Base.QUEUE_STATS[dock.type]
	var capacity : int = QUEUE_BASE + int(_scn.progress.modify(Enums.UpgradeTarget.BASE, stat, 0.0))
	var used : int = dock.queue.size() + (1 if dock.current != null else 0)
	return used < capacity

func _decide() -> void:
	_decision_clock += DT
	if (_decision_clock < DECISION_SECONDS):
		return
	_decision_clock = 0.0
	for attempt : int in range(4):
		var pick : BalanceUnit = _choose()
		if (pick == null):
			return
		var dock : SimDock = _ally_docks[Base.dock_type_of(pick.stats)]
		var build : SimBuild = SimBuild.new()
		build.profile = pick
		build.hp = pick.health
		dock.queue.append(build)
		_screws -= float(pick.price)
		_screws_spent += pick.price

func _choose() -> BalanceUnit:
	var affordable : Array[BalanceUnit] = []
	for unit : BalanceUnit in _loadout:
		if (float(unit.price) <= _screws and _queue_room(_ally_docks[Base.dock_type_of(unit.stats)])):
			affordable.append(unit)
	if (affordable.is_empty()):
		return null
	match _scn.policy:
		BalanceScenario.Policy.RANDOM:
			return affordable[_rng.randi() % affordable.size()]
		BalanceScenario.Policy.CHEAPEST:
			var cheapest : BalanceUnit = affordable[0]
			for unit : BalanceUnit in affordable:
				if (unit.price < cheapest.price):
					cheapest = unit
			return cheapest
	var mix : Dictionary = _enemy_mix()
	var best : BalanceUnit = null
	var best_score : float = -1.0
	for unit : BalanceUnit in affordable:
		var score : float = _counter_score(unit, mix)
		if (score > best_score):
			best_score = score
			best = unit
	var dream : BalanceUnit = null
	var dream_score : float = -1.0
	for unit : BalanceUnit in _loadout:
		var score : float = _counter_score(unit, mix)
		if (score > dream_score):
			dream_score = score
			dream = unit
	if (dream != null and dream != best and dream_score > best_score * 1.4 and float(dream.price) - _screws <= 6.0):
		return null
	return best

func _enemy_mix() -> Dictionary:
	var mix : Dictionary = {"air": 0.0, "sub": 0.0, "surface": 0.0}
	for unit : SimUnit in _units:
		if (unit.ally or !unit.alive):
			continue
		var weight : float = unit.hp
		if (unit.submerged or unit.profile.can_submerge):
			mix["sub"] = float(mix["sub"]) + weight
		elif (unit.profile.is_air):
			mix["air"] = float(mix["air"]) + weight
		else:
			mix["surface"] = float(mix["surface"]) + weight
	var total : float = float(mix["air"]) + float(mix["sub"]) + float(mix["surface"])
	if (total <= 0.0):
		return {"air": 0.0, "sub": 0.0, "surface": 1.0}
	for key : String in mix:
		mix[key] = float(mix[key]) / total
	return mix

func _counter_score(unit : BalanceUnit, mix : Dictionary) -> float:
	var gun_mult : float = _scn.progress.modify(Enums.UpgradeTarget.GUN, &"damage", 1.0)
	var power : float = 0.0
	for kind : String in mix:
		power += float(mix[kind]) * unit.dps(kind) * gun_mult
	return unit.health * power / maxf(float(unit.price), 1.0)

func _combat() -> void:
	var hits : Array[Array] = []
	var gun_mult : float = _scn.progress.modify(Enums.UpgradeTarget.GUN, &"damage", 1.0)
	var gun_rate : float = _scn.progress.modify(Enums.UpgradeTarget.GUN, &"shoot_interval", 1.0)
	for unit : SimUnit in _units:
		if (!unit.alive):
			continue
		if (unit.profile.can_submerge and !unit.submerged and absf(unit.x - unit.start_x) >= unit.profile.dive_distance):
			unit.submerged = true
		var target : SimUnit = _find_target(unit)
		var base_target : bool = false
		if (target == null):
			base_target = _base_in_reach(unit)
		if (target == null and !base_target):
			var direction : float = 1.0 if unit.ally else -1.0
			unit.x += direction * unit.speed * _speed_factor(unit) * DT
			continue
		var uptime : float = AIR_UPTIME if unit.profile.is_air else 1.0
		for index : int in range(unit.profile.guns.size()):
			var gun : Dictionary = unit.profile.guns[index]
			unit.cooldowns[index] -= DT
			if (unit.cooldowns[index] > 0.0):
				continue
			var damage : float = float(gun["damage"])
			var interval : float = float(gun["interval"])
			if (unit.ally):
				damage *= gun_mult
				interval *= gun_rate
			if (target != null):
				if (!_gun_can_hit(gun, target) or absf(target.x - unit.x) > float(gun["range"])):
					continue
				var counter : float = Global.counter_multiplier(unit.profile.unit_class, target.profile.unit_class)
				unit.cooldowns[index] = interval
				var los : float = 1.0
				if (target.submerged and !unit.submerged and bool(gun.get("los", false))):
					los = _sub_los(int(gun["type"]))
				if (_rng.randf() <= _scn.hit_rate * uptime * los):
					hits.append([target, damage * counter])
					_log_shot(unit.x, unit.ally, unit.profile.id, target.x, target.profile.id, damage * counter, target.profile.is_air)
			else:
				if (!bool(gun["surface"]) or _base_distance(unit) > float(gun["range"])):
					continue
				unit.cooldowns[index] = interval
				if (_rng.randf() <= _scn.hit_rate * uptime):
					hits.append([null, damage if !unit.ally else damage, unit.ally])
					_log_shot(unit.x, unit.ally, unit.profile.id, _distance if unit.ally else 0.0, "base", damage, false)
	_turret_fire(hits)
	for hit : Array in hits:
		_apply_hit(hit)
	_sweep()

func _log_shot(from_x : float, from_ally : bool, shooter : String, to_x : float, target : String, damage : float, target_air : bool) -> void:
	_shots.append({"t": _t, "fx": from_x, "ally": from_ally, "shooter": shooter, "tx": to_x, "target": target, "dmg": damage, "air": target_air})

func _prune_shots() -> void:
	while (!_shots.is_empty() and _t - float(_shots[0]["t"]) > 0.6):
		_shots.pop_front()

func _turret_fire(hits : Array[Array]) -> void:
	if (_turrets <= 0 or _enemy_hp <= 0.0):
		return
	var base_x : float = _distance
	for index : int in range(_turrets):
		_turret_cd[index] -= DT
		if (_turret_cd[index] > 0.0):
			continue
		var best : SimUnit = null
		var best_distance : float = INF
		for unit : SimUnit in _units:
			if (!unit.ally or !unit.alive or unit.submerged):
				continue
			var distance : float = absf(unit.x - base_x)
			if (distance <= float(_turret_gun["range"]) and distance < best_distance):
				best = unit
				best_distance = distance
		if (best == null):
			continue
		_turret_cd[index] = float(_turret_gun["interval"])
		if (_rng.randf() <= _scn.hit_rate):
			hits.append([best, float(_turret_gun["damage"])])
			_log_shot(base_x, false, "base_turret", best.x, best.profile.id, float(_turret_gun["damage"]), best.profile.is_air)

func _apply_hit(hit : Array) -> void:
	var target : Variant = hit[0]
	if (target == null):
		if (bool(hit[2])):
			_enemy_hp -= float(hit[1])
		else:
			_ally_hp -= float(hit[1])
		return
	var unit : SimUnit = target
	if (unit.alive):
		unit.hp -= float(hit[1])

func _sweep() -> void:
	var survivors : Array[SimUnit] = []
	for unit : SimUnit in _units:
		if (unit.hp > 0.0):
			survivors.append(unit)
			continue
		unit.alive = false
		_on_death(unit)
	_units = survivors

func _on_death(unit : SimUnit) -> void:
	if (unit.ally):
		if (unit.escort and _scn.objective == RunData.Objective.ESCORT):
			_finish(false, "escort_lost")
		return
	_kills += 1
	if (unit.boss):
		_boss_down = true
		if (_scn.objective == RunData.Objective.SHOOT_DOWN_BOMBER and unit.profile.id == "boss_heavy_bomber"):
			_finish(true, "boss_down")
		elif (_scn.objective == RunData.Objective.DEFEAT_BOSS and unit.profile.id == "boss_dreadnought"):
			_finish(true, "boss_down")
		return
	if (unit.profile.can_submerge):
		_hunted += 1
	var raw : float = _scn.progress.modify(Enums.UpgradeTarget.BASE, &"kill_screw", float(unit.profile.price) / 3.0)
	_screws += floorf(raw * _kill_slack())

func _kill_slack() -> float:
	var reference : float = 0.0
	for unit : BalanceUnit in _loadout:
		reference = maxf(reference, float(unit.price))
	if (reference <= 0.0):
		return 1.0
	return clampf(1.0 - _screws / reference, 0.0, 1.0)

func _sub_los(gun_type : int) -> float:
	return 1.0 if gun_type >= 0 else 1.0

func _gun_can_hit(gun : Dictionary, target : SimUnit) -> bool:
	if (target.submerged):
		return bool(gun["sub"])
	if (target.profile.is_air):
		return bool(gun["air"])
	return bool(gun["surface"])

func _find_target(unit : SimUnit) -> SimUnit:
	var best : SimUnit = null
	var best_distance : float = INF
	for other : SimUnit in _units:
		if (other.ally == unit.ally or !other.alive):
			continue
		var distance : float = absf(other.x - unit.x)
		if (distance > unit.radar or distance >= best_distance):
			continue
		var reachable : bool = false
		for gun : Dictionary in unit.profile.guns:
			if (_gun_can_hit(gun, other) and distance <= float(gun["range"])):
				reachable = true
		if (reachable):
			best = other
			best_distance = distance
	return best

func _speed_factor(unit : SimUnit) -> float:
	if (unit.profile.id == "boss_dreadnought"):
		return SPEED_BOSS_NAVAL
	if (unit.profile.is_air):
		return SPEED_AIR
	if (unit.profile.can_submerge):
		return SPEED_SUB
	return SPEED_NAVAL

func _base_distance(unit : SimUnit) -> float:
	var base_x : float = _distance if unit.ally else 0.0
	return maxf(absf(base_x - unit.x) - BASE_HALF_WIDTH, 0.0)

func _base_in_reach(unit : SimUnit) -> bool:
	var distance : float = _base_distance(unit)
	if (distance > unit.radar):
		return false
	for gun : Dictionary in unit.profile.guns:
		if (bool(gun["surface"]) and distance <= float(gun["range"])):
			return true
	return false

func _count_enemies() -> int:
	var count : int = 0
	for unit : SimUnit in _units:
		if (!unit.ally and unit.alive):
			count += 1
	return count

func _objective_tick() -> void:
	if (_done):
		return
	if (_ally_hp <= 0.0):
		_finish(false, "base_destroyed")
		return
	if (_enemy_hp <= 0.0):
		_finish(true, "enemy_base")
		return
	match _scn.objective:
		RunData.Objective.DEFEND:
			var beacon : float = _distance * 0.5
			var ally_inside : bool = false
			var enemy_inside : bool = false
			for unit : SimUnit in _units:
				if (unit.alive and absf(unit.x - beacon) < RunData.DEFEND_RADIUS):
					if (unit.ally):
						ally_inside = true
					else:
						enemy_inside = true
			_defend_left = maxf(_defend_left - DT, 0.0)
			if (ally_inside and enemy_inside):
				_contested_time += DT
			elif (ally_inside):
				_ally_hold += DT
			elif (enemy_inside):
				_enemy_hold += DT
			if (_ally_hold >= _defend_target):
				_finish(true, "held")
			elif (_enemy_hold >= _defend_target):
				_finish(false, "enemy_held")
			elif (_defend_left <= 0.0):
				_finish(_ally_hold > _enemy_hold, "timeout")
		RunData.Objective.ESCORT:
			if (_escort_unit and _escort_unit.alive):
				var progress : float = clampf((_escort_unit.x - START_OFFSET) / maxf(_distance - 2.0 * START_OFFSET, 1.0), 0.0, 1.0)
				if (progress >= RunData.ESCORT_GOAL):
					_finish(true, "escorted")
		RunData.Objective.HUNT_SUBMARINE:
			if (_hunted >= RunData.HUNT_TARGET):
				_finish(true, "hunted")
	if (_time_limit > 0.0 and _t >= _time_limit and !_done):
		_finish(false, "timeout")

func _director_tick() -> void:
	_director_clock += DT
	if (_director_clock < RunData.DIRECTOR_SAMPLE_SECONDS):
		return
	var step : float = _director_clock
	_director_clock = 0.0
	var allies : int = 0
	var enemies : int = 0
	for unit : SimUnit in _units:
		if (unit.ally and !unit.escort):
			allies += 1
		elif (!unit.ally):
			enemies += 1
	_director.update(step, allies, enemies, clampf(_ally_hp / maxf(_ally_max, 1.0), 0.0, 1.0),
			clampf(_enemy_hp / maxf(_enemy_max, 1.0), 0.0, 1.0))

func _sample() -> void:
	var enemies : int = 0
	var by_kind : Dictionary = {"air": 0, "sub": 0, "surface": 0}
	for unit : SimUnit in _units:
		if (unit.ally):
			continue
		enemies += 1
		var kind : String = "surface"
		if (unit.profile.can_submerge):
			kind = "sub"
		elif (unit.profile.is_air):
			kind = "air"
		by_kind[kind] = int(by_kind[kind]) + 1
	for kind : String in by_kind:
		_peak_by_kind[kind] = maxi(int(_peak_by_kind.get(kind, 0)), int(by_kind[kind]))
	_peak_enemies = maxi(_peak_enemies, enemies)
	_enemy_sum += float(enemies)
	_samples += 1

func _finish(success : bool, reason : String) -> void:
	if (_done):
		return
	_done = true
	_won = success
	_reason = reason

func _result() -> Dictionary:
	return {
		"won": _won,
		"reason": _reason,
		"time": _t,
		"ally_hp": maxf(_ally_hp, 0.0) / maxf(_ally_max, 1.0),
		"enemy_hp": maxf(_enemy_hp, 0.0) / maxf(_enemy_max, 1.0),
		"peak_enemies": _peak_enemies,
		"peak_by_kind": _peak_by_kind,
		"avg_enemies": _enemy_sum / maxf(float(_samples), 1.0),
		"enemy_spawned": _enemy_spawned,
		"enemy_spawned_by": _enemy_spawned_by,
		"ally_spawned": _ally_spawned,
		"contested": _contested_time,
		"hunted": _hunted,
		"kills": _kills,
		"screws_spent": _screws_spent,
		"loadout": _loadout.map(func(unit : BalanceUnit) -> String: return unit.id),
	}
