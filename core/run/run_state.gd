class_name RunState
extends RefCounted

var seed_value : int = 0
var map : RunMap
var stage : int = RunData.Stage.MAP
var current_node : int = -1
var focus_node : int = -1
var history : Array[int] = []
var base_hp : int = RunData.BASE_MAX_HP
var base_max_hp : int = RunData.BASE_MAX_HP
var screws : int = 0
var relics : Array[StringName] = []
var risks : Array[StringName] = []
var unit_buffs : Dictionary = {}
var boss_coins : int = 0
var result : int = RunData.Result.NONE
var end_reason : String = ""
var rewards_paid : bool = false
var end_summary : Dictionary = {}
var node_result : Dictionary = {}
var relic_offer : Array[StringName] = []
var pending_event_offer : bool = false
var _node_hp_before : int = 0

static func create(new_seed : int = 0) -> RunState:
	var run : RunState = RunState.new()
	run.seed_value = new_seed if new_seed != 0 else int(Time.get_unix_time_from_system()) ^ randi()
	run.map = RunMap.generate(run.seed_value)
	var guard : int = 0
	while (!run.map.is_valid() and guard < 50):
		guard += 1
		run.seed_value += 1
		run.map = RunMap.generate(run.seed_value)
	run.base_max_hp = int(Global.modify(Enums.UpgradeTarget.BASE, &"base_health", float(RunData.BASE_MAX_HP)))
	run.base_hp = run.base_max_hp
	return run

func is_active() -> bool:
	return result == RunData.Result.NONE and stage != RunData.Stage.ENDED

func floor_number() -> int:
	var node : Dictionary = map.get_node(focus_node if focus_node >= 0 else _anchor_node())
	return mini(int(node["col"]) + 1, RunData.COLUMNS)

func floors_cleared() -> int:
	return history.size()

func _anchor_node() -> int:
	return current_node if current_node >= 0 else 0

func reachable_nodes() -> Array[int]:
	if (!is_active()):
		return []
	if (current_node < 0):
		return map.first_ids()
	return map.next_ids(current_node)

func is_reachable(id : int) -> bool:
	return reachable_nodes().has(id) and !bool(map.get_node(id)["done"])

func node_state(id : int) -> String:
	if (history.has(id)):
		return "current" if id == current_node else "done"
	if (is_reachable(id)):
		return "normal"
	return "locked"

func equipped_risks_bonus() -> float:
	var total : float = 0.0
	for risk_id : StringName in risks:
		total += float(RunData.RISKS[risk_id]["bonus"])
	return total

func node_weather(id : int) -> int:
	var forced : float = _risk_value(&"force_weather", 0.0)
	if (id == focus_node and forced > 0.0):
		return int(forced)
	return int(map.get_node(id)["weather"])

func node_difficulty(id : int) -> int:
	var node : Dictionary = map.get_node(id)
	var score : int = 1 + int(node["col"]) / 2
	if (node["type"] == RunData.NodeType.ELITE):
		score += 1
	elif (node["type"] == RunData.NodeType.BOSS):
		score += 2
	score += int(RunData.WEATHER[node_weather(id)]["difficulty"])
	if (id == focus_node):
		score += risks.size() / 2
	return clampi(score, 1, 5)

func battle_distance(id : int) -> float:
	var node : Dictionary = map.get_node(id)
	var range_pair : Array = RunData.BATTLE_DISTANCE.get(int(node["objective"]), [RunData.CLASSIC_DISTANCE, RunData.CLASSIC_DISTANCE])
	var low : float = float(range_pair[0])
	var high : float = float(range_pair[1])
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([seed_value, id, "distance"])
	var t : float = float(node_difficulty(id) - 1) / 4.0
	var jitter : float = rng.randf_range(-1.0, 1.0) * RunData.BATTLE_DISTANCE_JITTER
	return clampf(lerpf(low, high, clampf(t + jitter, 0.0, 1.0)), low, high)

func expected_screws(id : int) -> int:
	var node : Dictionary = map.get_node(id)
	var base : float = RunData.NODE_REWARD_BASE + RunData.NODE_REWARD_PER_FLOOR * (int(node["col"]) + 1)
	if (node["type"] == RunData.NodeType.ELITE or node["type"] == RunData.NodeType.BOSS):
		base *= RunData.ELITE_REWARD_MULT
	base *= modify(RunData.T_RUN, &"reward_mult", 1.0)
	return int(round(base * (1.0 + equipped_risks_bonus())))

