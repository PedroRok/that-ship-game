class_name CampaignBattle
extends Node

const FORCED_BOSS_SPACING : float = 130.0
const WARNING_COOLDOWN : float = 25.0
const WARNING_AIR_COUNT : int = 2
const WARNING_SUB_COUNT : int = 1
const RUN_END_OVERLAY = preload("res://scenes/ui/pause/run_end_overlay.gd")

var game_round : GameRound
var run : RunState
var entry : Dictionary
var objective : int
var ally_base : Base
var enemy_base : AutoBase
var ships_manager : ShipManager
var wave_manager : WaveManager
var hud : ObjectiveHud
var markers : ObjectiveMarkers
var weather_layer : WeatherLayer
var defense_point : DefensePoint
var escort : Entity
var commander : EnemyCommander = EnemyCommander.new()
var _commander_clock : float = 0.0

var done : bool = false
var boss_defeated : bool = false
var bosses_killed : int = 0
var bosses_required : int = 1
var objective_bosses_down : int = 0
var hunted : int = 0
var elapsed : float = 0.0
var time_limit : float = 0.0
var defend_left : float = 0.0
var defend_prep : float = 0.0
var defend_target : float = 0.0
var ally_hold : float = 0.0
var enemy_hold : float = 0.0
var contested : bool = false
var enemy_hp_max : float = 1.0
var _built : Dictionary = {}
var _enemy_spawned : Dictionary = {}
var _ally_lost : Dictionary = {}
var _enemy_lost : Dictionary = {}
var _fleet : Array[String] = []
var _start_hp : int = 0
var _warned_at : Dictionary = {}
var _threat_present : Dictionary = {}
var _enemy_base_destroyed : bool = false
var _timeline : Array[Dictionary] = []
var _timeline_clock : float = 0.0
var _alert_shown : int = 0
var _held_boss : BoatStats
var _bosses_forced : bool = false

func setup(round_node : GameRound, new_run : RunState) -> void:
	game_round = round_node
	run = new_run
	entry = run.map.get_node(run.pending_node)
	objective = int(entry["objective"])
	ally_base = game_round.ally_base
	enemy_base = game_round.enemy_base as AutoBase
	ships_manager = game_round.get_node("ShipsManager") as ShipManager
	name = "CampaignBattle"
	game_round.add_child(self)
	_start_hp = run.base_hp
	for stats : EntityStats in Global.player_stats.loadout_entities():
		_fleet.append(stats.name)
	ally_base.health_component.health = float(run.base_hp)
	ally_base.health_component.label.text = str(run.base_hp)
	ally_base._max_health = maxf(float(run.base_max_hp), 1.0)
	ally_base.update_damage_visual()
	ally_base.death_event.connect(_on_base_death)
	enemy_base.death_event.connect(_on_base_death)
	ships_manager.boss_defeated.connect(_on_boss_defeated)
	ships_manager.unit_destroyed.connect(_on_unit_destroyed)
	ships_manager.child_entered_tree.connect(_on_ship_added)
	var time_mult : float = run.modify(RunData.T_RUN, &"time_mult", 1.0)
	if (objective == RunData.Objective.DEFEND):
		defend_left = RunData.DEFEND_LIMIT_SECONDS * time_mult
		defend_target = RunData.DEFEND_HOLD_SECONDS * time_mult
		defend_prep = RunData.DEFEND_PREP_SECONDS
		time_limit = 0.0
	else:
		time_limit = float(RunData.TIME_LIMITS.get(objective, 0.0)) * time_mult
	_build_waves()
	_build_overlays()
	var indicator : DockIndicator = DockIndicator.new()
	indicator.name = "DockIndicator"
	indicator.enemy_base = enemy_base
	game_round.canvas_layer.add_child(indicator)
	var info : BattleInfoPanel = BattleInfoPanel.create(hud,
			EnemyRosterPanel.create(wave_manager.table.get_wave(0).ships, RunBattleConfig.boss_for(entry)))
	info.name = "BattleInfo"
	info.weather = run.battle_weather()
	game_round.canvas_layer.add_child(info)
	_start_objective()
	if (BattleIntro.should_show()):
		BattleIntro.show_for.call_deferred(game_round, wave_manager.table.get_wave(0).ships, RunBattleConfig.boss_for(entry), objective)

