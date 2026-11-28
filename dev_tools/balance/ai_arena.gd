extends Node

const PlayerBot : GDScript = preload("res://dev_tools/balance/player_bot.gd")
const Variants : GDScript = preload("res://dev_tools/balance/enemy_variants.gd")
const OUT_ROOT : String = "res://extras/balance_reports/arena/"
const BASE_SLOT : int = 94
const ENDLESS : int = 6
const ENDLESS_CAP : float = 480.0
const CAMPAIGN_CAP : float = 700.0
const SAMPLE_FRAMES : int = 15
const FLEETS : Dictionary = {
	"early": ["mini", "small", "torpedo", "plane", "flak"],
	"navy": ["torpedo", "medium", "flak", "destroyer", "frigate", "tank", "cruiser"],
	"air": ["plane", "bomber", "interceptor", "missile_plane", "twin_bomber", "heli_scout", "heli_heavy", "flak"],
	"deep": ["torpedo", "sub_scout", "submarine", "sub_hunter", "sub_sam", "flak", "interceptor"],
}

const EscortProbe : GDScript = preload("res://dev_tools/balance/escort_probe.gd")

const SKILL_SLOT_LIMIT : int = 10

var ais : Array[String] = ["current"]
var bots : Array[String] = ["adaptive"]
var objectives : Array[int] = [0, 1, 2, 3, 4, 5, ENDLESS]
var floors : Array[int] = [1]
var fleets : Array[String] = ["early"]
var skill_names : Array[String] = []
var seeds : int = 1
var seed_first : int = 0
var params_path : String = ""
var gears : int = 400
var escort_speed : float = 0.0
var escort_health : float = 0.0
var escort_air : float = 1.0
var escort_health_scale : float = 1.0
var tag : String = "test"
var shard : int = 0
var shard_count : int = 1
var slot_override : int = -1
var elite : bool = false
var risk_names : Array[String] = []
var rows : Array[Dictionary] = []
var template : PlayerStats

func _ready() -> void:
	_parse_args()
	SaveManager.slot = slot_override if slot_override >= 90 else BASE_SLOT + shard
	get_window().size = Vector2i(1280, 720)
	template = Global.player_stats
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_ROOT + tag))
	var scenarios : Array[Dictionary] = _build_scenarios()
	var done : Dictionary = _load_done()
	for scenario : Dictionary in scenarios:
		if (done.has(_key(scenario))):
			continue
		await _play(scenario)
		_save_rows()
	for path : String in [SaveManager.save_path(SaveManager.slot), SaveManager.run_path(SaveManager.slot)]:
		if (FileAccess.file_exists(path)):
			DirAccess.remove_absolute(path)
	get_tree().quit()

func _parse_args() -> void:
	for arg : String in OS.get_cmdline_user_args():
		var parts : PackedStringArray = arg.split("=")
		if (parts.size() != 2):
			continue
		var value : String = parts[1]
		match parts[0]:
			"ai":
				ais = _strings(value)
			"bot":
				bots = _strings(value)
			"fleet":
				fleets = _strings(value)
			"skills":
				skill_names = _strings(value)
			"obj":
				objectives = _ints(value)
			"floors":
				floors = _ints(value)
			"seeds":
				seeds = int(value)
			"seed0":
				seed_first = int(value)
			"params":
				params_path = value
			"eair":
				escort_air = float(value)
			"ehpx":
				escort_health_scale = float(value)
			"espeed":
				escort_speed = float(value)
			"ehp":
				escort_health = float(value)
			"gears":
				gears = int(value)
			"slot":
				slot_override = int(value)
			"elite":
				elite = value == "1"
			"risks":
				risk_names = _strings(value)
			"tag":
				tag = value
			"shard":
				shard = int(value.split("/")[0])
				shard_count = maxi(int(value.split("/")[1]), 1)

func _strings(text : String) -> Array[String]:
	var result : Array[String] = []
	for part : String in text.split(","):
		result.append(part)
	return result

func _ints(text : String) -> Array[int]:
	var result : Array[int] = []
	for part : String in text.split(","):
		result.append(int(part))
	return result

