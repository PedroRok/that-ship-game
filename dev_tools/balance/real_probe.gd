extends Node

const OUT_DIR : String = "res://extras/balance_reports/"
const BASE_SLOT : int = 90
const SINGLE_SLOT : int = 99
const MAX_GAME_SECONDS : float = 700.0
const SAMPLE_FRAMES : int = 30
const SAVE_MARGIN : float = 14.0
const SIM_RUNS : int = 20
const FINISHED_SHOWN : int = 8
const OBJECTIVES : Array[int] = [
	RunData.Objective.DESTROY_BASE, RunData.Objective.DEFEND, RunData.Objective.ESCORT,
	RunData.Objective.HUNT_SUBMARINE, RunData.Objective.SHOOT_DOWN_BOMBER, RunData.Objective.DEFEAT_BOSS,
]

var floors : Array[int] = [1]
var budgets : Array[int] = [150, 900]
var only_objectives : Array[int] = []
var seeds : int = 1
var shard : int = 0
var shard_count : int = 1
var merge_only : bool = false
var slot : int = SINGLE_SLOT
var overlay : Label
var finished_lines : Array[String] = []
var scenarios : Array[Dictionary] = []
var rows : Array[Dictionary] = []
var speed_ratio : Dictionary = {}

func _ready() -> void:
	_parse_args()
	if (merge_only):
		_merge()
		get_tree().quit()
		return
	SaveManager.slot = slot
	_make_overlay()
	get_window().size = Vector2i(1280, 720)
	_build_scenarios()
	for scenario : Dictionary in scenarios:
		await _play(int(scenario["objective"]), int(scenario["floor"]), int(scenario["budget"]), int(scenario["seed"]))
	_save_rows()
	_live_done()
	_cleanup_slot()
	if (shard_count == 1):
		_merge()
	get_tree().quit()

func _parse_args() -> void:
	for arg : String in OS.get_cmdline_user_args():
		if (arg.begins_with("floors=")):
			floors = _ints(arg.substr(7))
		elif (arg.begins_with("budgets=")):
			budgets = _ints(arg.substr(8))
		elif (arg.begins_with("seeds=")):
			seeds = int(arg.substr(6))
		elif (arg.begins_with("obj=")):
			only_objectives = _ints(arg.substr(4))
		elif (arg.begins_with("shard=")):
			var parts : PackedStringArray = arg.substr(6).split("/")
			shard = int(parts[0])
			shard_count = maxi(int(parts[1]), 1)
		elif (arg == "merge"):
			merge_only = true
	slot = BASE_SLOT + shard if shard_count > 1 else SINGLE_SLOT

func _ints(text : String) -> Array[int]:
	var result : Array[int] = []
	for part : String in text.split(","):
		if (part.is_valid_int()):
			result.append(int(part))
	return result

func _build_scenarios() -> void:
	var index : int = 0
	for objective : int in OBJECTIVES:
		if (!only_objectives.is_empty() and !only_objectives.has(objective)):
			continue
		for floor_index : int in floors:
			for budget : int in budgets:
				for seed_index : int in range(seeds):
					if (index % shard_count == shard):
						scenarios.append({"objective": objective, "floor": floor_index, "budget": budget, "seed": seed_index})
					index += 1