func gives_relic(id : int) -> bool:
	var node : Dictionary = map.get_node(id)
	return node["type"] == RunData.NodeType.ELITE or node["type"] == RunData.NodeType.BATTLE

func expected_relic_text(id : int) -> String:
	var node : Dictionary = map.get_node(id)
	if (node["type"] == RunData.NodeType.ELITE):
		return "run.1_relic"
	if (node["type"] == RunData.NodeType.BATTLE):
		return Loc.t("run.relic_chance") % int(RunData.RELIC_CHANCE_BATTLE * 100.0)
	return ""

func _effect_sources() -> Array[Dictionary]:
	var effects : Array[Dictionary] = []
	for relic_id : StringName in relics:
		for effect : Dictionary in RunData.RELICS[relic_id]["effects"]:
			effects.append(effect)
	for risk_id : StringName in risks:
		for effect : Dictionary in RunData.RISKS[risk_id]["effects"]:
			effects.append(effect)
	if (stage == RunData.Stage.BATTLE and current_node >= 0):
		for effect : Dictionary in RunData.WEATHER[battle_weather()]["effects"]:
			effects.append(effect)
	return effects

func battle_weather() -> int:
	var forced : float = _risk_value(&"force_weather", 0.0)
	if (forced > 0.0):
		return int(forced)
	return int(map.get_node(pending_node)["weather"]) if pending_node >= 0 else RunData.Weather.CLEAR

func modify(target : int, stat : StringName, value : float, entity_name : String = "") -> float:
	var result_value : float = value
	for effect : Dictionary in _effect_sources():
		if (int(effect["target"]) != target or effect["stat"] != stat):
			continue
		if (effect["op"] == "mul"):
			result_value *= float(effect["value"])
		else:
			result_value += float(effect["value"])
	if (target == RunData.T_ENTITY and unit_buffs.has(entity_name) and stat == &"health"):
		result_value *= pow(RunData.UPGRADE_HEALTH_MULT, int(unit_buffs[entity_name]))
	return result_value

func _risk_value(stat : StringName, default_value : float) -> float:
	var total : float = default_value
	for risk_id : StringName in risks:
		for effect : Dictionary in RunData.RISKS[risk_id]["effects"]:
			if (effect["stat"] == stat):
				total = total + float(effect["value"]) if effect["op"] == "add" else total * float(effect["value"])
	return total

var pending_node : int = -1

func _recompute_max_hp() -> void:
	var previous : int = base_max_hp
	var raw : float = Global.modify(Enums.UpgradeTarget.BASE, &"base_health", float(RunData.BASE_MAX_HP))
	for relic_id : StringName in relics:
		for effect : Dictionary in RunData.RELICS[relic_id]["effects"]:
			if (effect["stat"] == &"max_hp"):
				raw += float(effect["value"])
	base_max_hp = maxi(int(raw), 10)
	if (base_max_hp > previous):
		base_hp += base_max_hp - previous
	base_hp = clampi(base_hp, 1, base_max_hp)

func set_focus(id : int) -> bool:
	if (stage != RunData.Stage.MAP or id < 0 or id >= map.nodes.size()):
		return false
	focus_node = id
	return true

func confirm_focus() -> bool:
	if (stage != RunData.Stage.MAP or !is_reachable(focus_node)):
		return false
	pending_node = focus_node
	var node : Dictionary = map.get_node(pending_node)
	match int(node["type"]):
		RunData.NodeType.BATTLE, RunData.NodeType.ELITE, RunData.NodeType.BOSS:
			stage = RunData.Stage.BRIEFING
		RunData.NodeType.EVENT:
			stage = RunData.Stage.EVENT
		RunData.NodeType.SHIPYARD:
			stage = RunData.Stage.SHIPYARD
	return true

func back_to_map() -> void:
	if (stage == RunData.Stage.BRIEFING):
		stage = RunData.Stage.MAP
		pending_node = -1
		risks.clear()

