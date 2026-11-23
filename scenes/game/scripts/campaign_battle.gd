class_name CampaignBattle
extends Node

const BANNER_SECONDS : float = 1.8

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

var done : bool = false
var boss_defeated : bool = false
var hunted : int = 0
var elapsed : float = 0.0
var time_limit : float = 0.0
var defend_left : float = 0.0
var contested : bool = false
var enemy_hp_max : float = 1.0
var _restore_test_flag : bool = false

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
	_restore_test_flag = Global.test_enemy_all_units
	Global.test_enemy_all_units = false
	ally_base.health_component.health = float(run.base_hp)
	ally_base.health_component.label.text = str(run.base_hp)
	ally_base.death_event.connect(_on_base_death)
	enemy_base.death_event.connect(_on_base_death)
	ships_manager.boss_defeated.connect(_on_boss_defeated)
	ships_manager.unit_destroyed.connect(_on_unit_destroyed)
	ships_manager.child_entered_tree.connect(_on_ship_added)
	var time_mult : float = run.modify(RunData.T_RUN, &"time_mult", 1.0)
	if (objective == RunData.Objective.DEFEND):
		defend_left = RunData.DEFEND_SECONDS * time_mult
		time_limit = 0.0
	else:
		time_limit = float(RunData.TIME_LIMITS.get(objective, 0.0)) * time_mult
	_build_waves()
	_build_overlays()
	_start_objective()

func _exit_tree() -> void:
	if (_restore_test_flag):
		Global.test_enemy_all_units = true

func _build_waves() -> void:
	wave_manager = WaveManager.new()
	wave_manager.table = RunBattleConfig.build_table(run, entry)
	wave_manager.enemy_base = enemy_base
	add_child(wave_manager)
	wave_manager.wave_started.connect(game_round._on_wave_started)
	wave_manager.start()
	enemy_hp_max = maxf(enemy_base.health_component.health, 1.0)

func _build_overlays() -> void:
	var canvas : CanvasLayer = game_round.canvas_layer
	hud = ObjectiveHud.new()
	hud.setup(objective)
	hud.position = Vector2(32, 62)
	hud.custom_minimum_size = Vector2(360, 0)
	canvas.add_child(hud)
	markers = ObjectiveMarkers.new()
	markers.provider = _marker_targets
	canvas.add_child(markers)
	weather_layer = WeatherLayer.new()
	weather_layer.setup(run.battle_weather(), canvas)
	game_round.add_child(weather_layer)
	game_round.move_child(weather_layer, canvas.get_index())
	weather_layer.show_banner(canvas)

func _start_objective() -> void:
	match objective:
		RunData.Objective.DEFEND:
			defense_point = DefensePoint.new()
			game_round.add_child(defense_point)
			var from : Vector2 = ally_base.global_position
			var to : Vector2 = enemy_base.global_position
			defense_point.global_position = Vector2((from.x + to.x) * 0.5, ally_base.get_spawn_point().y)
		RunData.Objective.ESCORT:
			ships_manager.handle_ship_spawn(ally_base.get_spawn_point(), RunBattleConfig.escort_stats(), ally_base.team_stats)

func _on_ship_added(child : Node) -> void:
	var unit : Entity = child as Entity
	if (unit and unit.entity_stats and unit.entity_stats.name == "escort" and unit.team_stats.team_id == 1):
		escort = unit

func _process(delta : float) -> void:
	if (done):
		return
	elapsed += delta
	match objective:
		RunData.Objective.DEFEND:
			_process_defend(delta)
		RunData.Objective.ESCORT:
			_process_escort()
		RunData.Objective.HUNT_SUBMARINE:
			_update_hud("Hunt: %d/%d" % [hunted, RunData.HUNT_TARGET], float(hunted) / RunData.HUNT_TARGET)
			if (hunted >= RunData.HUNT_TARGET):
				_finish(true)
		RunData.Objective.SHOOT_DOWN_BOMBER:
			_update_hud("Bomber down: %s" % ("YES" if boss_defeated else "NO"), 1.0 if boss_defeated else 0.0)
		RunData.Objective.DEFEAT_BOSS:
			_update_hud("Boss: %s" % ("DOWN" if boss_defeated else "ALIVE"), 1.0 if boss_defeated else 0.0)
		_:
			var hp : float = clampf(enemy_base.health_component.health / enemy_hp_max, 0.0, 1.0)
			_update_hud("Enemy base: %d%%" % int(round(hp * 100.0)), 1.0 - hp)
	if (done):
		return
	if (time_limit > 0.0 and elapsed >= time_limit):
		_finish(false)

func _process_defend(delta : float) -> void:
	contested = _enemy_in_zone()
	defense_point.set_contested(contested)
	if (!contested):
		defend_left = maxf(defend_left - delta, 0.0)
	var total : float = RunData.DEFEND_SECONDS * run.modify(RunData.T_RUN, &"time_mult", 1.0)
	_update_hud("Defend: %d:%02d" % [int(defend_left) / 60, int(defend_left) % 60],
			1.0 - defend_left / maxf(total, 1.0), contested)
	if (defend_left <= 0.0):
		_finish(true)

