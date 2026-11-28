class_name SfxCatalog
extends RefCounted

enum Family { AMBIENT, LAUNCH, LIGHT, HEAVY, TERMINAL }

const RANGES : Dictionary = {
	Family.AMBIENT: Vector3(240.0, 850.0, 1350.0),
	Family.LAUNCH: Vector3(320.0, 1000.0, 1700.0),
	Family.LIGHT: Vector3(350.0, 1150.0, 1900.0),
	Family.HEAVY: Vector3(460.0, 1500.0, 2450.0),
	Family.TERMINAL: Vector3(480.0, 1600.0, 2800.0),
}

const PATH : String = "res://assets/game/sounds/battle/%s/battle_%s_%s_%s.ogg"

const DUPLICATE_RADIUS : float = 40.0
const LARGE_SHIP_HEALTH : float = 28.0

const EVENTS : Dictionary = {
	&"bomb_explosion_hit": {"approved": ["d_r01"], "family": Family.HEAVY, "trim": -4.0, "priority": 4},
	&"bomb_explosion_water": {"approved": ["b_r01", "c_r01", "e_r01"], "family": Family.LIGHT, "trim": -5.0, "priority": 3},
	&"bomb_release": {"approved": ["d_r02"], "family": Family.LIGHT, "trim": -2.0, "priority": 2},
	&"depth_charge_explosion": {"approved": ["a_r02", "b_r03", "d_r03", "e_r03"], "family": Family.HEAVY, "trim": -4.0, "priority": 4, "gap": 0.045},
	&"depth_launcher_fire": {"approved": ["b_r02", "c_r02"], "family": Family.LIGHT, "trim": -4.0, "priority": 4},
	&"flak_burst": {"approved": ["c_r02", "d_r01"], "family": Family.LIGHT, "trim": -3.0, "priority": 2, "gap": 0.028},
	&"flare_release": {"approved": ["a_r02", "b_r02", "c_r02"], "family": Family.LIGHT, "trim": 0.0, "priority": 3},
	&"helicopter_destroyed": {"approved": ["a_r02", "b_r02"], "family": Family.HEAVY, "trim": -5.0, "priority": 6},
	&"helicopter_rotor": {"approved": ["b_r02", "d_r02"], "family": Family.AMBIENT, "trim": -12.0, "priority": 1, "loop": true},
	&"lightning_charge": {"approved": ["c_r01"], "family": Family.HEAVY, "trim": -4.0, "priority": 6},
	&"lightning_strike": {"approved": ["a_r03", "c_r01", "d_r03"], "family": Family.TERMINAL, "trim": -4.0, "priority": 8},
	&"missile_explosion": {"approved": ["b_r01", "d_r02"], "family": Family.HEAVY, "trim": -5.0, "priority": 5},
	&"missile_flight": {"approved": ["b_r03", "c_r03", "d_r03"], "family": Family.AMBIENT, "trim": -5.0, "priority": 2, "loop": true},
	&"plane_destroyed": {"approved": ["a_r02", "e_r01"], "family": Family.HEAVY, "trim": -5.0, "priority": 6},
	&"rotary_gun_burst": {"approved": ["a_r01", "b_r01", "c_r01"], "family": Family.LIGHT, "trim": -4.0, "priority": 4, "gap": 0.016},
	&"skill_bomb_explosion": {"approved": ["b_r03"], "family": Family.HEAVY, "trim": -4.0, "priority": 6},
	&"skill_bomb_whistle": {"approved": ["a_r03", "b_r03", "c_r03", "d_r01"], "family": Family.HEAVY, "trim": -3.0, "priority": 4},
	&"skill_flak_burst": {"approved": ["b_r01", "d_r02"], "family": Family.HEAVY, "trim": -3.0, "priority": 5},
	&"submarine_destroyed": {"approved": ["a_r02", "c_r01"], "family": Family.HEAVY, "trim": -4.0, "priority": 6},
	&"torpedo_surface": {"approved": ["a_r03", "e_r03"], "family": Family.AMBIENT, "trim": -5.0, "priority": 2, "loop": true},
	&"wreck_splash": {"approved": ["a_r03", "c_r01"], "family": Family.LIGHT, "trim": -5.0, "priority": 3},
	&"dock_build": {"takes": "abcdef", "family": Family.AMBIENT, "trim": -11.0, "priority": 1},
	&"dock_release": {"takes": "abc", "family": Family.LAUNCH, "trim": -9.0, "priority": 3},
	&"naval_launch": {"takes": "abc", "family": Family.LAUNCH, "trim": -15.0, "priority": 3},
	&"sub_launch": {"takes": "abc", "family": Family.LAUNCH, "trim": -15.0, "priority": 3},
	&"air_launch": {"takes": "abc", "family": Family.LAUNCH, "trim": -15.0, "priority": 3},
	&"light_cannon": {"takes": "abc", "revision": "v16", "family": Family.LIGHT, "trim": -9.0, "priority": 4, "gap": 0.03},
	&"heavy_cannon": {"takes": "abc", "family": Family.HEAVY, "trim": -6.0, "priority": 5},
	&"antiair_shot": {"takes": "abc", "revision": "v16", "family": Family.LIGHT, "trim": -10.0, "priority": 4, "gap": 0.03},
	&"torpedo_launch": {"takes": "abc", "family": Family.HEAVY, "trim": -7.0, "priority": 5},
	&"water_impact": {"takes": "abc", "family": Family.LIGHT, "trim": -5.0, "priority": 2, "gap": 0.08},
	&"hull_impact": {"takes": "abc", "family": Family.LIGHT, "trim": -4.0, "priority": 3, "gap": 0.05},
	&"ricochet": {"takes": "abc", "family": Family.LIGHT, "trim": -5.0, "priority": 3, "gap": 0.05},
	&"small_ship_break": {"takes": "abc", "family": Family.HEAVY, "trim": -7.0, "priority": 6},
	&"large_ship_sink": {"takes": "abc", "family": Family.HEAVY, "trim": -5.0, "priority": 7},
	&"base_damage": {"stem": "hull_impact", "takes": "abc", "family": Family.LIGHT, "trim": -4.0, "priority": 3},
	&"base_break": {"takes": "abc", "family": Family.TERMINAL, "trim": -3.0, "priority": 10},
	&"naval_engine": {"takes": "abc", "family": Family.AMBIENT, "trim": -12.0, "priority": 1, "loop": true},
	&"sub_propeller": {"takes": "abc", "family": Family.AMBIENT, "trim": -11.0, "priority": 1, "loop": true},
	&"air_engine": {"takes": "abc", "family": Family.AMBIENT, "trim": -12.0, "priority": 1, "loop": true},
	&"sub_dock_fill": {"takes": "abc", "family": Family.AMBIENT, "trim": -8.0, "priority": 2},
	&"sub_dock_drain": {"takes": "abc", "family": Family.AMBIENT, "trim": -8.0, "priority": 2},
}

