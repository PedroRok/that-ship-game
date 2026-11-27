extends RefCounted

const DECIDE_SECONDS : float = 0.5
const REVIEW_SECONDS : float = 18.0
const SWITCH_SCORE : float = 0.04
const BUYS_PER_DECISION : int = 2
const CHEAP_PRICE : int = 9
const HEAVY_PRICE : int = 15
const BOMB_MIN_VALUE : float = 15.0
const BOOST_MIN_SCREWS : int = 16
const STYLES : Array[String] = ["counter", "swarm", "heavy", "air", "naval", "subs"]

const DEFAULTS : Dictionary = {"decide": 0.5, "review": 18.0, "switch": 0.04, "buys": 2.0, "patience": 1.5,
	"patience_front": 0.55, "urgent_share": 0.3, "noise": 0.6, "price_exp": 0.5, "health_exp": 0.5, "siege": 0.15,
	"counter_bias": 0.05, "bomb_value": 15.0, "boost_screws": 16.0, "anti_air": 1.0, "anti_sub": 1.0, "escort_air": 1.0, "use_bomb": 1.0, "use_boost": 1.0,
	"cancel": 0.0, "wave": 0.0, "queue_max": 99.0, "spread": 0.0}

var params : Dictionary = DEFAULTS.duplicate()
var weights : Dictionary = {}
var mode : String = "adaptive"
var style : String = "counter"
var switches : int = 0
var cancels : int = 0
var _wave_open : bool = false
var style_seconds : Dictionary = {}
var skills_used : Dictionary = {"bomb": 0, "boost": 0}

var _fleet : Array[BalanceUnit] = []
var _memory : Dictionary = {}
var _decide_clock : float = 0.0
var _review_clock : float = 0.0
var _last : Dictionary = {}
var _rng : RandomNumberGenerator = RandomNumberGenerator.new()

func setup(new_mode : String, fleet : Array[BalanceUnit], seed_value : int) -> void:
	mode = new_mode
	_fleet = fleet
	_rng.seed = seed_value
	if (mode == "adaptive"):
		var options : Array[String] = _available()
		style = options[_rng.randi() % options.size()]
	else:
		style = mode

func _available() -> Array[String]:
	var result : Array[String] = []
	for name_key : String in STYLES:
		if (!_units_of(name_key).is_empty()):
			result.append(name_key)
	return result

func _units_of(style_name : String) -> Array[BalanceUnit]:
	var result : Array[BalanceUnit] = []
	for unit : BalanceUnit in _fleet:
		var fits : bool = true
		match style_name:
			"swarm":
				fits = unit.price <= CHEAP_PRICE
			"heavy":
				fits = unit.price >= HEAVY_PRICE
			"air":
				fits = unit.is_air
			"naval":
				fits = !unit.is_air and !unit.can_submerge
			"subs":
				fits = unit.can_submerge
		if (fits):
			result.append(unit)
	return result

func step(delta : float, game : GameRound, view : Dictionary) -> void:
	style_seconds[style] = float(style_seconds.get(style, 0.0)) + delta
	_decide_clock += delta
	_review_clock += delta
	if (mode == "adaptive" and _review_clock >= float(params["review"])):
		_review_clock = 0.0
		_review(view)
	if (_last.is_empty()):
		_last = view.duplicate()
	if (_decide_clock < float(params["decide"])):
		return
	_decide_clock = 0.0
	var ui : GameUI = game.get_node_or_null("CanvasLayer/GameUI") as GameUI
	if (ui == null):
		return
	_use_skills(game, ui, view)
	if (float(params["cancel"]) > 0.0):
		_cancel_useless(ui, view)
	if (float(params["wave"]) > 0.0 and !_wave_ready(ui, view)):
		return
	for attempt : int in range(int(params["buys"])):
		if (!_buy(ui, view)):
			_wave_open = false
			return

func _wave_ready(ui : GameUI, view : Dictionary) -> bool:
	if (float(ui.screw_label.total_value) >= float(params["wave"]) or _urgent_need(view) != ""):
		_wave_open = true
	return _wave_open

func _cancel_useless(ui : GameUI, view : Dictionary) -> void:
	var need : String = _urgent_need(view)
	if (need == ""):
		return
	for dock_type : int in ui.base.queues:
		var waiting : Array = ui.base.queues[dock_type]
		for index : int in range(waiting.size() - 1, -1, -1):
			var queued : BoatStats = waiting[index] as BoatStats
			if (BalanceSim.profile_of(queued).hits(need)):
				continue
			var slot : int = index + (1 if (ui.base.constructors[dock_type] as ShipConstructor).is_building() else 0)
			var removed : BoatStats = ui.base.cancel_slot(dock_type as BaseDock.Type, slot)
			if (removed):
				ui.refund_entity(removed)
				cancels += 1

func _review(view : Dictionary) -> void:
	var score : float = (float(view["front"]) - float(_last["front"])) * 0.5 \
			+ (float(_last["enemy_hp"]) - float(view["enemy_hp"])) * 2.0 \
			- (float(_last["ally_hp"]) - float(view["ally_hp"])) * 2.0 \
			+ (_balance(view) - _balance(_last)) * 0.3 \
			+ (float(view["progress"]) - float(_last["progress"])) * 2.0
	_memory[style] = score if !_memory.has(style) else (float(_memory[style]) + score) * 0.5
	_last = view.duplicate()
	if (score > float(params["switch"])):
		return
	var best : String = style
	var best_value : float = -INF
	for option : String in _available():
		if (option == style):
			continue
		var value : float = float(_memory.get(option, 0.08)) + _rng.randf() * 0.1
		if (option == "counter"):
			value += float(params["counter_bias"])
		if (value > best_value):
			best = option
			best_value = value
	if (best != style):
		style = best
		switches += 1
	for key : String in _memory:
		_memory[key] = float(_memory[key]) * 0.8

