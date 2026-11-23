class_name UpgradeStats
extends Resource

@export_group("Identity")
@export
var id : StringName
@export
var name_key : String
@export
var description_key : String
@export
var icon : Texture2D

@export_group("Effect")
@export
var target : Enums.UpgradeTarget = Enums.UpgradeTarget.ENTITY
@export
var stat : StringName
@export
var op : Enums.UpgradeOp = Enums.UpgradeOp.ADD
@export
var value_per_level : float = 1.0
@export
var only_for : Array[String]

@export
var unlocks_gun : int = -1

@export_group("Cost")
@export
var max_level : int = 1
@export
var gear_cost : Array[int] = [10]
@export
var boss_coin_cost : Array[int] = []

@export_group("Tree")
@export
var requires : Array[UpgradeStats]
@export
var tree_position : Vector2


func gears_for_level(level : int) -> int:
	return _cost_at(gear_cost, level)

func boss_coins_for_level(level : int) -> int:
	return _cost_at(boss_coin_cost, level)

func apply(base_value : float, level : int) -> float:
	if (level <= 0):
		return base_value
	match op:
		Enums.UpgradeOp.MULTIPLY:
			return base_value * pow(1.0 + value_per_level, level)
		_:
			return base_value + value_per_level * level

func affects(entity_name : String) -> bool:
	return only_for.is_empty() or only_for.has(entity_name)

func _cost_at(costs : Array[int], level : int) -> int:
	if (costs.is_empty() or level < 1):
		return 0
	return costs[min(level - 1, costs.size() - 1)]