func risk_available(risk_id : StringName) -> bool:
	return !risks.has(risk_id) and risks.size() < RunData.MAX_RISKS

func toggle_risk(risk_id : StringName) -> bool:
	if (stage != RunData.Stage.BRIEFING or !RunData.RISKS.has(risk_id)):
		return false
	if (risks.has(risk_id)):
		risks.erase(risk_id)
		return true
	if (risks.size() >= RunData.MAX_RISKS):
		return false
	risks.append(risk_id)
	return true

func start_battle() -> bool:
	if (stage != RunData.Stage.BRIEFING or pending_node < 0):
		return false
	_node_hp_before = base_hp
	stage = RunData.Stage.BATTLE
	return true

func resolve_battle(success : bool, base_hp_now : int, base_destroyed : bool, boss_defeated : bool) -> void:
	if (stage != RunData.Stage.BATTLE):
		return
	var node : Dictionary = map.get_node(pending_node)
	var is_boss : bool = int(node["type"]) == RunData.NodeType.BOSS
	base_hp = clampi(base_hp_now, 0, base_max_hp)
	var damage : int = _node_hp_before - base_hp
	if (base_destroyed or base_hp <= 0):
		_end_run(RunData.Result.LOST, "run.the_base_was_destroyed_during")
		return
	if (!success):
		base_hp = maxi(base_hp - RunData.FAIL_BASE_DAMAGE, 0)
		damage = _node_hp_before - base_hp
		if (base_hp <= 0):
			_end_run(RunData.Result.LOST, "run.the_objective_failed_and_the")
			return
	var gained : int = 0
	var offer : bool = false
	if (success):
		gained = expected_screws(pending_node)
		screws += gained
		var heal : int = int(modify(RunData.T_RUN, &"heal_after_battle", 0.0))
		base_hp = mini(base_hp + heal, base_max_hp)
		var chance : float = 1.0 if int(node["type"]) == RunData.NodeType.ELITE else RunData.RELIC_CHANCE_BATTLE
		offer = !is_boss and _rng().randf() < chance
	node["done"] = true
	history.append(pending_node)
	current_node = pending_node
	if (boss_defeated):
		boss_coins += RunData.BOSS_COINS_ON_VICTORY
	node_result = {
		"node": pending_node, "success": success, "screws": gained, "damage": maxi(damage, 0),
		"base_hp": base_hp, "relic_offered": offer, "relic": &"", "risk_bonus": equipped_risks_bonus(),
	}
	if (offer):
		relic_offer = roll_relic_offer()
		offer = !relic_offer.is_empty()
		node_result["relic_offered"] = offer
	risks.clear()
	if (success and is_boss):
		_end_run(RunData.Result.WON, "run.the_sector_boss_was_defeated")
		return
	stage = RunData.Stage.NODE_DONE

func _rng() -> RandomNumberGenerator:
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return rng

func continue_after_node() -> void:
	if (stage != RunData.Stage.NODE_DONE):
		return
	if (bool(node_result.get("relic_offered", false)) and !relic_offer.is_empty()):
		stage = RunData.Stage.RELIC
	else:
		stage = RunData.Stage.MAP
		pending_node = -1

func roll_relic_offer() -> Array[StringName]:
	var rng : RandomNumberGenerator = _rng()
	var offer : Array[StringName] = []
	var floor_index : int = int(map.get_node(pending_node)["col"]) if pending_node >= 0 else 0
	var pool : Array[StringName] = []
	for relic_id : StringName in RunData.RELICS:
		if (relics.has(relic_id)):
			continue
		if (int(RunData.RELICS[relic_id]["rarity"]) == RunData.Rarity.CURSED and floor_index < 1):
			continue
		pool.append(relic_id)
	while (offer.size() < RunData.RELIC_OFFER_SIZE and !pool.is_empty()):
		var rarity : int = _roll_rarity(rng)
		var candidates : Array[StringName] = pool.filter(
			func(rid : StringName) -> bool: return int(RunData.RELICS[rid]["rarity"]) == rarity)
		if (candidates.is_empty()):
			candidates = pool
		var pick : StringName = candidates[rng.randi_range(0, candidates.size() - 1)]
		offer.append(pick)
		pool.erase(pick)
	return offer

