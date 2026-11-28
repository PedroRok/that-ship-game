class_name BalanceFleet
extends RefCounted

const START_SCREWS : int = 10

static var _profiles : Dictionary = {}

static func profile_of(stats : BoatStats) -> BalanceUnit:
	var key : String = stats.name
	if (!_profiles.has(key)):
		_profiles[key] = BalanceUnit.from_stats(stats)
	return _profiles[key]

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