func _enemy_in_zone() -> bool:
	var context : BattleContext = BattleContext.of(self)
	if (context == null):
		return false
	for unit : Entity in context.entities:
		if (!is_instance_valid(unit) or unit.team_stats.team_id == 1):
			continue
		if (unit.global_position.distance_to(defense_point.global_position) < RunData.DEFEND_RADIUS):
			return true
	return false

func _process_escort() -> void:
	if (escort == null):
		_update_hud("Escort: waiting", 0.0)
		return
	if (!is_instance_valid(escort) or escort.is_queued_for_deletion()):
		_finish(false)
		return
	var start_x : float = ally_base.global_position.x
	var goal_x : float = enemy_base.global_position.x
	var progress : float = clampf((escort.global_position.x - start_x) / (goal_x - start_x), 0.0, 1.0)
	_update_hud("Escort: %d%%" % int(round(progress / RunData.ESCORT_GOAL * 100.0)), minf(progress / RunData.ESCORT_GOAL, 1.0))
	if (progress >= RunData.ESCORT_GOAL):
		_finish(true)

func _update_hud(headline : String, fraction : float, warn : bool = false) -> void:
	var detail : String = str(RunData.OBJECTIVES[objective]["text"])
	if (warn):
		detail = "Contested: enemies in the zone stop the countdown."
	var left : float = -1.0
	if (time_limit > 0.0):
		left = maxf(time_limit - elapsed, 0.0)
	hud.update_state(headline, fraction, detail, left, warn)

func _on_boss_defeated(stats : EntityStats) -> void:
	boss_defeated = true
	if (done):
		return
	if (objective == RunData.Objective.SHOOT_DOWN_BOMBER and stats.name == "boss_heavy_bomber"):
		_finish(true)
	elif (objective == RunData.Objective.DEFEAT_BOSS and stats.name == "boss_dreadnought"):
		_finish(true)

func _on_unit_destroyed(stats : EntityStats, team : TeamStats) -> void:
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
		_finish(true)

func _finish(success : bool, base_destroyed : bool = false) -> void:
	if (done):
		return
	done = true
	game_round.game_ended = true
	wave_manager.stop()
	game_round.skill_manager.stop()
	var hp : int = 0 if base_destroyed else int(ceil(ally_base.health_component.health))
	run.resolve_battle(success, hp, base_destroyed, boss_defeated)
	RunFlow.persist()
	_show_result_banner(success, base_destroyed)

func _show_result_banner(success : bool, base_destroyed : bool) -> void:
	var label : Label = Label.new()
	label.text = "BASE DESTROYED" if base_destroyed else ("OBJECTIVE COMPLETE" if success else "OBJECTIVE FAILED")
	label.add_theme_font_override("font", load("res://assets/fonts/dogicabold.ttf") as Font)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color("#78dddd") if success else Color("#dfa0a2"))
	label.add_theme_color_override("font_outline_color", Color("#090f15"))
	label.add_theme_constant_override("outline_size", 8)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = Vector2(640.0 - 300.0, 300.0)
	label.size = Vector2(600, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_round.canvas_layer.add_child(label)
	var timer : SceneTreeTimer = get_tree().create_timer(BANNER_SECONDS)
	timer.timeout.connect(RunFlow.advance)

func _marker_targets() -> Array[Dictionary]:
	var targets : Array[Dictionary] = []
	if (done):
		return targets
	if (objective == RunData.Objective.ESCORT and escort and is_instance_valid(escort)):
		targets.append({"pos": escort.global_position, "kind": "ally", "label": "ESCORT"})
	if (objective == RunData.Objective.DEFEND and defense_point):
		targets.append({"pos": defense_point.global_position, "kind": "target", "label": "DEFENSE POINT"})
	var context : BattleContext = BattleContext.of(self)
	if (context == null):
		return targets
	for unit : Entity in context.entities:
		if (!is_instance_valid(unit) or unit.team_stats.team_id == 1):
			continue
		var stats : EntityStats = unit.entity_stats
		if (stats.is_boss and (objective == RunData.Objective.SHOOT_DOWN_BOMBER or objective == RunData.Objective.DEFEAT_BOSS)):
			targets.append({"pos": unit.global_position, "kind": "target",
				"label": "BOMBER" if objective == RunData.Objective.SHOOT_DOWN_BOMBER else "BOSS"})
		elif (objective == RunData.Objective.HUNT_SUBMARINE):
			var boat : BoatStats = stats as BoatStats
			if (boat and boat.can_submerge):
				targets.append({"pos": unit.global_position, "kind": "enemy", "label": "SUBMARINE"})
	return targets
