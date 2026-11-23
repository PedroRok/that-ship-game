class_name ShopCatalog
extends Resource

@export
var units : Array[BoatStats]
@export
var upgrades : Array[UpgradeStats]
@export
var research : Array[UpgradeStats]

func all_upgrades() -> Array:
	return upgrades + research

func find_unit(unit_name : String) -> BoatStats:
	for unit : BoatStats in units:
		if (unit.name == unit_name):
			return unit
	return null

func upgrades_for(target : Enums.UpgradeTarget) -> Array[UpgradeStats]:
	var result : Array[UpgradeStats] = []
	for upgrade : UpgradeStats in upgrades:
		if (upgrade.target == target):
			result.append(upgrade)
	return result
