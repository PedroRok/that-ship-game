extends RefCounted

const NAMES : Array[String] = ["current", "blind", "waves", "adaptive", "tactician", "director"]

static func make(variant : String) -> EnemyCommander:
	match variant:
		"blind":
			return Blind.new()
		"waves":
			return Waves.new()
		"adaptive":
			return Adaptive.new()
		"tactician":
			return Tactician.new()
		"director":
			return Director.new()
	return EnemyCommander.new()

class Blind extends EnemyCommander:
	func sample(delta : float, context : BattleContext, ally_x : float, enemy_x : float, enemy_base_fraction : float) -> void:
		super.sample(delta, context, ally_x, enemy_x, enemy_base_fraction)
		counter_share = 0.0

class Waves extends EnemyCommander:
	const RELEASE_BANK : float = 32.0
	const MAX_HOLD : float = 28.0

	var releasing : bool = false
	var held : float = 0.0

	func tick(delta : float) -> void:
		if (releasing or alert >= 2 or base == null or !base.pending_bosses.is_empty() or opening_strike and opening_unit == ""):
			super.tick(delta)
			if (bank < 5.0):
				releasing = false
				held = 0.0
			return
		bank = minf(bank + base_rate * rate_mult * delta, RunData.SUPPLY_MAX_BANK)
		held += delta
		if (bank >= RELEASE_BANK or held >= MAX_HOLD):
			releasing = true

class Adaptive extends EnemyCommander:
	const MIN_BATTLE : float = 90.0
	const DEFENSE_STEPS : Array[float] = [0.66, 0.33]
	const DEFENSE_BANK : float = 24.0

	var ally_base : Base
	var ally_max : float = 1.0
	var clock : float = 0.0
	var advantage : float = 0.0
	var defense_used : int = 0

	func tick(delta : float) -> void:
		clock += delta
		super.tick(delta)

	func sample(delta : float, context : BattleContext, ally_x : float, enemy_x : float, enemy_base_fraction : float) -> void:
		super.sample(delta, context, ally_x, enemy_x, enemy_base_fraction)
		apply_balance(delta, enemy_base_fraction)

	func ally_fraction() -> float:
		if (ally_base == null or !is_instance_valid(ally_base)):
			return 1.0
		return clampf(ally_base.health_component.health / ally_max, 0.0, 1.0)

	func apply_balance(delta : float, enemy_base_fraction : float) -> void:
		var total : float = field_value + enemy_value
		var army : float = (field_value - enemy_value) / total if total > 0.0 else 0.0
		var lane : float = front * 2.0 - 1.0 if allies > 0 else -0.5
		var now : float = clampf(0.3 * lane + 0.4 * army + 1.0 * (ally_fraction() - enemy_base_fraction), -1.0, 1.0)
		advantage = lerpf(advantage, now, clampf(delta / 6.0, 0.0, 1.0))
		counter_share = 0.2 if advantage < -0.2 else (0.55 if advantage > 0.2 else 0.4)
		rate_mult = clampf(1.1 + 0.8 * advantage, 0.6, 1.7)
		if (clock < MIN_BATTLE):
			if (ally_fraction() < 0.7 or advantage < -0.3):
				rate_mult *= 0.6
			if (enemy_base_fraction < 0.8):
				rate_mult *= 1.5
		if (defense_used < DEFENSE_STEPS.size() and enemy_base_fraction <= DEFENSE_STEPS[defense_used]):
			defense_used += 1
			bank = minf(bank + DEFENSE_BANK, RunData.SUPPLY_MAX_BANK)

class Tactician extends Adaptive:
	const DOCTRINES : Array[String] = ["counter", "swarm", "heavy", "air", "sub"]
	const REVIEW : float = 20.0

	var doctrine : String = "counter"
	var doctrine_switches : int = 0
	var review_clock : float = 0.0
	var memory : Dictionary = {}
	var last_hp : float = 1.0
	var last_front : float = 0.0
	var last_army : float = 0.0

	func sample(delta : float, context : BattleContext, ally_x : float, enemy_x : float, enemy_base_fraction : float) -> void:
		var kept_bank : float = bank
		var kept_used : int = defense_used
		super.sample(delta, context, ally_x, enemy_x, enemy_base_fraction)
		bank = kept_bank
		defense_used = kept_used
		rate_mult = RunData.ALERT_SUPPLY_MULT[alert]
		counter_share = RunData.ALERT_COUNTER_SHARE[alert]
		review_doctrine(delta)

	func review_doctrine(delta : float) -> void:
		review_clock += delta
		if (review_clock < REVIEW):
			return
		review_clock = 0.0
		var total : float = field_value + enemy_value
		var army : float = (enemy_value - field_value) / total if total > 0.0 else 0.0
		var score : float = (last_hp - ally_fraction()) * 3.0 + (last_front - front) * 0.5 + (army - last_army) * 0.3
		last_hp = ally_fraction()
		last_front = front
		last_army = army
		memory[doctrine] = score
		if (score > 0.05):
			return
		var best : String = doctrine
		var best_value : float = -INF
		for option : String in DOCTRINES:
			if (option == doctrine or filtered(option, _pool()).is_empty()):
				continue
			var value : float = float(memory.get(option, 0.1)) + _rng.randf() * 0.15
			if (value > best_value):
				best = option
				best_value = value
		if (best != doctrine):
			doctrine = best
			doctrine_switches += 1
			_planned = null

	func filtered(option : String, pool : Array[BoatStats]) -> Array[BoatStats]:
		var result : Array[BoatStats] = []
		for unit : BoatStats in pool:
			var air : bool = unit is AirPlaneState
			if ((option == "swarm" and unit.price <= 9) or (option == "heavy" and unit.price >= 15)
					or (option == "air" and air) or (option == "sub" and unit.can_submerge)):
				result.append(unit)
		return result

	func _pick() -> BoatStats:
		if (doctrine == "counter"):
			if (!_targets.is_empty() and _rng.randf() < 0.75):
				var counter : BoatStats = _pick_counter(_pool())
				if (counter):
					return counter
			return super._pick()
		if (objective == RunData.Objective.HUNT_SUBMARINE and _live_subs == 0):
			return super._pick()
		var options : Array[BoatStats] = filtered(doctrine, _pool())
		if (options.is_empty() or _rng.randf() < 0.25):
			return super._pick()
		return options[_rng.randi() % options.size()]

class Director extends Tactician:
	func sample(delta : float, context : BattleContext, ally_x : float, enemy_x : float, enemy_base_fraction : float) -> void:
		super.sample(delta, context, ally_x, enemy_x, enemy_base_fraction)
		apply_balance(delta, enemy_base_fraction)