func _build_waves() -> void:
	wave_manager = WaveManager.new()
	wave_manager.table = RunBattleConfig.build_table(run, entry)
	wave_manager.enemy_base = enemy_base
	var is_boss_node : bool = int(entry["type"]) == RunData.NodeType.BOSS
	commander.setup(enemy_base, objective, EnemyCommander.rate_for(int(entry["col"]), is_boss_node), run.seed_value + run.pending_node)
	var first_steps : bool = Global.player_stats.campaigns_started <= 1 and int(entry["col"]) == 0
	commander.roll_opening(!is_boss_node and !first_steps and RunBattleConfig.boss_for(entry) == null)
	add_child(wave_manager)
	wave_manager.wave_started.connect(game_round._on_wave_started)
	wave_manager.start()
	if (objective == RunData.Objective.SHOOT_DOWN_BOMBER):
		_held_boss = enemy_base.pending_bosses.pop_front()
	if (objective == RunData.Objective.SHOOT_DOWN_BOMBER or objective == RunData.Objective.DEFEAT_BOSS):
		if ((wave_manager.table as RunWaveTable).extra_boss):
			bosses_required = 2
		(enemy_base.health_component as BaseHealthComponent).damaged.connect(_on_enemy_base_damaged)
	enemy_hp_max = maxf(enemy_base.health_component.health, 1.0)
	var floor_index : int = clampi(int(entry["col"]), 0, RunData.ENEMY_LIVE_CAP.size() - 1)
	enemy_base.live_cap = RunData.ENEMY_LIVE_CAP[floor_index]
	enemy_base.sub_cap = RunData.HUNT_SUB_CAP if objective == RunData.Objective.HUNT_SUBMARINE else 0

func _build_overlays() -> void:
	var canvas : CanvasLayer = game_round.canvas_layer
	hud = ObjectiveHud.new()
	hud.setup(objective)
	hud.set_floor(int(entry["col"]) + 1)
	hud.custom_minimum_size = Vector2(360, 0)
	markers = ObjectiveMarkers.new()
	markers.provider = _marker_targets
	canvas.add_child(markers)
	weather_layer = WeatherLayer.new()
	weather_layer.setup(run.battle_weather(), canvas)
	game_round.add_child(weather_layer)
	game_round.move_child(weather_layer, canvas.get_index())

func _start_objective() -> void:
	match objective:
		RunData.Objective.DEFEND:
			defense_point = DefensePoint.new()
			defense_point.water = game_round.get_node("Environment/Water_Body") as WaterBody
			game_round.add_child(defense_point)
			var from : Vector2 = ally_base.global_position
			var to : Vector2 = enemy_base.global_position
			defense_point.global_position = Vector2((from.x + to.x) * 0.5, ally_base.get_spawn_point().y)
			BattleContext.of(self).patrol_x = defense_point.global_position.x
		RunData.Objective.ESCORT:
			ships_manager.handle_ship_spawn(ally_base.get_spawn_point(), RunBattleConfig.escort_stats(), ally_base.team_stats)

func _on_ship_added(child : Node) -> void:
	var unit : Entity = child as Entity
	var plane : AirEntity = child as AirEntity
	if (plane and plane.entity_stats and plane.entity_stats.name == RunData.BOMBER_BOSS_NAME):
		plane.retreat_enabled = true
		_spare_base.call_deferred(plane)
		plane.loiter_min_x = ally_base.global_position.x + RunData.BOMBER_LOITER_BASE_GAP
		plane.loiter_max_x = (ally_base.global_position.x + enemy_base.global_position.x) * 0.5
	if (unit and unit.entity_stats and unit.team_stats):
		_count(_built if unit.team_stats.team_id == 1 else _enemy_spawned, unit.entity_stats.name)
	if (unit and unit.entity_stats and unit.entity_stats.name == "escort" and unit.team_stats.team_id == 1):
		escort = unit

