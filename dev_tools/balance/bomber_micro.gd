extends Node

const OUT_FILE : String = "res://extras/balance_reports/bomber_micro_latest.md"
const SLOT : int = 97
const MAX_SECONDS : float = 45.0
var max_seconds : float = MAX_SECONDS
const SAMPLE_FRAMES : int = 30
const SUB_OFFSET_X : float = 160.0
const ALLY_OFFSET_X : float = -60.0

var only_units : Array[String] = []
var results : Array[Dictionary] = []

func _ready() -> void:
	for arg : String in OS.get_cmdline_user_args():
		if (arg.begins_with("units=")):
			for part : String in arg.substr(6).split(","):
				only_units.append(part)
	SaveManager.slot = SLOT
	for item : Variant in Global.CATALOG.units:
		var boat : BoatStats = item as BoatStats
		if (!only_units.is_empty() and !only_units.has(boat.name)):
			continue
		await _trial(boat)
	_write()
	for path : String in [SaveManager.save_path(SLOT), SaveManager.run_path(SLOT)]:
		if (FileAccess.file_exists(path)):
			DirAccess.remove_absolute(path)
	get_tree().quit()

func _trial(boat : BoatStats) -> void:
	var stats : PlayerStats = Global.player_stats.duplicate()
	stats.unlocked_entities = [boat]
	stats.loadout = [boat.name]
	stats.upgrade_levels = {}
	Global.player_stats = stats
	var run : RunState = RunState.create(777)
	Global.run = run
	var entry : Dictionary = run.map.get_node(0)
	entry["objective"] = RunData.Objective.DESTROY_BASE
	entry["col"] = 1
	entry["type"] = RunData.NodeType.BATTLE
	entry["weather"] = RunData.Weather.CLEAR
	run.pending_node = 0
	run.focus_node = 0
	run.stage = RunData.Stage.BRIEFING
	run.start_battle()
	var game : GameRound = load("res://scenes/ui/naval_hud/naval_round.tscn").instantiate() as GameRound
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	game.campaign.wave_manager.stop()
	game.campaign.set_process(false)
	game.enemy_base.set_process(false)
	game.enemy_base.set_physics_process(false)
	game.ally_base.set_process(false)
	game.ally_base.set_physics_process(false)
	var ships : ShipManager = game.get_node("ShipsManager") as ShipManager
	var ally_team : TeamStats = game.ally_base.team_stats
	var enemy_team : TeamStats = game.enemy_base.team_stats
	var mid_x : float = (game.ally_base.global_position.x + game.enemy_base.global_position.x) * 0.5
	var surface_y : float = game.enemy_base.get_spawn_point().y
	var sub_stats : BoatStats = (load("res://core/resources/boats/boss_heavy_bomber.tres") as BoatStats).duplicate()
	sub_stats.health *= 3.0
	var known : Dictionary = {}
	ships.child_entered_tree.connect(func(child : Node) -> void:
		known[child.get_instance_id()] = child)
	ships.handle_ship_spawn(Vector2(mid_x + 300.0, 130.0), sub_stats, enemy_team)
	ships.handle_ship_spawn(Vector2(mid_x + ALLY_OFFSET_X, surface_y), boat, ally_team)
	await get_tree().process_frame
	var sub : Entity = null
	var ally : Entity = null
	for node : Node in ships.get_children():
		var unit : Entity = node as Entity
		if (unit == null):
			continue
		if (unit.team_stats.team_id == 1):
			ally = unit
		else:
			sub = unit
	var shot_counter : Array[int] = [0]
	var los_samples : int = 0
	var samples : int = 0
	var hits_before : float = 0.0
	if (ally):
		ally.bullet_fired.connect(func(_b : Bullet, _d : Vector2, _p : Vector2, _r : float) -> void:
			shot_counter[0] += 1)
	var sub_health : HealthComponent = sub.get_node("HealthComponent") as HealthComponent
	var ally_health : HealthComponent = ally.get_node("HealthComponent") as HealthComponent
	var sub_max : float = sub_health.default_health
	var ally_max : float = ally_health.default_health
	var min_gap : float = 99999.0
	var kill_time : float = -1.0
	var ally_dead_time : float = -1.0
	var start_frame : int = Engine.get_physics_frames()
	var t : float = 0.0
	var sub_alive : bool = true
	var ally_alive : bool = true
	var last_sub_hp : float = sub_max
	var last_ally_hp : float = ally_max
	var submerged_seen : bool = false
	var trace : Array[String] = []
	while (t < MAX_SECONDS and (sub_alive or ally_alive)):
		for step : int in range(SAMPLE_FRAMES):
			await get_tree().physics_frame
		t = float(Engine.get_physics_frames() - start_frame) / 60.0
		if (sub_alive):
			if (!is_instance_valid(sub) or sub.is_queued_for_deletion()):
				sub_alive = false
				kill_time = t
				last_sub_hp = 0.0
			else:
				last_sub_hp = sub_health.actual_health
				submerged_seen = submerged_seen or sub.is_submerged()
		if (ally_alive):
			if (!is_instance_valid(ally) or ally.is_queued_for_deletion()):
				ally_alive = false
				ally_dead_time = t
				last_ally_hp = 0.0
			else:
				last_ally_hp = ally_health.actual_health
		if (sub_alive and ally_alive):
			min_gap = minf(min_gap, absf(sub.global_position.x - ally.global_position.x))
			var gun_note : String = ""
			var shots : int = shot_counter[0]
			samples += 1
			var any_los : bool = false
			for gun_node : Gun in (ally as ShipEntity).guns if ally is ShipEntity else []:
				var simple_gun : SimpleGun = gun_node as SimpleGun
				if (simple_gun and simple_gun.gun_line_of_sight.is_colliding()):
					any_los = true
			if (any_los):
				los_samples += 1
			var ship : ShipEntity = ally as ShipEntity
			if (ship and !ship.guns.is_empty()):
				var g : Gun = ship.guns[0]
				var simple : SimpleGun = g as SimpleGun
				var los : String = "n/a"
				var ray : String = ""
				if (simple):
					los = str(simple.gun_line_of_sight.is_colliding())
					ray = " ray_to=(%.0f,%.0f) mask=%d" % [simple.gun_line_of_sight.target_position.x, simple.gun_line_of_sight.target_position.y, simple.gun_line_of_sight.collision_mask]
				var state_name : String = ""
				if (ship.state_machine and ship.state_machine.current_state):
					state_name = String(ship.state_machine.current_state.name)
				gun_note = " gun0 can=%s dist=%.0f range=%.0f los=%s%s cd=%d enemy=%s state=%s rot=%.2f" % [str(g.can_target(sub)), g.target_distance(sub), g.effective_range(), los, ray, g.current_time_to_shoot, str(g.enemy != null), state_name, g.projectile_rotation_spawn]
			trace.append("t=%.1f dx=%.0f ally=(%.0f,%.0f) sub=(%.0f,%.0f) sub_sub=%s hp ally=%.0f sub=%.0f shots=%d%s" % [t,
				ally.global_position.x - sub.global_position.x, ally.global_position.x, ally.global_position.y, sub.global_position.x,
				sub.global_position.y, str(sub.is_submerged()), ally_health.actual_health, sub_health.actual_health, shots, gun_note])
		if (!sub_alive):
			break
	var unit_info : BalanceUnit = BalanceUnit.from_stats(boat)
	results.append({
		"unit": boat.name, "sub_gun": unit_info.dps("sub") > 0.0, "sub_dps": unit_info.dps("sub"),
		"shots": shot_counter[0], "los": "%d/%d" % [los_samples, samples], "sub_hp_left": last_sub_hp, "sub_max": sub_max, "killed": !sub_alive, "kill_time": kill_time,
		"ally_alive": ally_alive, "ally_dead_time": ally_dead_time, "ally_hp_left": last_ally_hp, "ally_max": ally_max,
		"min_gap": min_gap if min_gap < 99999.0 else -1.0, "submerged": submerged_seen, "t": t, "trace": trace,
	})
	var shots : int = shot_counter[0]
	print("MICRO %s shots=%d sub_hp=%.0f/%.0f killed=%s gap=%.0f" % [boat.name, shots, last_sub_hp, sub_max, str(!sub_alive), min_gap])
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _write() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://extras/balance_reports/"))
	var lines : PackedStringArray = []
	lines.append("# Submarine micro-test (real battle, 1 ally unit vs 1 submerged enemy submarine, no bases/waves)")
	lines.append("")
	lines.append("| unit | has sub gun | sub dps | shots fired | los samples | sub hp left | sub killed | kill time | closest x gap | ally survived | ally hp left | t |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
	for row : Dictionary in results:
		lines.append("| %s | %s | %.1f | %d | %s | %.0f/%.0f | %s | %.0f | %.0f | %s | %.0f/%.0f | %.0f |" % [
			row["unit"], "yes" if bool(row["sub_gun"]) else "no", float(row["sub_dps"]), int(row["shots"]), row["los"], float(row["sub_hp_left"]),
			float(row["sub_max"]), "yes" if bool(row["killed"]) else "no", float(row["kill_time"]), float(row["min_gap"]),
			"yes" if bool(row["ally_alive"]) else "no", float(row["ally_hp_left"]), float(row["ally_max"]), float(row["t"])])
	if (!only_units.is_empty()):
		for row : Dictionary in results:
			lines.append("")
			lines.append("### trace %s" % row["unit"])
			lines.append("```")
			lines.append("
".join(row["trace"]))
			lines.append("```")
	var file : FileAccess = FileAccess.open(OUT_FILE, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("wrote bomber_micro_latest.md")
