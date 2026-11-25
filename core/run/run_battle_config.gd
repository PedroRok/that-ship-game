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

static func boss_for(entry : Dictionary) -> BoatStats:
	match int(entry["objective"]):
		RunData.Objective.SHOOT_DOWN_BOMBER:
			return load(BOATS_DIR + "boss_heavy_bomber.tres") as BoatStats
		RunData.Objective.DEFEAT_BOSS:
			return load(BOATS_DIR + "boss_dreadnought.tres") as BoatStats
	return null

static func extra_boss() -> BoatStats:
	return load(BOATS_DIR + "boss_dreadnought.tres") as BoatStats

static func build_table(run : RunState, entry : Dictionary) -> RunWaveTable:
	var table : RunWaveTable = RunWaveTable.new()
	var floor_index : int = clampi(int(entry["col"]), 0, RunData.ENEMY_SPAWN_INTERVAL.size() - 1)
	var health : float = RunData.ENEMY_HEALTH_MULT[floor_index]
	if (int(entry["type"]) == RunData.NodeType.ELITE):
		health *= RunData.ELITE_HEALTH_MULT
	health = run.modify(RunData.T_RUN, &"enemy_health", health)
	table.base_health_mult = health
	table.base_interval = RunData.ENEMY_SPAWN_INTERVAL[floor_index]
	table.pool = pool_for(entry)
	table.tier = tier_for(entry)
	table.boss = boss_for(entry)
	table.extra_boss = extra_boss() if run.modify(RunData.T_RUN, &"extra_boss", 0.0) >= 1.0 else null
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
	stats.health = 36.0
	stats.price = 0
	return stats