func _play(objective : int, floor_index : int, budget : int, seed_index : int) -> void:
	var progress : BalanceProgress = BalanceProgress.build(Global.CATALOG, budget, budget / 250)
	var loadout : Array[BalanceUnit] = BalanceSim.pick_loadout(progress)
	var stats : PlayerStats = Global.player_stats.duplicate()
	stats.unlocked_entities = []
	stats.loadout = []
	stats.start_screw = BalanceSim.START_SCREWS
	stats.upgrade_levels = progress.levels.duplicate()
	for unit_name : String in progress.unlocked:
		stats.unlocked_entities.append(Global.CATALOG.find_unit(unit_name))
	for unit : BalanceUnit in loadout:
		stats.loadout.append(unit.id)
	Global.player_stats = stats
	var run : RunState = RunState.create(500 + objective + seed_index * 97)
	Global.run = run
	var node_id : int = RunData.BOSS_ID if objective == RunData.Objective.DEFEAT_BOSS else 0
	var entry : Dictionary = run.map.get_node(node_id)
	entry["objective"] = objective
	entry["col"] = floor_index
	entry["type"] = RunData.NodeType.BOSS if objective == RunData.Objective.DEFEAT_BOSS else RunData.NodeType.BATTLE
	entry["weather"] = RunData.Weather.CLEAR
	run.pending_node = node_id
	run.focus_node = node_id
	run.stage = RunData.Stage.BRIEFING
	run.start_battle()
	var game : GameRound = load("res://scenes/ui/naval_hud/naval_round.tscn").instantiate() as GameRound
	add_child(game)
	await get_tree().process_frame
	var tracker : Dictionary = {"deaths": {}, "reason": "", "escort_max": 0.0}
	var ships : ShipManager = game.get_node("ShipsManager") as ShipManager
	ships.unit_destroyed.connect(func(stats : EntityStats, team : TeamStats) -> void:
		var key : String = ("ally:" if team.team_id == 1 else "enemy:") + stats.name
		var deaths : Dictionary = tracker["deaths"]
		deaths[key] = int(deaths.get(key, 0)) + 1)
	game.ally_base.death_event.connect(func(_team : TeamStats) -> void:
		if (String(tracker["reason"]).is_empty()):
			tracker["reason"] = "base_destroyed")
	var start_frame : int = Engine.get_physics_frames()
	var peak : int = 0
	var enemy_sum : float = 0.0
	var samples : int = 0
	var spawned : Dictionary = {}
	var seen : Dictionary = {}
	var game_time : float = 0.0
	while (run.stage == RunData.Stage.BATTLE and game_time < MAX_GAME_SECONDS):
		for step : int in range(SAMPLE_FRAMES):
			await get_tree().physics_frame
		game_time = float(Engine.get_physics_frames() - start_frame) / 60.0
		var context : BattleContext = BattleContext.of(game)
		var enemies : int = 0
		var mix : Dictionary = {"air": 0, "sub": 0, "surface": 0}
		var drawn : Array = []
		var ally_x : float = 0.0
		var enemy_x : float = 1.0
		for base : Base in context.bases:
			if (base.team_stats.team_id == 1):
				ally_x = base.global_position.x
			else:
				enemy_x = base.global_position.x
		for unit : Entity in context.entities:
			if (!is_instance_valid(unit) or unit.is_queued_for_deletion()):
				continue
			var kind : String = _kind_of(unit.entity_stats)
			var enemy_side : bool = unit.team_stats.team_id != 1
			if (enemy_side):
				enemies += 1
				mix[kind] = int(mix[kind]) + 1
				if (!seen.has(unit.get_instance_id())):
					seen[unit.get_instance_id()] = true
					var key : String = unit.entity_stats.name
					spawned[key] = int(spawned.get(key, 0)) + 1
			var body : RigidBody2D = unit as RigidBody2D
			if (body and unit.entity_stats.name != "escort"):
				var ratio : float = absf(body.linear_velocity.x) / maxf(unit.entity_stats.speed, 1.0)
				var name_key : String = unit.entity_stats.name
				speed_ratio[name_key] = maxf(float(speed_ratio.get(name_key, 0.0)), ratio)
			var health_node : HealthComponent = unit.get_node_or_null("HealthComponent") as HealthComponent
			var health_fraction : float = 1.0
			if (health_node and health_node.default_health > 0.0):
				health_fraction = health_node.actual_health / health_node.default_health
			drawn.append([snappedf((unit.global_position.x - ally_x) / maxf(enemy_x - ally_x, 1.0), 0.001),
				0 if enemy_side else 1, ["surface", "air", "sub"].find(kind), 1 if unit.is_submerged() else 0,
				snappedf(clampf(health_fraction, 0.0, 1.0), 0.01)])
		var battle : CampaignBattle = game.campaign
		if (battle and is_instance_valid(battle.escort) and !battle.escort.is_queued_for_deletion()):
			var span : float = maxf(enemy_x - ally_x, 1.0)
			tracker["escort_max"] = maxf(float(tracker["escort_max"]), clampf((battle.escort.global_position.x - ally_x) / span, 0.0, 1.0))
		peak = maxi(peak, enemies)
		enemy_sum += float(enemies)
		samples += 1
		_status(objective, floor_index, budget, seed_index, game_time, enemies, peak, mix, drawn, run)
		_bot(game, loadout, mix)
	var success : bool = bool(run.node_result.get("success", false)) and run.stage != RunData.Stage.ENDED or run.result == RunData.Result.WON
	var camp : CampaignBattle = game.campaign
	var reason : String = "won"
	var progress_info : Dictionary = {}
	if (camp):
		progress_info = {
			"hunted": camp.hunted, "boss_down": camp.boss_defeated, "elapsed": camp.elapsed, "time_limit": camp.time_limit,
			"defend_left": camp.defend_left, "escort_max": tracker["escort_max"],
			"enemy_base_frac": clampf(camp.enemy_base.health_component.health / maxf(camp.enemy_hp_max, 1.0), 0.0, 1.0),
			"ally_base_hp": game.ally_base.health_component.health,
		}
	if (!success):
		reason = String(tracker["reason"])
		if (reason.is_empty()):
			if (game_time >= MAX_GAME_SECONDS):
				reason = "probe_cap"
			elif (objective == RunData.Objective.ESCORT and int((tracker["deaths"] as Dictionary).get("ally:escort", 0)) > 0):
				reason = "escort_lost"
			elif (camp and camp.time_limit > 0.0 and camp.elapsed >= camp.time_limit):
				reason = "timeout"
			else:
				reason = "other"
	rows.append({
		"objective": objective, "floor": floor_index, "budget": budget, "seed": seed_index, "won": success,
		"time": game_time, "peak": peak, "avg": enemy_sum / maxf(float(samples), 1.0),
		"spawned": spawned, "base_hp": run.base_hp, "reason": reason, "deaths": tracker["deaths"], "progress": progress_info,
	})
	finished_lines.append("%s f%d %dg s%d: %s  t=%.0f  peak=%d" % [RunData.OBJECTIVES[objective]["icon"], floor_index, budget, seed_index,
			"WON" if success else "LOST", game_time, peak])
	print("REAL obj=%d floor=%d budget=%d won=%s time=%.0f peak=%d" % [objective, floor_index, budget, str(success), game_time, peak])
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _kind_of(stats : EntityStats) -> String:
	if (stats is AirPlaneState):
		return "air"
	var boat : BoatStats = stats as BoatStats
	if (boat and boat.can_submerge):
		return "sub"
	return "surface"