func _build_scenarios() -> Array[Dictionary]:
	var cells : Array[Dictionary] = []
	for seed_index : int in range(seed_first, seed_first + seeds):
		var block : Array[Dictionary] = []
		for objective : int in objectives:
			for floor_index : int in floors:
				if (objective == ENDLESS and floor_index != floors[0]):
					continue
				for fleet : String in fleets:
					block.append({"objective": objective, "floor": floor_index, "fleet": fleet, "seed": seed_index})
		var rng : RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 77 + seed_index
		while (!block.is_empty()):
			cells.append(block.pop_at(rng.randi_range(0, block.size() - 1)))
	var result : Array[Dictionary] = []
	var index : int = 0
	for cell : Dictionary in cells:
		for bot : String in bots:
			for ai : String in ais:
				if (index % shard_count == shard):
					var scenario : Dictionary = cell.duplicate()
					scenario["bot"] = bot
					scenario["ai"] = ai
					result.append(scenario)
				index += 1
	return result

func _key(row : Dictionary) -> String:
	return "%d %d %s %s %s %d" % [int(row["objective"]), int(row["floor"]), row["fleet"], row["bot"], row["ai"], int(row["seed"])]

func _load_done() -> Dictionary:
	var done : Dictionary = {}
	var path : String = OUT_ROOT + tag + "/rows_%d.json" % shard
	if (!FileAccess.file_exists(path)):
		return done
	var parsed : Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if (parsed is Array):
		for item : Variant in parsed as Array:
			var row : Dictionary = item
			rows.append(row)
			done[_key(row)] = true
	return done

func _fleet_names(fleet_name : String) -> Array:
	if (fleet_name.begins_with("x:")):
		return Array(fleet_name.substr(2).split("+"))
	return FLEETS[fleet_name]

func _load_params(bot : RefCounted) -> void:
	if (params_path.is_empty()):
		return
	var data : Dictionary = JSON.parse_string(FileAccess.get_file_as_string(params_path))
	var current : Dictionary = bot.get("params")
	current.merge(data.get("params", {}) as Dictionary, true)
	bot.set("weights", data.get("weights", {}))

