class_name RunBattleConfig
extends RefCounted

const WAVE_TABLE : WaveTable = preload("res://core/resources/waves/wave_table.tres")
const BOATS_DIR : String = "res://core/resources/boats/"

const FLOOR_POOLS : Array[Array] = [
	["mini", "small", "torpedo"],
	["medium", "flak", "plane", "interceptor", "heli_scout", "sub_scout"],
	["destroyer", "submarine", "bomber", "frigate", "missile_plane", "heli_heavy", "sub_hunter"],
	["tank", "cruiser", "twin_bomber", "sub_sam"],
]

static func capability_warning(objective : int) -> String:
	if (objective == RunData.Objective.HUNT_SUBMARINE and anti_sub_count() == 0):
		return "run.warn_no_anti_sub"
	if (objective == RunData.Objective.SHOOT_DOWN_BOMBER and !_loadout_reaches_bomber()):
		return "run.warn_no_anti_air"
	return ""

static func _loadout_reaches_bomber() -> bool:
	for stats : EntityStats in Global.player_stats.loadout_entities():
		if (RunData.ANTI_BOMBER_UNITS.has(stats.name)):
			return true
	return false

static func anti_sub_count() -> int:
	var count : int = 0
	for stats : EntityStats in Global.player_stats.loadout_entities():
		var index : int = 0
		for slot : GunSlot in stats.gun_slots:
			var gun_type : int = Global.gun_type_for(stats.name, index, slot)
			index += 1
			if (gun_type < 0):
				continue
			var scene : PackedScene = Enums.gun_scene(gun_type)
			if (scene == null):
				continue
			var gun : Gun = scene.instantiate() as Gun
			var hits : bool = gun != null and gun.hits_submerged
			if (gun):
				gun.free()
			if (hits):
				count += 1
				break
	return count

static func hunt_sub_level() -> int:
	var count : int = anti_sub_count()
	var level : int = 0
	for step : int in RunData.HUNT_ANTI_SUB_STEPS:
		if (count >= step):
			level += 1
	return level

static func _raise_subs(roster : Array[BoatStats], floor_index : int, level : int, rng : RandomNumberGenerator) -> void:
	var wanted : int = 0
	for index : int in range(roster.size() - 1, -1, -1):
		if (roster[index].can_submerge):
			roster.remove_at(index)
			wanted += 1
	var names : Array = RunData.HUNT_SUB_LEVELS[floor_index][level - 1]
	var tier : Array[BoatStats] = []
	for item : Variant in Global.CATALOG.units:
		var unit : BoatStats = item
		if (names.has(unit.name)):
			tier.append(unit)
	for _index : int in range(clampi(wanted, 1, tier.size())):
		roster.append(tier.pop_at(rng.randi_range(0, tier.size() - 1)))

static func floor_of(entry : Dictionary) -> int:
	return clampi(int(entry["col"]), 0, RunData.COLUMNS - 1)

static func base_tiers() -> Array[BaseTier]:
	var tiers : Array[BaseTier] = []
	for item : Variant in WAVE_TABLE.waves:
		var wave : WaveData = item
		if (wave.base_tier and !tiers.has(wave.base_tier)):
			tiers.append(wave.base_tier)
	return tiers

static func tier_for(entry : Dictionary) -> BaseTier:
	var tiers : Array[BaseTier] = base_tiers()
	return tiers[clampi(floor_of(entry), 0, tiers.size() - 1)]

static func pool_for(entry : Dictionary) -> Array[BoatStats]:
	var names : Array[String] = []
	for floor_index : int in range(floor_of(entry) + 1):
		for unit_name : String in FLOOR_POOLS[floor_index]:
			names.append(unit_name)
	var objective : int = int(entry["objective"])
	if (objective == RunData.Objective.HUNT_SUBMARINE and !names.has("submarine")):
		names.append("submarine")
	var pool : Array[BoatStats] = []
	for item : Variant in Global.CATALOG.units:
		var unit : BoatStats = item
		if (names.has(unit.name) and !unit.is_boss):
			pool.append(unit)
	return pool

static func player_ship_count() -> int:
	return Global.player_stats.loadout_entities().size()

