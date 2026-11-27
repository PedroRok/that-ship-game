extends Node

const OUT_ROOT : String = "res://extras/balance_reports/duel/"
const BASE_SLOT : int = 110
const MAX_SECONDS : float = 75.0
const SPAWN_GAP_FRAMES : int = 24
const UNITS : Array[String] = ["mini", "small", "torpedo", "medium", "destroyer", "frigate", "tank", "cruiser", "flak",
	"plane", "interceptor", "missile_plane", "bomber", "twin_bomber", "heli_scout", "heli_heavy",
	"sub_scout", "submarine", "sub_hunter", "sub_sam"]

var value : int = 60
var shard : int = 0
var shard_count : int = 1
var rows : Array[Dictionary] = []
var pairs : PackedStringArray = []
var tag : String = ""
var pairs_file : String = ""

func _ready() -> void:
	for arg : String in OS.get_cmdline_user_args():
		if (arg.begins_with("value=")):
			value = int(arg.substr(6))
		elif (arg.begins_with("pairsfile=")):
			pairs_file = arg.substr(10)
		elif (arg.begins_with("pairs=")):
			pairs = arg.substr(6).split(",")
		elif (arg.begins_with("tag=")):
			tag = arg.substr(4) + "_"
		elif (arg.begins_with("shard=")):
			shard = int(arg.substr(6).split("/")[0])
			shard_count = maxi(int(arg.substr(6).split("/")[1]), 1)
	SaveManager.slot = BASE_SLOT + shard
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_ROOT))
	if (!pairs_file.is_empty()):
		pairs = FileAccess.get_file_as_string(pairs_file).strip_edges().split(",")
	var matches : Array[PackedStringArray] = []
	for pair : String in pairs:
		matches.append(pair.split(":"))
	if (matches.is_empty()):
		for first : int in range(UNITS.size()):
			for second : int in range(first + 1, UNITS.size()):
				matches.append(PackedStringArray([UNITS[first], UNITS[second]]))
	for index : int in range(matches.size()):
		if (index % shard_count != shard):
			continue
		await _duel(matches[index][0], matches[index][1], false)
		await _duel(matches[index][0], matches[index][1], true)
		var file : FileAccess = FileAccess.open(OUT_ROOT + tag + "rows_%d.json" % shard, FileAccess.WRITE)
		file.store_string(JSON.stringify(rows))
		file.close()
	for path : String in [SaveManager.save_path(SaveManager.slot), SaveManager.run_path(SaveManager.slot)]:
		if (FileAccess.file_exists(path)):
			DirAccess.remove_absolute(path)
	get_tree().quit()

func _duel(first : String, second : String, swapped : bool) -> void:
	seed(hash(first + second) + int(swapped))
	var player : String = second if swapped else first
	var enemy : String = first if swapped else second
	var stats : PlayerStats = Global.player_stats.duplicate()
	stats.upgrade_levels = {}
	stats.unlocked_entities = []
	stats.loadout = []
	var teams : Array[PackedStringArray] = [player.split("+"), enemy.split("+")]
	for unit_name : String in Array(teams[0]) + Array(teams[1]):
		if (stats.loadout.has(unit_name)):
			continue
		stats.unlocked_entities.append(Global.CATALOG.find_unit(unit_name))
		stats.loadout.append(unit_name)
	Global.player_stats = stats
	var run : RunState = RunState.create(900)
	var entry : Dictionary = run.map.get_node(0)
	entry["objective"] = RunData.Objective.DESTROY_BASE
	entry["col"] = 1
	entry["type"] = RunData.NodeType.BATTLE
	entry["weather"] = RunData.Weather.CLEAR
	run.pending_node = 0
	run.focus_node = 0
	run.stage = RunData.Stage.BRIEFING
	run.start_battle()
	Global.run = run
	var game : GameRound = load("res://scenes/ui/naval_hud/naval_round.tscn").instantiate() as GameRound
	add_child(game)
	var mute : EnemyCommander = EnemyCommander.new()
	mute.setup(game.campaign.commander.base, RunData.Objective.DESTROY_BASE, 0.0, 1)
	mute.base = null
	game.campaign.commander = mute
	var orders : Array[Array] = [[], []]
	for side : int in range(2):
		var waiting : Array[Array] = []
		for unit_name : String in teams[side]:
			var boat : BoatStats = Global.CATALOG.find_unit(unit_name)
			var group : Array = []
			for index : int in maxi(roundi(float(value) / teams[side].size() / boat.price), 1):
				group.append(boat)
			waiting.append(group)
		var added : bool = true
		while (added):
			added = false
			for group : Array in waiting:
				if (!group.is_empty()):
					orders[side].append(group.pop_back())
					added = true
	var docks : Array[Array] = [[], []]
	for side : int in range(2):
		for unit_name : String in teams[side]:
			docks[side].append(Global.CATALOG.find_unit(unit_name))
	var ally_docks : Array[BoatStats] = []
	ally_docks.assign(docks[0])
	var enemy_docks : Array[BoatStats] = []
	enemy_docks.assign(docks[1])
	game.ally_base.show_docks_for(ally_docks)
	game.enemy_base.show_docks_for(enemy_docks)
	await get_tree().process_frame
	var ships : ShipManager = game.get_node("ShipsManager") as ShipManager
	var bases : Array[Base] = [game.ally_base, game.enemy_base]
	var counts : Array[int] = [orders[0].size(), orders[1].size()]
	var spawned : Array[int] = [0, 0]
	var frame : int = 0
	var left : Array[float] = [1.0, 1.0]
	var contact : bool = false
	while (frame < int(MAX_SECONDS * 60.0)):
		if (frame % SPAWN_GAP_FRAMES == 0):
			for side : int in range(2):
				if (spawned[side] < counts[side]):
					var boat : BoatStats = orders[side][spawned[side]] as BoatStats
					var constructor : Node2D = bases[side].constructors[Base.dock_type_of(boat)] as Node2D
					ships.handle_ship_spawn(constructor.global_position, boat, bases[side].team_stats)
					spawned[side] += 1
		await get_tree().physics_frame
		frame += 1
		if (frame % 30 != 0):
			continue
		var health : Array[float] = [0.0, 0.0]
		for unit : Entity in BattleContext.of(game).entities:
			if (!is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.destroyed):
				continue
			var side : int = 0 if unit.team_stats.team_id == 1 else 1
			var component : HealthComponent = unit.get_node_or_null("HealthComponent") as HealthComponent
			health[side] += clampf(component.actual_health / maxf(component.default_health, 1.0), 0.0, 1.0) if component else 1.0
		for side : int in range(2):
			left[side] = (health[side] + float(counts[side] - spawned[side])) / counts[side]
			contact = contact or left[side] < 0.999
		if ((left[0] <= 0.0 or left[1] <= 0.0) and spawned[0] == counts[0] and spawned[1] == counts[1]):
			break
	var first_side : int = 1 if swapped else 0
	rows.append({"a": first, "b": second, "swapped": swapped, "a_left": snappedf(left[first_side], 0.01),
		"b_left": snappedf(left[1 - first_side], 0.01), "a_count": counts[first_side], "b_count": counts[1 - first_side],
		"time": snappedf(frame / 60.0, 0.1), "contact": contact})
	print("DUEL %s(%.2f) vs %s(%.2f) swapped=%s t=%.0f" % [first, left[first_side], second, left[1 - first_side], str(swapped), frame / 60.0])
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