func _spare_base(plane : AirEntity) -> void:
	if (!is_instance_valid(plane)):
		return
	for gun : Gun in plane.get_guns():
		gun.base_damage_mult = 0.0

func _process(delta : float) -> void:
	if (done):
		return
	elapsed += delta
	if (_held_boss and elapsed >= RunData.BOMBER_ARRIVAL_SECONDS):
		enemy_base.pending_bosses.append(_held_boss)
		_held_boss = null
		_show_warning("battle.bomber_incoming")
	commander.tick(delta)
	_timeline_clock += delta
	if (_timeline_clock >= RunData.LOG_SAMPLE_SECONDS):
		_timeline_clock -= RunData.LOG_SAMPLE_SECONDS
		_sample_timeline()
	_process_commander(delta)
	match objective:
		RunData.Objective.DEFEND:
			_process_defend(delta)
		RunData.Objective.ESCORT:
			_process_escort()
		RunData.Objective.HUNT_SUBMARINE:
			hud.counter = "%d/%d" % [mini(hunted, RunData.HUNT_TARGET), RunData.HUNT_TARGET]
			_update_hud(Loc.t("battle.hunt") % [hunted, RunData.HUNT_TARGET], float(hunted) / RunData.HUNT_TARGET)
			if (hunted >= RunData.HUNT_TARGET):
				_finish(true)
		RunData.Objective.SHOOT_DOWN_BOMBER:
			hud.counter = "%d/%d" % [objective_bosses_down, bosses_required]
			var headline : String = Loc.t("battle.bomber_down") % Loc.t("common.yes" if boss_defeated else "common.no")
			if (_held_boss):
				headline = Loc.t("battle.bomber_eta") % ceili(maxf(RunData.BOMBER_ARRIVAL_SECONDS - elapsed, 0.0))
			_update_hud(headline, 1.0 if boss_defeated else 0.0)
		RunData.Objective.DEFEAT_BOSS:
			hud.counter = "%d/%d" % [objective_bosses_down, bosses_required]
			_update_hud(Loc.t("battle.boss") % Loc.t("battle.down" if boss_defeated else "battle.alive"),
					float(objective_bosses_down) / float(bosses_required))
		_:
			var hp : float = clampf(enemy_base.health_component.health / enemy_hp_max, 0.0, 1.0)
			_update_hud(Loc.t("battle.enemy_base") % int(round(hp * 100.0)), 1.0 - hp)
	if (done):
		return
	if (time_limit > 0.0 and elapsed >= time_limit):
		_finish(false)

func _process_commander(delta : float) -> void:
	_commander_clock += delta
	if (_commander_clock < RunData.COMMANDER_SAMPLE_SECONDS):
		return
	var step : float = _commander_clock
	_commander_clock = 0.0
	var allies : int = 0
	var enemies : int = 0
	var enemy_air : int = 0
	var enemy_subs : int = 0
	var context : BattleContext = BattleContext.of(self)
	if (context):
		for unit : Entity in context.entities:
			if (!is_instance_valid(unit) or unit.is_queued_for_deletion()):
				continue
			if (unit.team_stats.team_id == 1):
				if (unit.entity_stats == null or unit.entity_stats.name != "escort"):
					allies += 1
			else:
				enemies += 1
				if (unit.entity_stats is AirPlaneState):
					enemy_air += 1
				var boat : BoatStats = unit.entity_stats as BoatStats
				if (boat and boat.can_submerge):
					enemy_subs += 1
	if (context):
		commander.sample(step, context, ally_base.global_position.x, enemy_base.global_position.x,
				clampf(enemy_base.health_component.health / enemy_hp_max, 0.0, 1.0))
		if (commander.alert > _alert_shown):
			_show_warning("battle.alert_high" if commander.alert >= 2 else "battle.alert_low")
		_alert_shown = commander.alert
	_check_threat("battle.warn_air", enemy_air >= WARNING_AIR_COUNT, enemy_air == 0)
	_check_threat("battle.warn_sub", enemy_subs >= WARNING_SUB_COUNT, enemy_subs == 0)
	hud.set_debug_text(Loc.t("battle.threat_pace_x_skip_units") % [commander.alert, commander.rate_mult,
			int(commander.counter_share * 100.0), allies, enemies])