func _balance(view : Dictionary) -> float:
	var total : float = float(view["ally_value"]) + float(view["enemy_value"])
	return (float(view["ally_value"]) - float(view["enemy_value"])) / total if total > 0.0 else 0.0

func _buy(ui : GameUI, view : Dictionary) -> bool:
	var screws : float = float(ui.screw_label.total_value)
	var pool : Array[BalanceUnit] = _units_of(style)
	if (mode == "adaptive"):
		var need : String = _urgent_need(view)
		if (need != ""):
			var answers : Array[BalanceUnit] = []
			for unit : BalanceUnit in _fleet:
				if (unit.hits(need)):
					answers.append(unit)
			if (!answers.is_empty()):
				pool = answers
	if (float(params["spread"]) > 0.0):
		var idle : Array[BalanceUnit] = []
		for unit : BalanceUnit in _fleet:
			if (ui.base.queue_used(Base.dock_type_of(unit.stats)) == 0 and float(unit.price) <= screws):
				idle.append(unit)
		if (!idle.is_empty()):
			pool = idle
	var best : BalanceUnit = null
	var best_score : float = 0.0
	var dream : BalanceUnit = null
	var dream_score : float = 0.0
	for unit : BalanceUnit in pool:
		if (!ui.base.queue_has_room(Base.dock_type_of(unit.stats))):
			continue
		if (ui.base.queue_used(Base.dock_type_of(unit.stats)) >= int(params["queue_max"])):
			continue
		if (unit.stats.air_hunter and float(view["enemy_air"]) <= 0.0):
			continue
		var noise : float = float(params["noise"])
		var score : float = _score(unit, view) * (1.0 - noise * 0.5 + _rng.randf() * noise)
		if (score > dream_score):
			dream = unit
			dream_score = score
		if (float(unit.price) <= screws and score > best_score):
			best = unit
			best_score = score
	if (dream != null and dream != best and float(dream.price) > screws):
		var patient : bool = style == "heavy" or dream_score > best_score * float(params["patience"])
		if (patient and float(view["front_enemy"]) < float(params["patience_front"])):
			return false
	if (best == null):
		return false
	var before : float = float(ui.screw_label.total_value)
	ui.spawn_entity(best.stats)
	return float(ui.screw_label.total_value) < before

func _urgent_need(view : Dictionary) -> String:
	var total : float = float(view["enemy_value"])
	if (total <= 0.0):
		return ""
	for kind : String in ["air", "sub"]:
		var share : float = float(view["enemy_" + kind]) / total
		if (share >= float(params["urgent_share"]) and float(view["answer_" + kind]) < float(view["enemy_" + kind])):
			return kind
	return ""

func _score(unit : BalanceUnit, view : Dictionary) -> float:
	var total : float = float(view["enemy_value"])
	var power : float = 0.0
	if (total <= 0.0):
		power = maxf(unit.dps("surface"), maxf(unit.dps("air"), unit.dps("sub")) * 0.5) + 0.05
	else:
		var classes : Dictionary = view["enemy_classes"]
		for key : Variant in classes:
			var entry : Dictionary = classes[key]
			var mult : float = Global.counter_multiplier(unit.unit_class, int(entry["class"]) as Enums.UnitClass)
			if (unit.stats.surface_damage_mult >= 0.0 and String(entry["kind"]) != "air"):
				mult = unit.stats.surface_damage_mult
			power += float(entry["value"]) / total * unit.dps(String(entry["kind"])) * mult
		var siege : float = unit.stats.surface_damage_mult if unit.stats.surface_damage_mult >= 0.0 else 1.0
		power += unit.dps("surface") * siege * float(params["siege"])
	var score : float = pow(maxf(unit.health, 0.1), float(params["health_exp"])) * power / pow(maxf(float(unit.price), 1.0), float(params["price_exp"]))
	if (float(view["enemy_air"]) > 0.0):
		if (unit.hits("air")):
			score *= float(params["anti_air"])
		if (unit.is_air and unit.stats.air_hunter == false and unit.stats.prefers_air == false):
			score *= float(params["escort_air"])
	if (float(view["enemy_sub"]) > 0.0 and unit.hits("sub")):
		score *= float(params["anti_sub"])
	score *= float(weights.get(unit.id, 1.0))
	if (mode != "adaptive" and mode != "counter"):
		score = maxf(score, 0.05)
	return score

func _use_skills(game : GameRound, ui : GameUI, view : Dictionary) -> void:
	var skills : SkillManager = game.skill_manager
	if (skills == null or !skills.enabled):
		return
	var cluster : Dictionary = view["cluster"]
	if (float(params["use_bomb"]) > 0.0 and float(cluster["value"]) >= float(params["bomb_value"]) and skills.cooldown_left(&"bomb") <= 0.0
			and ui.screw_label.total_value >= SkillCatalog.BOMB_COST):
		skills._drop_bombs(cluster["position"] as Vector2)
		skills_used["bomb"] = int(skills_used["bomb"]) + 1
	elif (float(params["use_boost"]) > 0.0 and ui.screw_label.total_value >= int(params["boost_screws"]) and skills.cooldown_left(&"boost") <= 0.0):
		if (skills._fire_boost()):
			skills_used["boost"] = int(skills_used["boost"]) + 1