func _play(scenario : Dictionary) -> void:
	var objective : int = int(scenario["objective"])
	var floor_index : int = int(scenario["floor"])
	var seed_index : int = int(scenario["seed"])
	var base_seed : int = 500 + objective * 13 + floor_index * 7 + seed_index * 97
	seed(base_seed)
	var progress : BalanceProgress = BalanceProgress.build(Global.CATALOG, gears, gears / 250)
	var stats : PlayerStats = template.duplicate()
	stats.unlocked_entities = []
	stats.loadout = []
	stats.start_screw = BalanceFleet.START_SCREWS
	stats.upgrade_levels = progress.levels.duplicate()
	stats.campaigns_started = 2
	var fleet : Array[BalanceUnit] = []
	for unit_name : String in _fleet_names(String(scenario["fleet"])):
		var boat : BoatStats = Global.CATALOG.find_unit(unit_name)
		stats.unlocked_entities.append(boat)
		stats.loadout.append(unit_name)
		fleet.append(BalanceFleet.profile_of(boat))
	for skill_name : String in skill_names:
		if (stats.loadout.size() >= SKILL_SLOT_LIMIT):
			stats.loadout.pop_back()
			fleet.pop_back()
		stats.loadout.insert(0, SkillCatalog.PREFIX + skill_name)
		var skill : SkillStats = SkillCatalog.find(SkillCatalog.PREFIX + skill_name)
		if (skill.unlock_id != &""):
			stats.upgrade_levels[skill.unlock_id] = maxi(int(stats.upgrade_levels.get(skill.unlock_id, 0)), 1)
	Global.player_stats = stats
	var run : RunState = null
	if (objective != ENDLESS):
		run = RunState.create(base_seed)
		var node_id : int = RunData.BOSS_ID if objective == RunData.Objective.DEFEAT_BOSS else 0
		var entry : Dictionary = run.map.get_node(node_id)
		entry["objective"] = objective
		entry["col"] = floor_index
		entry["type"] = RunData.NodeType.BOSS if objective == RunData.Objective.DEFEAT_BOSS else (RunData.NodeType.ELITE if elite else RunData.NodeType.BATTLE)
		entry["weather"] = RunData.Weather.CLEAR
		run.pending_node = node_id
		run.focus_node = node_id
		run.stage = RunData.Stage.BRIEFING
		for risk_name : String in risk_names:
			if (!run.toggle_risk(StringName(risk_name))):
				push_error("ARENA risk not applied: " + risk_name)
		run.start_battle()
	Global.run = run
	var game : GameRound = load("res://scenes/ui/naval_hud/naval_round.tscn").instantiate() as GameRound
	add_child(game)
	var commander : EnemyCommander = _install(game, String(scenario["ai"]), base_seed)
	await get_tree().process_frame
	var bot : RefCounted = PlayerBot.new()
	bot.setup(String(scenario["bot"]), fleet, base_seed + 1)
	_load_params(bot)
	var probe : RefCounted = EscortProbe.new()
	probe.call("start", get_tree())
	probe.set("air_mult", escort_air)
	probe.set("health_scale", escort_health_scale)
	var skill_log : Array = []
	var first_frame : int = Engine.get_physics_frames()
	if (game.skill_manager):
		game.skill_manager.skill_used.connect(func(id : StringName, _where : Vector2) -> void:
			skill_log.append([snappedf(float(Engine.get_physics_frames() - first_frame) / 60.0, 0.1), String(id)]))
	var tracker : Dictionary = {"built": {}, "lost": {}, "enemy_built": {}, "enemy_lost": {}, "reason": "", "seen": {}}
	var ships : ShipManager = game.get_node("ShipsManager") as ShipManager
	ships.unit_destroyed.connect(func(unit_stats : EntityStats, team : TeamStats) -> void:
		var table : Dictionary = tracker["lost" if team.team_id == 1 else "enemy_lost"]
		table[unit_stats.name] = int(table.get(unit_stats.name, 0)) + 1)
	game.ally_base.death_event.connect(func(_team : TeamStats) -> void:
		tracker["reason"] = "base_destroyed")
	var ally_max : float = maxf(game.ally_base.health_component.health, 1.0)
	var enemy_max : float = maxf(game.enemy_base.health_component.health, 1.0)
	var cap : float = ENDLESS_CAP if objective == ENDLESS else CAMPAIGN_CAP
	var start_frame : int = Engine.get_physics_frames()
	var game_time : float = 0.0
	var peak : int = 0
	var view : Dictionary = {}
	var eco : Dictionary = {"income": 0.0, "spent": 0.0, "bank": 0.0, "samples": 0, "docks": {}}
	var bank : float = -1.0
	while (!_finished(game, run) and game_time < cap):
		for step : int in range(SAMPLE_FRAMES):
			await get_tree().physics_frame
		var now : float = float(Engine.get_physics_frames() - start_frame) / 60.0
		var delta : float = now - game_time
		game_time = now
		if (_finished(game, run)):
			break
		view = _observe(game, tracker, ally_max, enemy_max)
		peak = maxi(peak, int(view["enemy_count"]))
		bank = _step_with_economy(bot, delta, game, view, eco, bank)
		_track_objective(game, tracker)
		if (game.campaign and is_instance_valid(game.campaign.escort)):
			probe.call("tick", game, game.campaign.escort, float(tracker.get("escort_progress", 0.0)))
	probe.call("stop")
	var success : bool = false
	if (objective == ENDLESS):
		success = game_time >= cap
	else:
		success = bool(run.node_result.get("success", false)) and run.stage != RunData.Stage.ENDED or run.result == RunData.Result.WON
	var reason : String = String(tracker["reason"])
	if (success):
		reason = "won"
	elif (reason.is_empty()):
		reason = "objective_or_timeout" if game_time < cap else "cap"
	var ally_hp : float = 1.0
	var enemy_hp : float = 1.0
	if (!view.is_empty()):
		ally_hp = float(view["ally_hp"])
		enemy_hp = float(view["enemy_hp"])
	if (reason == "base_destroyed"):
		ally_hp = 0.0
	var row : Dictionary = scenario.duplicate()
	row.merge({
		"won": success, "reason": reason, "time": snappedf(game_time, 0.1), "ally_hp": snappedf(ally_hp, 0.01),
		"enemy_hp": snappedf(enemy_hp, 0.01), "peak": peak, "switches": bot.switches, "styles": bot.style_seconds,
		"skills": bot.skills_used, "built": tracker["built"], "lost": tracker["lost"],
		"enemy_built": tracker["enemy_built"], "enemy_lost": tracker["enemy_lost"],
		"ai_switches": int(commander.get("doctrine_switches")) if commander.get("doctrine_switches") != null else 0,
	})
	row.merge({"espeed": escort_speed, "ehp": escort_health, "escort_progress": snappedf(float(tracker.get("escort_progress", 0.0)), 0.01),
		"retreats": int(tracker.get("retreats", 0)), "bomber_seen": float(tracker.get("bomber_seen", -1.0)),
		"dmg_with_bomber": snappedf(float(tracker.get("dmg_with_bomber", 0.0)), 0.1),
		"dmg_other": snappedf(float(tracker.get("dmg_other", 0.0)), 0.1)})
	row["escort_damage"] = probe.call("report")
	row.merge({"elite": elite, "risks": risk_names, "skill_log": skill_log, "gears": gears,
		"supply_screws": int(bot.skills_used["supply"]) * int(Global.modify(Enums.UpgradeTarget.SKILL, &"supply_amount", SkillManager.SUPPLY_AMOUNT)),
		"bosses_required": game.campaign.bosses_required if game.campaign else 0,
		"enemy_health_mult": (game.campaign.wave_manager.table as RunWaveTable).base_health_mult if game.campaign else 1.0})
	row["eco"] = eco
	row["cancels"] = bot.cancels
	row.merge({"eair": escort_air, "ehpx": escort_health_scale})
	rows.append(row)
	print("ARENA %s obj=%d f=%d fleet=%s bot=%s ai=%s s=%d won=%s t=%.0f hp=%.2f" % [tag, objective, floor_index,
			scenario["fleet"], scenario["bot"], scenario["ai"], seed_index, str(success), game_time, ally_hp])
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _step_with_economy(bot : RefCounted, delta : float, game : GameRound, view : Dictionary, eco : Dictionary, last : float) -> float:
	var ui : GameUI = game.get_node_or_null("CanvasLayer/GameUI") as GameUI
	if (!ui):
		bot.step(delta, game, view)
		return last
	var before : float = float(ui.screw_label.total_value)
	if (last >= 0.0):
		eco["income"] = float(eco["income"]) + before - last
	eco["bank"] = float(eco["bank"]) + before
	eco["samples"] = int(eco["samples"]) + 1
	var docks : Dictionary = eco["docks"]
	for dock_type : int in ui.base.constructors:
		if (ui.base.docks.has(dock_type) and !(ui.base.docks[dock_type] as BaseDock).active):
			continue
		var key : String = ["naval", "air", "sub"][[BaseDock.Type.NAVAL, BaseDock.Type.AIR, BaseDock.Type.SUB].find(dock_type)]
		var entry : Dictionary = docks.get(key, {"idle": 0, "full": 0, "queued": 0})
		var used : int = ui.base.queue_used(dock_type as BaseDock.Type)
		entry["idle"] = int(entry["idle"]) + int(used == 0)
		entry["full"] = int(entry["full"]) + int(!ui.base.queue_has_room(dock_type as BaseDock.Type))
		entry["queued"] = int(entry["queued"]) + used
		docks[key] = entry
	bot.step(delta, game, view)
	var after : float = float(ui.screw_label.total_value)
	eco["spent"] = float(eco["spent"]) + before - after
	return after