func _roll_rarity(rng : RandomNumberGenerator) -> int:
	var total : float = 0.0
	for rarity : int in RunData.RARITY_WEIGHTS:
		total += float(RunData.RARITY_WEIGHTS[rarity])
	var pick : float = rng.randf() * total
	for rarity : int in RunData.RARITY_WEIGHTS:
		pick -= float(RunData.RARITY_WEIGHTS[rarity])
		if (pick <= 0.0):
			return rarity
	return RunData.Rarity.COMMON

func claim_relic(relic_id : StringName) -> bool:
	if (stage != RunData.Stage.RELIC or !relic_offer.has(relic_id) or relics.has(relic_id)):
		return false
	relics.append(relic_id)
	node_result["relic"] = relic_id
	_apply_relic_instant(relic_id)
	_close_relic_offer()
	return true

func skip_relic() -> bool:
	if (stage != RunData.Stage.RELIC):
		return false
	_close_relic_offer()
	return true

func _apply_relic_instant(relic_id : StringName) -> void:
	_recompute_max_hp()

func _close_relic_offer() -> void:
	relic_offer.clear()
	node_result["relic_offered"] = false
	if (pending_event_offer):
		pending_event_offer = false
	stage = RunData.Stage.MAP
	pending_node = -1

func current_event() -> Dictionary:
	if (pending_node < 0):
		return {}
	return RunData.event_by_id(StringName(map.get_node(pending_node)["event_id"]))

func can_choose_event(index : int) -> bool:
	if (stage != RunData.Stage.EVENT or pending_node < 0):
		return false
	var choices : Array = current_event().get("choices", [])
	if (index < 0 or index >= choices.size()):
		return false
	return screws + int(choices[index].get("screws", 0)) >= 0

func choose_event(index : int) -> bool:
	if (!can_choose_event(index)):
		return false
	var node : Dictionary = map.get_node(pending_node)
	if (bool(node["done"])):
		return false
	var choice : Dictionary = current_event()["choices"][index]
	node["done"] = true
	history.append(pending_node)
	current_node = pending_node
	screws += int(choice.get("screws", 0))
	var hp_change : int = int(choice.get("hp", 0))
	base_hp = clampi(base_hp + hp_change, 1, base_max_hp)
	if (bool(choice.get("relic_offer", false))):
		pending_event_offer = true
		relic_offer = roll_relic_offer()
		node_result = {"node": pending_node, "relic_offered": !relic_offer.is_empty()}
		if (!relic_offer.is_empty()):
			stage = RunData.Stage.RELIC
			return true
		pending_event_offer = false
	stage = RunData.Stage.MAP
	pending_node = -1
	return true

func shipyard_used(action : String) -> bool:
	return pending_node >= 0 and map.get_node(pending_node)["used"].has(action)

func can_repair() -> bool:
	return stage == RunData.Stage.SHIPYARD and !shipyard_used("repair") \
			and screws >= RunData.REPAIR_COST and base_hp < base_max_hp

func repair_base() -> bool:
	if (!can_repair()):
		return false
	screws -= RunData.REPAIR_COST
	base_hp = mini(base_hp + RunData.REPAIR_HP, base_max_hp)
	map.get_node(pending_node)["used"].append("repair")
	return true

func can_upgrade_unit() -> bool:
	return stage == RunData.Stage.SHIPYARD and !shipyard_used("upgrade") and screws >= RunData.UPGRADE_COST

func upgrade_unit(unit_name : String) -> bool:
	if (!can_upgrade_unit() or !Global.player_stats.has_boat(unit_name)):
		return false
	screws -= RunData.UPGRADE_COST
	unit_buffs[unit_name] = int(unit_buffs.get(unit_name, 0)) + 1
	map.get_node(pending_node)["used"].append("upgrade")
	return true

func leave_shipyard() -> void:
	if (stage != RunData.Stage.SHIPYARD):
		return
	var node : Dictionary = map.get_node(pending_node)
	if (!bool(node["done"])):
		node["done"] = true
		history.append(pending_node)
		current_node = pending_node
	stage = RunData.Stage.MAP
	pending_node = -1

func _end_run(new_result : int, reason : String) -> void:
	if (result != RunData.Result.NONE):
		return
	result = new_result
	end_reason = reason
	stage = RunData.Stage.ENDED
	pay_rewards()

