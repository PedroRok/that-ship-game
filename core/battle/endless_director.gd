class_name EndlessDirector
extends Node

signal unit_unlocked(unit : BoatStats)

var game_round : GameRound
var enemy_base : AutoBase
var ships_manager : ShipManager
var commander : EnemyCommander = EnemyCommander.new()
var level : int = 1
var elapsed : float = 0.0
var deployed_value : int = 0
var roster : Array[BoatStats] = []

var _sample_clock : float = 0.0
var _enemy_hp_max : float = 1.0

func setup(round_node : GameRound, seed_value : int) -> void:
	game_round = round_node
	enemy_base = round_node.enemy_base as AutoBase
	ships_manager = round_node.get_node("ShipsManager") as ShipManager
	commander.setup(enemy_base, RunData.Objective.DESTROY_BASE, supply_for(1), seed_value)
	ships_manager.child_entered_tree.connect(_on_unit_added)
	_unlock_tiers()
	enemy_base.roster_override = roster
	_apply_level()

static func level_for(seconds : float, value : int) -> int:
	return 1 + int(seconds / RunData.ENDLESS_LEVEL_SECONDS + float(value) / RunData.ENDLESS_LEVEL_VALUE)

static func supply_for(for_level : int) -> float:
	return minf(RunData.ENDLESS_SUPPLY_START + RunData.ENDLESS_SUPPLY_STEP * (for_level - 1), RunData.ENDLESS_SUPPLY_MAX)

static func tier_count(for_level : int) -> int:
	var count : int = 0
	for needed : int in RunData.ENDLESS_TIER_LEVELS:
		if (for_level >= needed):
			count += 1
	return clampi(count, 1, RunBattleConfig.FLOOR_POOLS.size())

func on_wave(wave : WaveData) -> void:
	if (wave.base_tier):
		_enemy_hp_max = maxf(enemy_base.health_component.health, 1.0)

func _process(delta : float) -> void:
	if (game_round.game_ended):
		return
	elapsed += delta
	commander.tick(delta)
	_sample_clock += delta
	if (_sample_clock < RunData.COMMANDER_SAMPLE_SECONDS):
		return
	var step : float = _sample_clock
	_sample_clock = 0.0
	var context : BattleContext = BattleContext.of(self)
	if (context):
		commander.sample(step, context, game_round.ally_base.global_position.x, enemy_base.global_position.x,
				clampf(enemy_base.health_component.health / _enemy_hp_max, 0.0, 1.0))
	var wanted : int = level_for(elapsed, deployed_value)
	while (level < wanted):
		level_up()

func level_up() -> void:
	level += 1
	var fresh : Array[BoatStats] = _unlock_tiers()
	var counter : BoatStats = _unlock_counter()
	if (counter):
		fresh.append(counter)
	_apply_level()
	if (!fresh.is_empty()):
		unit_unlocked.emit(fresh.back())

func _apply_level() -> void:
	commander.base_rate = supply_for(level)
	commander.counter_bonus = minf(RunData.ENDLESS_COUNTER_STEP * (level - 1), RunData.ENDLESS_COUNTER_BONUS_MAX)
	enemy_base.live_cap = mini(RunData.ENDLESS_LIVE_CAP_START + RunData.ENDLESS_LIVE_CAP_STEP * (level - 1), RunData.ENDLESS_LIVE_CAP_MAX)
	enemy_base.ships = roster
	enemy_base.show_docks_for(roster)

func _unlock_tiers() -> Array[BoatStats]:
	var added : Array[BoatStats] = []
	for tier : int in range(tier_count(level)):
		for unit : BoatStats in _tier_units(tier):
			if (!roster.has(unit)):
				roster.append(unit)
				added.append(unit)
	return added

func _unlock_counter() -> BoatStats:
	var targets : Array[Dictionary] = _player_targets()
	if (targets.is_empty()):
		return null
	var best : BoatStats = null
	var best_score : float = 0.0
	var next_tier : int = tier_count(level)
	for tier : int in range(next_tier, mini(next_tier + RunData.ENDLESS_COUNTER_REACH, RunBattleConfig.FLOOR_POOLS.size())):
		for unit : BoatStats in _tier_units(tier):
			if (roster.has(unit)):
				continue
			var score : float = commander.counter_score(unit, targets)
			if (score > best_score):
				best = unit
				best_score = score
	if (best):
		roster.append(best)
	return best

func _tier_units(tier : int) -> Array[BoatStats]:
	var names : Array = RunBattleConfig.FLOOR_POOLS[tier]
	var units : Array[BoatStats] = []
	for item : Variant in Global.CATALOG.units:
		var unit : BoatStats = item
		if (names.has(unit.name) and !unit.is_boss):
			units.append(unit)
	return units

func _player_targets() -> Array[Dictionary]:
	var targets : Array[Dictionary] = []
	var context : BattleContext = BattleContext.of(self)
	if (context == null):
		return targets
	for unit : Entity in context.entities:
		if (!is_instance_valid(unit) or unit.destroyed or unit.team_stats.team_id != 1):
			continue
		var boat : BoatStats = unit.entity_stats as BoatStats
		if (boat):
			targets.append({"class": int(boat.unit_class), "weight": float(boat.price),
				"air": unit.entity_stats is AirPlaneState, "sub": boat.can_submerge})
	return targets

func _on_unit_added(child : Node) -> void:
	var unit : Entity = child as Entity
	if (unit and unit.entity_stats and unit.team_stats and unit.team_stats.team_id == 1):
		deployed_value += unit.entity_stats.price