func _track_objective(game : GameRound, tracker : Dictionary) -> void:
	var battle : CampaignBattle = game.campaign
	if (battle == null):
		return
	var ally_x : float = game.ally_base.global_position.x
	var span : float = maxf(game.enemy_base.global_position.x - ally_x, 1.0)
	var escort : Entity = battle.escort if is_instance_valid(battle.escort) else null
	if (escort):
		if (!tracker.has("escort_patched")):
			tracker["escort_patched"] = true
			if (escort_speed > 0.0):
				escort.entity_stats.speed = escort_speed
			if (escort_health > 0.0):
				var component : HealthComponent = escort.get_node("HealthComponent") as HealthComponent
				component.default_health = escort_health
				component.actual_health = escort_health
		tracker["escort_progress"] = maxf(float(tracker.get("escort_progress", 0.0)),
				(escort.global_position.x - ally_x) / span / RunData.ESCORT_GOAL)
	var bomber_close : bool = false
	for unit : Entity in BattleContext.of(game).entities:
		var plane : AirEntity = unit as AirEntity
		if (!is_instance_valid(plane) or plane.entity_stats == null or plane.entity_stats.name != RunData.BOMBER_BOSS_NAME):
			continue
		if (!tracker.has("bomber_seen")):
			tracker["bomber_seen"] = snappedf(battle.elapsed, 0.1)
		tracker["retreats"] = plane.retreat_stage
		bomber_close = plane.global_position.x - ally_x < 320.0
	var health : float = game.ally_base.health_component.health
	var lost : float = maxf(float(tracker.get("base_before", health)) - health, 0.0)
	tracker["base_before"] = health
	var key : String = "dmg_with_bomber" if bomber_close else "dmg_other"
	tracker[key] = float(tracker.get(key, 0.0)) + lost

func _install(game : GameRound, ai : String, seed_value : int) -> EnemyCommander:
	var old : EnemyCommander = game.campaign.commander if game.campaign else game.endless.commander
	var fresh : EnemyCommander = Variants.make(ai)
	fresh.setup(old.base, old.objective, old.base_rate, seed_value)
	fresh.counter_bonus = old.counter_bonus
	if (old.opening_strike):
		fresh.start_opening()
	if (fresh.get("ally_max") != null):
		fresh.set("ally_base", game.ally_base)
		fresh.set("ally_max", maxf(game.ally_base.health_component.health, 1.0))
	if (game.campaign):
		game.campaign.commander = fresh
	else:
		game.endless.commander = fresh
	return fresh

