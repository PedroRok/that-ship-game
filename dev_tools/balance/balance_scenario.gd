class_name BalanceScenario
extends RefCounted

enum Policy { RANDOM, COUNTER, CHEAPEST }

var objective : int = RunData.Objective.DESTROY_BASE
var floor_index : int = 0
var elite : bool = false
var gear_budget : int = 0
var coin_budget : int = 0
var policy : Policy = Policy.COUNTER
var seed_value : int = 1
var enemy_health_mult : float = 1.0
var time_mult : float = 1.0
var distance_t : float = 0.5
var ally_hp_fraction : float = 1.0
var hit_rate : float = 0.8
var spawn_cap : int = 0
var extra_boss : bool = false
var progress : BalanceProgress

func entry() -> Dictionary:
	return {
		"col": floor_index,
		"objective": objective,
		"type": RunData.NodeType.ELITE if elite else RunData.NodeType.BATTLE,
	}

func label() -> String:
	return "%s f%d%s" % [RunData.OBJECTIVES[objective]["icon"], floor_index, " elite" if elite else ""]