func _bot(game : GameRound, loadout : Array[BalanceUnit], mix : Dictionary) -> void:
	var ui : GameUI = game.get_node_or_null("CanvasLayer/GameUI") as GameUI
	if (ui == null):
		return
	var total : float = float(int(mix["air"]) + int(mix["sub"]) + int(mix["surface"]))
	var shares : Dictionary = {"air": 0.0, "sub": 0.0, "surface": 1.0}
	if (total > 0.0):
		shares = {"air": float(mix["air"]) / total, "sub": float(mix["sub"]) / total, "surface": float(mix["surface"]) / total}
	for attempt : int in range(4):
		var best : BalanceUnit = null
		var best_score : float = -1.0
		var dream : BalanceUnit = null
		var dream_score : float = -1.0
		for unit : BalanceUnit in loadout:
			if (!ui.base.queue_has_room(Base.dock_type_of(unit.stats))):
				continue
			var power : float = 0.0
			for kind : String in shares:
				power += float(shares[kind]) * unit.dps(kind)
			var score : float = unit.health * power / maxf(float(unit.price), 1.0)
			if (score > dream_score):
				dream_score = score
				dream = unit
			if (float(unit.price) > float(ui.screw_label.total_value)):
				continue
			if (score > best_score):
				best_score = score
				best = unit
		if (best == null):
			return
		if (dream != null and dream != best and dream_score > best_score * 1.4 and float(dream.price) - float(ui.screw_label.total_value) <= 0.0):
			return
		ui.spawn_entity(best.stats)