func _finished(game : GameRound, run : RunState) -> bool:
	if (run == null):
		return game.game_ended
	return run.stage != RunData.Stage.BATTLE

func _observe(game : GameRound, tracker : Dictionary, ally_max : float, enemy_max : float) -> Dictionary:
	var context : BattleContext = BattleContext.of(game)
	var ally_x : float = game.ally_base.global_position.x
	var enemy_x : float = game.enemy_base.global_position.x
	var span : float = maxf(enemy_x - ally_x, 1.0)
	var view : Dictionary = {"front": 0.0, "front_enemy": 0.0, "ally_value": 0.0, "enemy_value": 0.0, "enemy_air": 0.0,
		"enemy_sub": 0.0, "answer_air": 0.0, "answer_sub": 0.0, "enemy_classes": {}, "enemy_count": 0,
		"cluster": {"value": 0.0, "position": Vector2.ZERO}, "progress": 0.0}
	var enemies : Array[Entity] = []
	var seen : Dictionary = tracker["seen"]
	for unit : Entity in context.entities:
		if (!is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.entity_stats == null):
			continue
		var boat : BoatStats = unit.entity_stats as BoatStats
		var unit_name : String = unit.entity_stats.name
		if (unit_name == "escort"):
			continue
		var price : float = float(boat.price if boat else 0)
		var ally : bool = unit.team_stats.team_id == 1
		if (!seen.has(unit.get_instance_id())):
			seen[unit.get_instance_id()] = true
			var table : Dictionary = tracker["built" if ally else "enemy_built"]
			table[unit_name] = int(table.get(unit_name, 0)) + 1
		var progress : float = clampf((unit.global_position.x - ally_x) / span, 0.0, 1.0)
		if (ally):
			view["ally_value"] = float(view["ally_value"]) + price
			view["front"] = maxf(float(view["front"]), progress)
			var profile : BalanceUnit = BalanceFleet.profile_of(boat) if boat else null
			if (profile):
				for kind : String in ["air", "sub"]:
					if (profile.hits(kind)):
						view["answer_" + kind] = float(view["answer_" + kind]) + price
		else:
			enemies.append(unit)
			price = maxf(price, 10.0) if boat and boat.is_boss else price
			var kind : String = "surface"
			if (unit.entity_stats is AirPlaneState):
				kind = "air"
			elif (boat and boat.can_submerge):
				kind = "sub"
			view["enemy_value"] = float(view["enemy_value"]) + price
			view["enemy_count"] = int(view["enemy_count"]) + 1
			view["front_enemy"] = maxf(float(view["front_enemy"]), 1.0 - progress)
			if (kind != "surface"):
				view["enemy_" + kind] = float(view["enemy_" + kind]) + price
			var classes : Dictionary = view["enemy_classes"]
			var key : String = "%d_%s" % [int(unit.entity_stats.unit_class), kind]
			if (!classes.has(key)):
				classes[key] = {"class": int(unit.entity_stats.unit_class), "kind": kind, "value": 0.0}
			classes[key]["value"] = float(classes[key]["value"]) + price
	for center : Entity in enemies:
		var value : float = 0.0
		for other : Entity in enemies:
			if (absf(other.global_position.x - center.global_position.x) <= SkillManager.BOMB_SPREAD
					and !(other.entity_stats is AirPlaneState) and !other.is_submerged()):
				var other_boat : BoatStats = other.entity_stats as BoatStats
				value += float(other_boat.price if other_boat else 0)
		if (value > float(view["cluster"]["value"])):
			view["cluster"] = {"value": value, "position": center.global_position}
	view["ally_hp"] = clampf(game.ally_base.health_component.health / ally_max, 0.0, 1.0)
	view["enemy_hp"] = clampf(game.enemy_base.health_component.health / enemy_max, 0.0, 1.0)
	var battle : CampaignBattle = game.campaign
	if (battle):
		match battle.objective:
			RunData.Objective.DEFEND:
				view["progress"] = (battle.ally_hold - battle.enemy_hold) / maxf(battle.defend_target, 1.0)
			RunData.Objective.HUNT_SUBMARINE:
				view["progress"] = float(battle.hunted) / RunData.HUNT_TARGET
	return view

func _save_rows() -> void:
	var file : FileAccess = FileAccess.open(OUT_ROOT + tag + "/rows_%d.json" % shard, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows))
	file.close()