const LAUNCH_BY_DOCK : Dictionary = {
	BaseDock.Type.NAVAL: &"naval_launch",
	BaseDock.Type.AIR: &"air_launch",
	BaseDock.Type.SUB: &"sub_launch",
}

static var _streams : Dictionary = {}

static func has_event(event : StringName) -> bool:
	return EVENTS.has(event)

static func streams(event : StringName) -> Array[AudioStream]:
	if (_streams.has(event)):
		return _streams[event]
	var list : Array[AudioStream] = []
	var def : Dictionary = EVENTS[event]
	var stem : String = String(def.get("stem", event))
	var revision : String = String(def.get("revision", "v14"))
	var filenames : Array[String] = []
	if (def.has("approved")):
		for take : String in def["approved"]:
			filenames.append("res://assets/game/sounds/battle/%s/battle_%s_%s.ogg" % [stem, stem, take])
	else:
		for take : String in String(def["takes"]):
			filenames.append(PATH % [stem, stem, take, revision])
	for filename : String in filenames:
		var stream : AudioStream = load(filename) as AudioStream
		if (stream):
			if (is_loop(event) and stream is AudioStreamOggVorbis):
				(stream as AudioStreamOggVorbis).loop = true
			list.append(stream)
		else:
			push_error("Missing sound take %s" % filename)
	_streams[event] = list
	return list

static func range_of(event : StringName) -> Vector3:
	return RANGES[EVENTS[event]["family"]]

static func trim_of(event : StringName) -> float:
	return float(EVENTS[event]["trim"])

static func priority_of(event : StringName) -> int:
	return int(EVENTS[event]["priority"])

static func gap_of(event : StringName) -> float:
	return float(EVENTS[event].get("gap", 0.0))

static func is_loop(event : StringName) -> bool:
	return bool(EVENTS[event].get("loop", false))

static func launch_event(stats : EntityStats) -> StringName:
	if (!stats or stats.is_boss):
		return &""
	return LAUNCH_BY_DOCK[Base.dock_type_of(stats)]

static func destruction_event(stats : EntityStats) -> StringName:
	if (!stats):
		return &""
	if (stats is HelicopterStats):
		return &"helicopter_destroyed"
	if (stats is AirPlaneState):
		return &"plane_destroyed"
	var boat : BoatStats = stats as BoatStats
	if (!boat):
		return &""
	if (boat.can_submerge):
		return &"submarine_destroyed"
	if (boat.is_boss or (boat.unit_class == Enums.UnitClass.HEAVY and boat.health >= LARGE_SHIP_HEALTH)):
		return &"large_ship_sink"
	return &"small_ship_break"

static func engine_event(entity : Entity) -> StringName:
	if (entity is HelicopterEntity):
		return &"helicopter_rotor"
	if (entity is AirEntity):
		return &"air_engine"
	if (entity.is_submerged()):
		return &"sub_propeller"
	return &"naval_engine"