func _status(objective : int, floor_index : int, budget : int, seed_index : int, game_time : float, enemies : int, peak : int, mix : Dictionary, drawn : Array, run : RunState) -> void:
	var label : String = "%s f%d %dg s%d" % [RunData.OBJECTIVES[objective]["icon"], floor_index, budget, seed_index]
	var progress : String = "%d/%d" % [rows.size() + 1, scenarios.size()]
	if (overlay):
		overlay.text = "WORKER %d  battle %s  %s\nt %.0fs  enemies %d (peak %d)  air %d sub %d surface %d\n%s" % [
			shard, progress, label, game_time, enemies, peak, int(mix["air"]), int(mix["sub"]), int(mix["surface"]),
			"\n".join(finished_lines.slice(maxi(finished_lines.size() - FINISHED_SHOWN, 0)))]
	_write_live({"worker": shard, "state": "running", "label": label, "progress": progress, "t": game_time, "enemies": enemies,
		"peak": peak, "mix": mix, "units": drawn, "base_hp": run.base_hp, "base_max": run.base_max_hp,
		"finished": finished_lines.slice(maxi(finished_lines.size() - FINISHED_SHOWN, 0))})

func _live_done() -> void:
	_write_live({"worker": shard, "state": "done", "label": "finished", "progress": "%d/%d" % [rows.size(), scenarios.size()],
		"t": 0.0, "enemies": 0, "peak": 0, "mix": {}, "units": [], "base_hp": 0, "base_max": 1,
		"finished": finished_lines.slice(maxi(finished_lines.size() - FINISHED_SHOWN, 0))})

func _write_live(data : Dictionary) -> void:
	var file : FileAccess = FileAccess.open(OUT_DIR + "real_probe_live_%d.json" % shard, FileAccess.WRITE)
	if (file):
		file.store_string(JSON.stringify(data))
		file.close()

func _save_rows() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var file : FileAccess = FileAccess.open(OUT_DIR + "real_probe_rows_%d.json" % shard, FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows, "speed": speed_ratio}))
	file.close()

func _cleanup_slot() -> void:
	for path : String in [SaveManager.save_path(slot), SaveManager.run_path(slot)]:
		if (FileAccess.file_exists(path)):
			DirAccess.remove_absolute(path)

func _make_overlay() -> void:
	if (DisplayServer.get_name() == "headless"):
		return
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	overlay = Label.new()
	overlay.position = Vector2(300, 74)
	overlay.add_theme_font_size_override("font_size", 14)
	overlay.add_theme_color_override("font_color", Color("#ffe9a8"))
	overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	overlay.add_theme_constant_override("outline_size", 6)
	layer.add_child(overlay)