static func roster_for(entry : Dictionary, player_count : int, seed_value : int) -> Array[BoatStats]:
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool : Array[BoatStats] = pool_for(entry)
	var wanted : int = mini(maxi(player_count, 3) + rng.randi_range(0, RunData.ROSTER_EXTRA_MAX), RunData.ROSTER_MAX)
	var objective : int = int(entry["objective"])
	var roster : Array[BoatStats] = []
	var remaining : Array[BoatStats] = pool.duplicate()
	remaining.sort_custom(func(a : BoatStats, b : BoatStats) -> bool: return a.price < b.price)
	if (!remaining.is_empty()):
		roster.append(remaining.pop_front())
	if (objective == RunData.Objective.HUNT_SUBMARINE):
		for unit : BoatStats in remaining:
			if (unit.can_submerge):
				roster.append(unit)
				remaining.erase(unit)
				break
	while (roster.size() < wanted and !remaining.is_empty()):
		roster.append(remaining.pop_at(rng.randi_range(0, remaining.size() - 1)))
	if (roster.size() < maxi(player_count, 3)):
		var extra : Array[BoatStats] = []
		for floor_index : int in range(floor_of(entry) + 1, FLOOR_POOLS.size()):
			var names : Array = FLOOR_POOLS[floor_index]
			var tier : Array[BoatStats] = []
			for item : Variant in Global.CATALOG.units:
				var unit : BoatStats = item
				if (names.has(unit.name) and !unit.is_boss and !roster.has(unit)):
					tier.append(unit)
			tier.sort_custom(func(a : BoatStats, b : BoatStats) -> bool: return a.price < b.price)
			extra.append_array(tier)
		while (roster.size() < maxi(player_count, 3) and !extra.is_empty()):
			roster.append(extra.pop_front())
	if (objective == RunData.Objective.HUNT_SUBMARINE):
		var level : int = hunt_sub_level()
		if (level > 0):
			_raise_subs(roster, floor_of(entry), level, rng)
	return roster

static func boss_for(entry : Dictionary) -> BoatStats:
	match int(entry["objective"]):
		RunData.Objective.SHOOT_DOWN_BOMBER:
			return load(BOATS_DIR + "boss_heavy_bomber.tres") as BoatStats
		RunData.Objective.DEFEAT_BOSS:
			return load(BOATS_DIR + "boss_dreadnought.tres") as BoatStats
	return null

static func extra_boss(objective : int = -1) -> BoatStats:
	var file : String = "boss_heavy_bomber.tres" if objective == RunData.Objective.SHOOT_DOWN_BOMBER else "boss_dreadnought.tres"
	return load(BOATS_DIR + file) as BoatStats

static func build_table(run : RunState, entry : Dictionary) -> RunWaveTable:
	var table : RunWaveTable = RunWaveTable.new()
	var floor_index : int = clampi(int(entry["col"]), 0, RunData.ENEMY_HEALTH_MULT.size() - 1)
	var health : float = RunData.ENEMY_HEALTH_MULT[floor_index]
	if (int(entry["type"]) == RunData.NodeType.ELITE):
		health *= RunData.ELITE_HEALTH_MULT
	health = run.modify(RunData.T_RUN, &"enemy_health", health)
	table.base_health_mult = health
	table.boss_risk_mult = run.modify(RunData.T_RUN, &"enemy_health", 1.0)
	table.pool = roster_for(entry, player_ship_count(), run.seed_value + int(entry.get("id", run.pending_node)))
	table.tier = tier_for(entry)
	table.boss = boss_for(entry)
	table.extra_boss = extra_boss(int(entry["objective"])) if run.modify(RunData.T_RUN, &"extra_boss", 0.0) >= 1.0 else null
	table.wave_duration = RunData.WAVE_DURATION
	return table

static func expected_enemies(entry : Dictionary) -> Array[Dictionary]:
	var result : Array[Dictionary] = []
	var objective : int = int(entry["objective"])
	var pool : Array[BoatStats] = pool_for(entry)
	var names : Array[String] = []
	var has_sub : bool = false
	var has_air : bool = false
	for unit : BoatStats in pool:
		names.append(unit.name)
		has_sub = has_sub or unit.can_submerge
		has_air = has_air or unit is AirPlaneState
	if (objective == RunData.Objective.ESCORT):
		result.append({"key": "escort", "label": "run.allied_escort"})
	if (objective == RunData.Objective.DEFEAT_BOSS):
		result.append({"key": "boss", "label": "run.dreadnought"})
	if (objective == RunData.Objective.SHOOT_DOWN_BOMBER):
		result.append({"key": "bomber", "label": "run.heavy_bomber"})
	if (names.has("destroyer") or names.has("cruiser") or names.has("frigate") or names.has("tank")):
		result.append({"key": "destroyer", "label": "run.warships"})
	elif (names.has("medium") or names.has("flak") or names.has("torpedo") or names.has("small") or names.has("mini")):
		result.append({"key": "destroyer", "label": "run.patrol_boats"})
	if (has_sub):
		result.append({"key": "submarine", "label": "run.submarine"})
	if has_air and objective != RunData.Objective.SHOOT_DOWN_BOMBER:
		result.append({"key": "bomber", "label": "run.bomber"})
	while (result.size() > 3):
		result.pop_back()
	return result

static func silhouette(key : String) -> Texture2D:
	return load("res://assets/game/entities/silhouette_%s_v01.png" % key) as Texture2D

static func escort_stats() -> BoatStats:
	var stats : BoatStats = (load(BOATS_DIR + "tank_boat.tres") as BoatStats).duplicate()
	stats.name = "escort"
	stats.health = RunData.ESCORT_HEALTH
	stats.speed = RunData.ESCORT_SPEED
	stats.gun_slots = [] as Array[GunSlot]
	stats.price = 0
	return stats
