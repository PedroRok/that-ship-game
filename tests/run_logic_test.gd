extends Node

var failures : int = 0

func check(condition : bool, message : String) -> void:
	if (condition):
		print("PASS  ", message)
	else:
		failures += 1
		print("FAIL  ", message)

func _ready() -> void:
	SaveManager.use_test_directory()
	Global.player_stats = Global.player_stats.duplicate()
	for starter : String in ["mini", "small"]:
		if (!Global.player_stats.has_boat(starter)):
			Global.player_stats.add_entity(Global.CATALOG.find_unit(starter))
	test_map()
	test_flow()
	test_once_only()
	test_events_and_shipyard()
	test_risks()
	test_serialization()
	test_failure_and_defeat()
	test_assets()
	test_director()
	print("---- ", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func test_map() -> void:
	var bad : int = 0
	for seed_value : int in range(1, 301):
		var map : RunMap = RunMap.generate(seed_value)
		var valid : bool = map.nodes.size() == RunData.BOSS_ID + 1
		for id : int in map.first_ids():
			if (!map.has_path_to_boss(id)):
				valid = false
		for entry : Dictionary in map.nodes:
			var id : int = int(entry["id"])
			if (map.column_of(id) == 0):
				continue
			var incoming : bool = false
			for from_id : Variant in map.edges:
				if (map.next_ids(int(from_id)).has(id)):
					incoming = true
			if (!incoming):
				valid = false
		if (!valid):
			bad += 1
	check(bad == 0, "300 seeds: 13 nodes, every route reaches the boss, no orphan node (bad=%d)" % bad)
	var map_a : RunMap = RunMap.generate(42)
	var map_b : RunMap = RunMap.generate(42)
	check(JSON.stringify(map_a.to_dict()) == JSON.stringify(map_b.to_dict()), "same seed gives the same map")

func new_run(seed_value : int = 7) -> RunState:
	var run : RunState = RunState.create(seed_value)
	Global.run = run
	return run

func play_node(run : RunState, id : int, success : bool = true, hp : int = -1) -> void:
	run.set_focus(id)
	check(run.confirm_focus(), "confirm node %d" % id)
	if (run.stage == RunData.Stage.BRIEFING):
		check(run.start_battle(), "start battle at node %d" % id)
		run.resolve_battle(success, run.base_hp if hp < 0 else hp, false, 0)

func test_flow() -> void:
	var run : RunState = new_run()
	check(run.stage == RunData.Stage.MAP, "run starts on the map")
	var locked : int = RunData.BOSS_ID
	run.set_focus(locked)
	check(!run.confirm_focus(), "unreachable destination cannot advance the run")
	var first : int = run.reachable_nodes()[0]
	for id : int in run.reachable_nodes():
		if (int(run.map.get_node(id)["type"]) == RunData.NodeType.BATTLE):
			first = id
			break
	play_node(run, first)
	check(run.stage == RunData.Stage.NODE_DONE, "battle ends on the node-complete screen")
	check(run.screws > 0 and run.history == [first], "screws paid and route recorded")
	var before : int = run.screws
	run.continue_after_node()
	if (run.stage == RunData.Stage.RELIC):
		check(!run.relic_offer.is_empty() and run.relic_offer.size() <= RunData.RELIC_OFFER_SIZE, "relic offer has up to 3 options")
		check(!run.claim_relic(&"not_in_offer"), "claiming a relic outside the offer is rejected")
		var pick : StringName = run.relic_offer[0]
		check(run.claim_relic(pick) and run.relics.has(pick), "claiming a relic adds it once")
		check(!run.claim_relic(pick), "second claim is rejected")
	check(run.stage == RunData.Stage.MAP, "flow returns to the map")
	check(run.screws == before, "continuing does not pay again")
	var guard : int = 0
	while (run.is_active() and guard < 20):
		guard += 1
		var options : Array[int] = run.reachable_nodes()
		if (options.is_empty()):
			break
		var id : int = options[0]
		var node_type : int = int(run.map.get_node(id)["type"])
		run.set_focus(id)
		run.confirm_focus()
		match node_type:
			RunData.NodeType.EVENT:
				var index : int = run.current_event()["choices"].size() - 1
				run.choose_event(index)
			RunData.NodeType.SHIPYARD:
				run.leave_shipyard()
			_:
				run.start_battle()
				run.resolve_battle(true, run.base_hp, false, int(node_type == RunData.NodeType.BOSS))
		if (run.stage == RunData.Stage.NODE_DONE):
			run.continue_after_node()
		if (run.stage == RunData.Stage.RELIC):
			run.skip_relic()
	check(run.result == RunData.Result.WON, "defeating the boss ends the run as a win (result=%d)" % run.result)
	check(run.rewards_paid and int(run.end_summary["gears"]) > 0, "win paid gears")
	var gears_after : int = Global.player_stats.gear
	run.pay_rewards()
	check(Global.player_stats.gear == gears_after, "rewards are paid only once")

func test_once_only() -> void:
	var run : RunState = new_run(11)
	var node : int = run.reachable_nodes()[0]
	for id : int in run.reachable_nodes():
		if (int(run.map.get_node(id)["type"]) == RunData.NodeType.BATTLE):
			node = id
			break
	run.set_focus(node)
	run.confirm_focus()
	run.start_battle()
	run.resolve_battle(true, 80, false, 0)
	var screws : int = run.screws
	var hp : int = run.base_hp
	run.resolve_battle(true, 10, false, 0)
	run.resolve_battle(false, 1, true, 0)
	check(run.screws == screws and run.base_hp == hp and run.result == RunData.Result.NONE,
			"resolving a battle twice (double click / re-created scene) changes nothing")
	check(!run.start_battle(), "cannot start a second battle from the node-complete screen")

func test_events_and_shipyard() -> void:
	var run : RunState = new_run(21)
	var event_id : int = -1
	var yard_id : int = -1
	for entry : Dictionary in run.map.nodes:
		if (int(entry["type"]) == RunData.NodeType.EVENT and event_id < 0):
			event_id = int(entry["id"])
		if (int(entry["type"]) == RunData.NodeType.SHIPYARD and yard_id < 0):
			yard_id = int(entry["id"])
	check(event_id >= 0 and yard_id >= 0, "map has at least one event and one shipyard")
	run.screws = 200
	run.base_hp = 50
	run.stage = RunData.Stage.MAP
	run.current_node = -1
	run.pending_node = yard_id
	run.stage = RunData.Stage.SHIPYARD
	check(run.can_repair(), "repair is available")
	check(run.repair_base() and run.base_hp == 50 + RunData.REPAIR_HP and run.screws == 200 - RunData.REPAIR_COST,
			"repair heals and charges the cost")
	check(!run.repair_base(), "repair only once per shipyard")
	check(run.upgrade_unit("small") and run.screws == 200 - RunData.REPAIR_COST - RunData.UPGRADE_COST, "upgrade charges once")
	check(!run.upgrade_unit("small"), "upgrade only once per shipyard")
	check(run.unit_buffs.get("small", 0) == 1, "unit buff recorded")
	run.leave_shipyard()
	run.leave_shipyard()
	check(run.stage == RunData.Stage.MAP and run.history.count(yard_id) == 1, "leaving the shipyard twice records the visit once")
	run.pending_node = event_id
	run.stage = RunData.Stage.EVENT
	var choices : Array = run.current_event()["choices"]
	run.screws = 0
	var costly : int = -1
	for index : int in choices.size():
		if (int(choices[index].get("screws", 0)) < 0):
			costly = index
	if (costly >= 0):
		check(!run.can_choose_event(costly), "an unaffordable event choice is disabled")
	check(run.choose_event(choices.size() - 1), "free event choice resolves")
	check(!run.choose_event(choices.size() - 1), "event cannot be resolved twice")

func test_risks() -> void:
	var run : RunState = new_run(31)
	var node : int = run.reachable_nodes()[0]
	for id : int in run.reachable_nodes():
		if (int(run.map.get_node(id)["type"]) == RunData.NodeType.BATTLE):
			node = id
			break
	run.map.get_node(node)["objective"] = RunData.Objective.DESTROY_BASE
	run.set_focus(node)
	run.confirm_focus()
	var plain : int = run.expected_screws(node)
	check(run.toggle_risk(&"stronger_enemies"), "equip risk 1")
	check(run.toggle_risk(&"less_time"), "equip risk 2")
	check(run.toggle_risk(&"fragile_base"), "equip risk 3")
	check(!run.toggle_risk(&"more_bosses"), "fourth risk is rejected (max 3)")
	var bonus : float = run.equipped_risks_bonus()
	check(is_equal_approx(bonus, 0.15 + 0.20 + 0.15), "bonus is the sum of equipped risks")
	var boosted : int = run.expected_screws(node)
	check(boosted > plain, "expected screws grow with risks (%d -> %d)" % [plain, boosted])
	run.start_battle()
	var dmg : float = Global.modify(Enums.UpgradeTarget.BASE, &"damage_taken", 1.0)
	check(is_equal_approx(dmg, 1.25), "fragile base raises damage taken in battle (%.2f)" % dmg)
	var table : RunWaveTable = RunBattleConfig.build_table(run, run.map.get_node(node))
	check(is_equal_approx(table.base_health_mult, RunData.ENEMY_HEALTH_MULT[0] * 1.25), "armored enemies scale the wave table")
	run.resolve_battle(true, run.base_hp, false, 0)
	check(run.node_result["screws"] == boosted, "paid screws match the briefing preview (%d)" % int(run.node_result["screws"]))
	check(run.risks.is_empty(), "risks are consumed by the battle")
	check(Global.modify(Enums.UpgradeTarget.BASE, &"damage_taken", 1.0) == 1.0, "no run effects outside a battle")

func test_serialization() -> void:
	var run : RunState = new_run(41)
	run.relics.append(&"hull")
	run.screws = 33
	run.unit_buffs["small"] = 2
	var json : String = JSON.stringify(run.to_dict())
	var back : RunState = RunState.from_dict(JSON.parse_string(json))
	check(back != null and back.screws == 33 and back.relics == [&"hull"] and back.unit_buffs.get("small", 0) == 2,
			"run survives a JSON save/load round trip")
	check(JSON.stringify(back.to_dict()) == json, "round trip is stable")
	back.stage = RunData.Stage.BATTLE
	back.base_hp = 10
	var again : RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())))
	check(again.stage == RunData.Stage.BRIEFING, "a run saved mid-battle reloads at the briefing")