func _check_threat(text_id : String, arrived : bool, gone : bool) -> void:
	if (gone):
		_threat_present[text_id] = false
		return
	if (!arrived or bool(_threat_present.get(text_id, false))):
		return
	_threat_present[text_id] = true
	if (elapsed - float(_warned_at.get(text_id, -WARNING_COOLDOWN)) < WARNING_COOLDOWN):
		return
	_warned_at[text_id] = elapsed
	_show_warning(text_id)

func _show_warning(text_id : String) -> void:
	match text_id:
		"battle.warn_air":
			BattleAudio.play_ui(self, &"alert_air_threat")
		"battle.warn_sub":
			BattleAudio.play_ui(self, &"alert_sub_threat")
	var body : String = ""
	var file : String = ""
	match text_id:
		"battle.warn_air":
			body = Loc.t("battle.warn_air_desc")
			file = "plane"
		"battle.warn_sub":
			body = Loc.t("battle.warn_sub_desc")
			file = "submarine"
		"battle.bomber_incoming":
			body = Loc.t("battle.bomber_incoming_desc")
			file = RunData.BOMBER_BOSS_NAME
	var stats : EntityStats = null
	if (file != ""):
		stats = load("res://core/resources/boats/%s.tres" % file) as EntityStats
	BattleAlert.show_on(game_round.canvas_layer, Loc.t(text_id), body, stats)

func _sample_timeline() -> void:
	_timeline.append({"t": int(elapsed), "alert": commander.alert, "front": snappedf(commander.front, 0.01),
		"you": commander.field_value, "enemy": commander.enemy_value, "bank": int(commander.bank),
		"hp": int(ally_base.health_component.health),
		"enemy_hp": snappedf(clampf(enemy_base.health_component.health / enemy_hp_max, 0.0, 1.0), 0.01)})

func _roster_names() -> Array[String]:
	var names : Array[String] = []
	for unit : BoatStats in wave_manager.table.get_wave(0).ships:
		names.append(unit.name)
	return names

func _count(table : Dictionary, key : String) -> void:
	table[key] = int(table.get(key, 0)) + 1

func _write_log(success : bool, base_destroyed : bool, hp : int) -> void:
	var reason : String = "won"
	if (!success):
		if (base_destroyed):
			reason = "base_destroyed"
		elif ((time_limit > 0.0 and elapsed >= time_limit) or (objective == RunData.Objective.DEFEND and defend_left <= 0.0)):
			reason = "timeout"
		else:
			reason = "objective_lost"
	BattleLog.append({
		"time": Time.get_datetime_string_from_system(), "slot": SaveManager.slot, "seed": run.seed_value,
		"node": run.pending_node, "floor": int(entry["col"]), "type": int(entry["type"]),
		"objective": str(RunData.OBJECTIVES[objective]["icon"]), "weather": run.battle_weather(),
		"success": success, "reason": reason, "seconds": snappedf(elapsed, 0.1),
		"base_hp_start": _start_hp, "base_hp_end": hp, "base_hp_max": run.base_max_hp,
		"enemy_base_left": snappedf(clampf(enemy_base.health_component.health / enemy_hp_max, 0.0, 1.0), 0.01),
		"opening": "strike" if commander.opening_strike else "normal", "opening_unit": commander.opening_unit,
		"opening_cut": commander.slow_cut, "hunted": hunted, "timeline": _timeline, "roster": _roster_names(), "fleet": _fleet, "upgrades": Global.player_stats.upgrade_levels,
		"built": _built, "ally_lost": _ally_lost, "enemy_spawned": _enemy_spawned, "enemy_lost": _enemy_lost,
	})

