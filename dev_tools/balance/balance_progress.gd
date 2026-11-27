class_name BalanceProgress
extends RefCounted

const STARTERS : Array[String] = ["mini", "small"]
const UNIT_SHARE : float = 0.4

var gears_spent : int = 0
var coins_spent : int = 0
var levels : Dictionary = {}
var unlocked : Array[String] = []
var upgrades : Array[UpgradeStats] = []

static func build(catalog : ShopCatalog, gear_budget : int, coin_budget : int) -> BalanceProgress:
	var progress : BalanceProgress = BalanceProgress.new()
	for unit_name : String in STARTERS:
		progress.unlocked.append(unit_name)
	for item : Variant in catalog.all_upgrades():
		progress.upgrades.append(item as UpgradeStats)
	var unit_budget : int = int(float(gear_budget) * UNIT_SHARE)
	var units : Array[BoatStats] = []
	for item : Variant in catalog.units:
		units.append(item as BoatStats)
	units.sort_custom(func(a : BoatStats, b : BoatStats) -> bool: return a.unlock_cost < b.unlock_cost)
	var spent : int = 0
	for unit : BoatStats in units:
		if (progress.unlocked.has(unit.name) or unit.is_boss or unit.unlock_cost <= 0):
			continue
		if (spent + unit.unlock_cost > unit_budget):
			continue
		spent += unit.unlock_cost
		progress.unlocked.append(unit.name)
	progress.gears_spent = spent
	var remaining : int = gear_budget - spent
	var coins : int = coin_budget
	var bought : bool = true
	while (bought):
		bought = false
		var best : UpgradeStats = null
		var best_cost : int = 0
		for upgrade : UpgradeStats in progress.upgrades:
			var level : int = int(progress.levels.get(upgrade.id, 0))
			if (level >= upgrade.max_level or !progress._requirements_met(upgrade)):
				continue
			var cost : int = upgrade.gears_for_level(level + 1)
			var coin_cost : int = upgrade.boss_coins_for_level(level + 1)
			if (cost > remaining or coin_cost > coins):
				continue
			if (best == null or cost < best_cost):
				best = upgrade
				best_cost = cost
		if (best != null):
			progress.levels[best.id] = int(progress.levels.get(best.id, 0)) + 1
			remaining -= best_cost
			coins -= best.boss_coins_for_level(int(progress.levels[best.id]))
			progress.gears_spent += best_cost
			bought = true
	progress.coins_spent = coin_budget - coins
	return progress

func _requirements_met(upgrade : UpgradeStats) -> bool:
	for required : UpgradeStats in upgrade.requires:
		if (int(levels.get(required.id, 0)) < 1):
			return false
	return true

func modify(target : int, stat : StringName, base_value : float, entity_name : String = "") -> float:
	var value : float = base_value
	for upgrade : UpgradeStats in upgrades:
		if (int(upgrade.target) != target or upgrade.stat != stat):
			continue
		if (target == Enums.UpgradeTarget.ENTITY and !upgrade.affects(entity_name)):
			continue
		value = upgrade.apply(value, int(levels.get(upgrade.id, 0)))
	return value

func gun_unlocked(unit_name : String, gun_type : int) -> bool:
	for upgrade : UpgradeStats in upgrades:
		if (int(upgrade.target) == Enums.UpgradeTarget.WEAPON_UNLOCK and upgrade.unlocks_gun == gun_type \
				and upgrade.affects(unit_name) and int(levels.get(upgrade.id, 0)) > 0):
			return true
	return false