func test_failure_and_defeat() -> void:
	var run : RunState = new_run(51)
	var node : int = run.reachable_nodes()[0]
	for id : int in run.reachable_nodes():
		if (int(run.map.get_node(id)["type"]) == RunData.NodeType.BATTLE):
			node = id
			break
	run.set_focus(node)
	run.confirm_focus()
	run.start_battle()
	var hp : int = run.base_hp
	run.resolve_battle(false, hp, false, 0)
	check(run.stage == RunData.Stage.NODE_DONE and run.base_hp == hp - RunData.FAIL_BASE_DAMAGE and run.screws == 0,
			"failed objective costs base HP and pays nothing")
	run.continue_after_node()
	check(run.stage == RunData.Stage.MAP, "failed node returns to the map (no relic)")
	var lost : RunState = new_run(52)
	var start_node : int = lost.reachable_nodes()[0]
	for id : int in lost.reachable_nodes():
		if (int(lost.map.get_node(id)["type"]) == RunData.NodeType.BATTLE):
			start_node = id
			break
	lost.set_focus(start_node)
	lost.confirm_focus()
	lost.start_battle()
	var gears : int = Global.player_stats.gear
	lost.resolve_battle(false, 0, true, 0)
	check(lost.result == RunData.Result.LOST and lost.stage == RunData.Stage.ENDED, "base destroyed ends the run as lost")
	check(lost.rewards_paid and Global.player_stats.gear >= gears, "defeat pays its (small) reward once")