func _process_defend(delta : float) -> void:
	var ally_inside : bool = _team_in_zone(true)
	var enemy_inside : bool = _team_in_zone(false)
	contested = ally_inside and enemy_inside
	defense_point.set_presence(ally_inside, enemy_inside)
	if (defend_prep > 0.0):
		defend_prep = maxf(defend_prep - delta, 0.0)
		hud.countdown = defend_left
		_update_defend_hud(Loc.t("battle.defend_prep") % ceili(defend_prep))
		return
	var step : float = minf(delta, defend_left)
	defend_left -= step
	if (ally_inside and !enemy_inside):
		ally_hold = minf(ally_hold + step, defend_target)
	elif (enemy_inside and !ally_inside):
		enemy_hold = minf(enemy_hold + step, defend_target)
	hud.countdown = defend_left
	_update_defend_hud(Loc.t("battle.defend") % [_clock_text(ally_hold), _clock_text(defend_target)])
	if (ally_hold >= defend_target):
		_finish(true)
	elif (enemy_hold >= defend_target):
		_finish(false)
	elif (defend_left <= 0.0):
		_finish(ally_hold > enemy_hold)

func _update_defend_hud(headline : String) -> void:
	var detail : String = Loc.t("battle.defend_enemy") % [_clock_text(enemy_hold), _clock_text(defend_target)]
	if (contested):
		detail = Loc.t("battle.defend_contested") % detail
	hud.update_state(headline, ally_hold / maxf(defend_target, 1.0), detail, -1.0, contested)
	hud.set_rival(enemy_hold / maxf(defend_target, 1.0))