func pay_rewards() -> void:
	if (rewards_paid):
		return
	rewards_paid = true
	var gears : int = history.size() * RunData.GEARS_PER_NODE
	var coins : int = boss_coins
	if (result == RunData.Result.WON):
		gears += RunData.GEARS_VICTORY_BONUS
	end_summary = {"gears": gears, "boss_coins": coins, "floors": mini(history.size(), RunData.COLUMNS),
		"won": result == RunData.Result.WON}
	Global.player_stats.gear += gears
	Global.player_stats.boss_coin += coins
	Global.save_game()

func abandon() -> void:
	result = RunData.Result.LOST
	rewards_paid = true
	stage = RunData.Stage.ENDED
	end_reason = "run.run_abandoned"

func to_dict() -> Dictionary:
	var relic_names : Array = []
	for relic_id : StringName in relics:
		relic_names.append(str(relic_id))
	var offer_names : Array = []
	for relic_id : StringName in relic_offer:
		offer_names.append(str(relic_id))
	var risk_names : Array = []
	for risk_id : StringName in risks:
		risk_names.append(str(risk_id))
	return {
		"seed": seed_value, "map": map.to_dict(), "stage": stage, "current_node": current_node,
		"focus_node": focus_node, "pending_node": pending_node, "history": history,
		"base_hp": base_hp, "base_max_hp": base_max_hp, "screws": screws,
		"relics": relic_names, "risks": risk_names, "unit_buffs": unit_buffs,
		"boss_coins": boss_coins, "result": result, "end_reason": end_reason,
		"rewards_paid": rewards_paid, "relic_offer": offer_names,
		"pending_event_offer": pending_event_offer, "node_hp_before": _node_hp_before,
		"node_result": _result_to_json(),
	}

func _result_to_json() -> Dictionary:
	var copy : Dictionary = node_result.duplicate()
	if (copy.has("relic")):
		copy["relic"] = str(copy["relic"])
	return copy

static func from_dict(data : Dictionary) -> RunState:
	var run : RunState = RunState.new()
	run.seed_value = int(data.get("seed", 0))
	run.map = RunMap.from_dict(data.get("map", {}))
	if (!run.map.is_valid()):
		return null
	run.stage = int(data.get("stage", RunData.Stage.MAP))
	run.current_node = int(data.get("current_node", -1))
	run.focus_node = int(data.get("focus_node", -1))
	run.pending_node = int(data.get("pending_node", -1))
	for id : Variant in data.get("history", []):
		run.history.append(int(id))
	run.base_hp = int(data.get("base_hp", RunData.BASE_MAX_HP))
	run.base_max_hp = int(data.get("base_max_hp", RunData.BASE_MAX_HP))
	run.screws = int(data.get("screws", 0))
	for relic_name : Variant in data.get("relics", []):
		if (RunData.RELICS.has(StringName(str(relic_name)))):
			run.relics.append(StringName(str(relic_name)))
	for relic_name : Variant in data.get("relic_offer", []):
		if (RunData.RELICS.has(StringName(str(relic_name)))):
			run.relic_offer.append(StringName(str(relic_name)))
	for risk_name : Variant in data.get("risks", []):
		if (RunData.RISKS.has(StringName(str(risk_name)))):
			run.risks.append(StringName(str(risk_name)))
	var buffs : Dictionary = data.get("unit_buffs", {})
	for unit_name : Variant in buffs:
		run.unit_buffs[str(unit_name)] = int(buffs[unit_name])
	run.boss_coins = int(data.get("boss_coins", 0))
	run.result = int(data.get("result", RunData.Result.NONE))
	run.end_reason = str(data.get("end_reason", ""))
	run.rewards_paid = bool(data.get("rewards_paid", false))
	run.pending_event_offer = bool(data.get("pending_event_offer", false))
	run._node_hp_before = int(data.get("node_hp_before", run.base_hp))
	run.node_result = data.get("node_result", {})
	if (run.node_result.has("relic")):
		run.node_result["relic"] = StringName(str(run.node_result["relic"]))
	if (run.stage == RunData.Stage.BATTLE):
		run.stage = RunData.Stage.BRIEFING
		run.base_hp = run._node_hp_before
	return run