func test_assets() -> void:
	var missing : Array[String] = []
	for relic_id : StringName in RunData.RELICS:
		if (RunData.relic_icon(relic_id) == null):
			missing.append("relic " + relic_id)
	for risk_id : StringName in RunData.RISKS:
		if (RunData.risk_icon(risk_id) == null):
			missing.append("risk " + risk_id)
	for weather : int in RunData.WEATHER:
		if (RunData.weather_icon(weather) == null):
			missing.append("weather %d" % weather)
	for objective : int in RunData.OBJECTIVES:
		if (RunData.objective_overlay(objective) == null or RunData.objective_hud_icon(objective) == null):
			missing.append("objective %d" % objective)
	for node_type : int in RunData.NODE_ICON_KEYS:
		for state : String in ["normal", "hover", "done", "locked", "current"]:
			if (RunData.node_glyph(node_type, state) == null):
				missing.append("node %d %s" % [node_type, state])
	for key : String in ["base_health", "base_health_damaged", "boss", "floors", "repair", "upgrade_unit", "cargo_box",
			"beacon_signal", "continue_trip", "check_ok", "cross_fail"]:
		if (RunData.ui_icon(key) == null or RunData.ui_icon(key, true) == null):
			missing.append("icon " + key)
	check(missing.is_empty(), "every referenced icon loads (%s)" % ", ".join(missing))