func _merge() -> void:
	var all_rows : Array[Dictionary] = []
	var speeds : Dictionary = {}
	var dir : DirAccess = DirAccess.open(OUT_DIR)
	if (dir == null):
		return
	for file_name : String in dir.get_files():
		if (!file_name.begins_with("real_probe_rows_") or !file_name.ends_with(".json")):
			continue
		var parsed : Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT_DIR + file_name))
		if (parsed is Dictionary):
			for item : Variant in (parsed as Dictionary)["rows"]:
				all_rows.append(item as Dictionary)
			var speed : Dictionary = (parsed as Dictionary)["speed"]
			for key : String in speed:
				speeds[key] = maxf(float(speeds.get(key, 0.0)), float(speed[key]))
	all_rows.sort_custom(func(a : Dictionary, b : Dictionary) -> bool:
		return [int(a["objective"]), int(a["floor"]), int(a["budget"]), int(a["seed"])] < [int(b["objective"]), int(b["floor"]), int(b["budget"]), int(b["seed"])])
	var lines : PackedStringArray = []
	lines.append("# Real probe vs simulator")
	lines.append("")
	lines.append("Real = one real game battle per row (separate Godot processes). Sim = %d seeds, same scenario." % SIM_RUNS)
	lines.append("")
	lines.append("| objective | floor | gears | real won | real time | real peak | real avg | sim win | sim time | sim peak | sim avg |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
	for row : Dictionary in all_rows:
		var wins : int = 0
		var time_sum : float = 0.0
		var peak_sum : float = 0.0
		var avg_sum : float = 0.0
		for index : int in range(SIM_RUNS):
			var scn : BalanceScenario = BalanceScenario.new()
			scn.objective = int(row["objective"])
			scn.floor_index = int(row["floor"])
			scn.seed_value = 1000 + index
			scn.progress = BalanceProgress.build(Global.CATALOG, int(row["budget"]), int(row["budget"]) / 250)
			var result : Dictionary = BalanceSim.new().run(scn)
			if (bool(result["won"])):
				wins += 1
			time_sum += float(result["time"])
			peak_sum += float(result["peak_enemies"])
			avg_sum += float(result["avg_enemies"])
		lines.append("| %d %s | %d | %d | %s | %.0f | %d | %.1f | %d%% | %.0f | %.1f | %.1f |" % [
			int(row["objective"]), RunData.OBJECTIVES[int(row["objective"])]["icon"], int(row["floor"]), int(row["budget"]),
			"yes" if bool(row["won"]) else "no", float(row["time"]), int(row["peak"]), float(row["avg"]),
			int(float(wins) / SIM_RUNS * 100.0), time_sum / SIM_RUNS, peak_sum / SIM_RUNS, avg_sum / SIM_RUNS])
	lines.append("")
	lines.append("## Measured speed (max |vx| / stats.speed) per unit")
	lines.append("")
	for key : String in speeds:
		lines.append("- %s: %.2f" % [key, float(speeds[key])])
	lines.append("")
	lines.append("## Enemies spawned in real battles")
	lines.append("")
	for row : Dictionary in all_rows:
		lines.append("- %s f%d %dg s%d: %s" % [RunData.OBJECTIVES[int(row["objective"])]["icon"], int(row["floor"]), int(row["budget"]), int(row["seed"]), JSON.stringify(row["spawned"])])
	lines.append("")
	lines.append("## Outcome detail (reason, objective progress, kills)")
	lines.append("")
	lines.append("| objective | floor | gears | seed | result | reason | t | limit | hunted | boss down | enemy base | defend left | escort max | ally base hp |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for row : Dictionary in all_rows:
		var info : Dictionary = row.get("progress", {})
		lines.append("| %s | %d | %d | %d | %s | %s | %.0f | %.0f | %d | %s | %d%% | %.0f | %d%% | %.0f |" % [
			RunData.OBJECTIVES[int(row["objective"])]["icon"], int(row["floor"]), int(row["budget"]), int(row["seed"]),
			"WON" if bool(row["won"]) else "LOST", str(row.get("reason", "?")), float(row["time"]),
			float(info.get("time_limit", 0.0)), int(info.get("hunted", 0)), "yes" if bool(info.get("boss_down", false)) else "no",
			int(float(info.get("enemy_base_frac", 1.0)) * 100.0), float(info.get("defend_left", 0.0)),
			int(float(info.get("escort_max", 0.0)) * 100.0), float(info.get("ally_base_hp", 0.0))])
	lines.append("")
	lines.append("### Loss reasons")
	lines.append("")
	var reasons : Dictionary = {}
	for row : Dictionary in all_rows:
		var tag : String = "%s %s" % [RunData.OBJECTIVES[int(row["objective"])]["icon"], str(row.get("reason", "?"))]
		reasons[tag] = int(reasons.get(tag, 0)) + 1
	for tag : String in reasons:
		lines.append("- %s: %d" % [tag, int(reasons[tag])])
	lines.append("")
	lines.append("### Deaths per unit type (ally = player losses, enemy = player kills)")
	lines.append("")
	for row : Dictionary in all_rows:
		lines.append("- %s f%d %dg s%d %s: %s" % [RunData.OBJECTIVES[int(row["objective"])]["icon"], int(row["floor"]), int(row["budget"]),
				int(row["seed"]), "WON" if bool(row["won"]) else "LOST", JSON.stringify(row.get("deaths", {}))])
	var file : FileAccess = FileAccess.open(OUT_DIR + "real_probe_latest.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("merged %d rows into real_probe_latest.md" % all_rows.size())