func _clock_text(seconds : float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _team_in_zone(ally : bool) -> bool:
	var context : BattleContext = BattleContext.of(self)
	if (context == null):
		return false
	for unit : Entity in context.entities:
		if (!is_instance_valid(unit) or (unit.team_stats.team_id == 1) != ally or unit.destroyed):
			continue
		var offset : Vector2 = unit.global_position - defense_point.global_position
		if (unit.entity_stats is AirPlaneState):
			offset.y = 0.0
		if (offset.length() < RunData.DEFEND_RADIUS):
			return true
	return false

func _process_escort() -> void:
	if (escort == null):
		_update_hud("battle.escort_waiting", 0.0)
		return
	if (!is_instance_valid(escort) or escort.is_queued_for_deletion()):
		_finish(false)
		return
	var start_x : float = ally_base.global_position.x
	var goal_x : float = enemy_base.global_position.x
	var progress : float = clampf((escort.global_position.x - start_x) / (goal_x - start_x), 0.0, 1.0)
	_update_hud(Loc.t("battle.escort") % int(round(progress / RunData.ESCORT_GOAL * 100.0)), minf(progress / RunData.ESCORT_GOAL, 1.0))
	if (progress >= RunData.ESCORT_GOAL):
		_finish(true)

func _update_hud(headline : String, fraction : float) -> void:
	var detail : String = Loc.t(str(RunData.OBJECTIVES[objective]["text"]))
	var left : float = -1.0
	if (time_limit > 0.0):
		left = maxf(time_limit - elapsed, 0.0)
	hud.update_state(headline, fraction, detail, left)

func _on_boss_defeated(stats : EntityStats) -> void:
	if (done):
		return
	bosses_killed += 1
	var bomber : bool = objective == RunData.Objective.SHOOT_DOWN_BOMBER and stats.name == RunData.BOMBER_BOSS_NAME
	var sector : bool = objective == RunData.Objective.DEFEAT_BOSS and stats.name == "boss_dreadnought"
	if (!bomber and !sector):
		return
	objective_bosses_down += 1
	if (objective_bosses_down >= bosses_required):
		boss_defeated = true
		_finish(true)

func _on_enemy_base_damaged() -> void:
	if (_bosses_forced or done):
		return
	_bosses_forced = true
	_force_bosses.call_deferred()

func _force_bosses() -> void:
	if (done):
		return
	var bosses : Array[BoatStats] = enemy_base.take_unlaunched_bosses()
	if (_held_boss):
		bosses.append(_held_boss)
		_held_boss = null
		_show_warning("battle.bomber_incoming")
	var table : RunWaveTable = wave_manager.table as RunWaveTable
	if (table.extra_boss and wave_manager.current_wave_number() < 3):
		var wave : WaveData = table.get_wave(2)
		bosses.append(enemy_base.boss_copy(wave.boss, wave.boss_health_mult, wave.boss_coin_reward))
		table.extra_boss = null
	var back : float = -float(enemy_base.team_stats.direction)
	for index : int in bosses.size():
		enemy_base.launch_now(bosses[index])
		var unit : Entity = ships_manager.get_child(ships_manager.get_child_count() - 1) as Entity
		unit.global_position.x += back * FORCED_BOSS_SPACING * float(index)

func _on_unit_destroyed(stats : EntityStats, team : TeamStats) -> void:
	_count(_ally_lost if team.team_id == 1 else _enemy_lost, stats.name)
	if (done):
		return
	if (team.team_id == 1):
		if (stats.name == "escort" and objective == RunData.Objective.ESCORT):
			_finish(false)
		return
	var boat : BoatStats = stats as BoatStats
	if (boat and boat.can_submerge and !boat.is_boss):
		hunted += 1

func _on_base_death(team : TeamStats) -> void:
	if (done):
		return
	if (team.team_id == 1):
		_finish(false, true)
	else:
		_enemy_base_destroyed = true
		_finish(true)

func _finish(success : bool, base_destroyed : bool = false) -> void:
	if (done):
		return
	done = true
	game_round.game_ended = true
	wave_manager.stop()
	game_round.skill_manager.stop()
	var hp : int = 0 if base_destroyed else int(ceil(ally_base.health_component.health))
	_write_log(success, base_destroyed, hp)
	run.resolve_battle(success, hp, base_destroyed, bosses_killed, _enemy_base_destroyed)
	RunFlow.persist()
	RUN_END_OVERLAY.show_for(run, game_round)

func _marker_targets() -> Array[Dictionary]:
	var targets : Array[Dictionary] = []
	if (done):
		return targets
	if (objective == RunData.Objective.ESCORT and escort and is_instance_valid(escort)):
		targets.append({"pos": escort.global_position, "kind": "ally", "label": "battle.escort_caps",
				"id": "escort", "unit": escort.entity_stats})
	if (objective == RunData.Objective.DEFEND and defense_point):
		targets.append({"pos": defense_point.global_position, "kind": "target", "label": "battle.defense_point", "id": "defense"})
	var context : BattleContext = BattleContext.of(self)
	if (context == null):
		return targets
	for unit : Entity in context.entities:
		if (!is_instance_valid(unit) or unit.team_stats.team_id == 1):
			continue
		var stats : EntityStats = unit.entity_stats
		if (stats.is_boss and (objective == RunData.Objective.SHOOT_DOWN_BOMBER or objective == RunData.Objective.DEFEAT_BOSS)):
			targets.append({"pos": unit.global_position, "kind": "enemy", "id": unit.get_instance_id(), "unit": stats,
				"label": "battle.bomber" if objective == RunData.Objective.SHOOT_DOWN_BOMBER else "battle.boss_caps"})
		elif (objective == RunData.Objective.HUNT_SUBMARINE):
			var boat : BoatStats = stats as BoatStats
			if (boat and boat.can_submerge):
				targets.append({"pos": unit.global_position, "kind": "enemy", "label": "battle.submarine",
						"id": unit.get_instance_id(), "unit": stats})
	return targets