func test_director() -> void:
	var even : ThreatDirector = ThreatDirector.new()
	for i : int in 60:
		even.update(0.5, 5, 5, 1.0, 1.0)
	check(absf(even.threat - 50.0) < 2.0 and is_equal_approx(even.interval_mult, 1.0), "even match with full HP stays neutral (threat %.1f)" % even.threat)
	var start : ThreatDirector = ThreatDirector.new()
	start.update(0.5, 0, 0, 1.0, 1.0)
	check(start.skip_chance == 0.0 and start.interval_mult <= 1.0 + 0.001, "empty battle start is not read as 'struggling'")
	var winning : ThreatDirector = ThreatDirector.new()
	for i : int in 200:
		winning.update(0.5, 12, 2, 1.0, 0.3)
	check(winning.interval_mult < 0.85 and winning.skip_chance == 0.0, "dominating player: enemies spawn faster (x%.2f)" % winning.interval_mult)
	var losing : ThreatDirector = ThreatDirector.new()
	for i : int in 200:
		losing.update(0.5, 1, 12, 0.3, 1.0)
	check(losing.interval_mult > 1.1 and losing.skip_chance > 0.05, "struggling player: slower spawns (x%.2f) and skipped spawns (%.0f%%)" % [losing.interval_mult, losing.skip_chance * 100.0])
	var low : float = 1.0 - RunData.DIRECTOR_RANGE
	var high : float = 1.0 + RunData.DIRECTOR_RANGE
	check(winning.interval_mult >= low - 0.0001 and losing.interval_mult <= high + 0.0001 and losing.skip_chance <= RunData.DIRECTOR_MAX_SKIP + 0.0001,
			"output always stays inside the +-30% limits")
	var hp_full : float = ThreatDirector.interval_for(ThreatDirector.raw_score(5, 5, 1.0, 1.0))
	var hp_empty : float = ThreatDirector.interval_for(ThreatDirector.raw_score(5, 5, 0.0, 1.0))
	var unit_swing : float = ThreatDirector.interval_for(ThreatDirector.raw_score(10, 0, 1.0, 1.0))
	check(absf(hp_empty - hp_full) < 0.08 and absf(unit_swing - hp_full) > absf(hp_empty - hp_full) * 2.0,
			"base HP is a light multiplier (HP swing %.3f vs unit swing %.3f)" % [absf(hp_empty - hp_full), absf(unit_swing - hp_full)])
	var slow : ThreatDirector = ThreatDirector.new()
	slow.update(0.5, 12, 0, 1.0, 0.0)
	check(slow.interval_mult > 0.9, "the pace changes gradually, not in one step (x%.2f after 0.5s)" % slow.interval_mult)
