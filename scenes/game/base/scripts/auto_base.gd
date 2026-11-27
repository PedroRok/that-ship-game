class_name AutoBase
extends Base

const MIN_BASE_HEALTH : float = 100.0

@export
var ships : Array[BoatStats]

@export
var time_to_spawn : int = 5

@export
var turret_offsets : Array[Vector2] = [Vector2(0, -50), Vector2(25, -50), Vector2(-25, -50)]

@export
var dock_interval_mult : Dictionary = {
	BaseDock.Type.NAVAL: 1.0,
	BaseDock.Type.AIR: 1.5,
	BaseDock.Type.SUB: 1.5,
}

@onready
var timer : Timer = $Timer

var dock_timers : Dictionary = {}

var production_mult : float = 1.0
var director_interval_mult : float = 1.0
var director_skip_chance : float = 0.0
var stat_mult : float = 1.0
var spawn_interval : float = 5.0
var pending_bosses : Array[BoatStats] = []
var turrets : Array[BaseTurret] = []
var active : bool = false
var live_cap : int = 0
var sub_cap : int = 0
var boss_skip_chance : float = 0.0
var budget_mode : bool = false
var roster_override : Array[BoatStats] = []

func _ready() -> void:
	super._ready()
	spawn_interval = time_to_spawn
	timer.stop()
	dock_timers[BaseDock.Type.NAVAL] = timer
	for dock_type : BaseDock.Type in [BaseDock.Type.AIR, BaseDock.Type.SUB]:
		var dock_timer : Timer = Timer.new()
		add_child(dock_timer)
		dock_timers[dock_type] = dock_timer
	for dock_type : int in dock_timers:
		(dock_timers[dock_type] as Timer).timeout.connect(_on_dock_timer.bind(dock_type))

func apply_wave(wave : WaveData) -> void:
	ships = wave.ships if roster_override.is_empty() else roster_override
	stat_mult = wave.stat_mult
	spawn_interval = wave.spawn_interval
	if (wave.base_tier):
		apply_tier(wave.base_tier)
	if (wave.boss):
		pending_bosses.append(boss_copy(wave.boss, wave.boss_health_mult, wave.boss_coin_reward))
	show_docks_for(Global.CATALOG.units if Global.test_enemy_all_units and !budget_mode else ships)
	active = true
	if (budget_mode):
		return
	for dock_type : int in dock_timers:
		(dock_timers[dock_type] as Timer).start(_dock_interval(dock_type))
		_on_dock_timer(dock_type)

func apply_tier(tier : BaseTier) -> void:
	if (tier.sprite):
		set_base_texture(tier.sprite)
	if (!tier.turret_offsets.is_empty()):
		turret_offsets = tier.turret_offsets
	production_mult = tier.production_interval_mult
	health_component.health = maxf(tier.base_health, MIN_BASE_HEALTH)
	health_component.label.text = str(health_component.health)
	_max_health = maxf(health_component.health, 1.0)
	_set_turrets(tier.turret_count)

func set_director(interval_mult : float, skip_chance : float) -> void:
	director_interval_mult = interval_mult
	director_skip_chance = skip_chance
	for dock_type : int in dock_timers:
		var dock_timer : Timer = dock_timers[dock_type]
		if (!dock_timer.is_stopped()):
			dock_timer.wait_time = maxf(_dock_interval(dock_type), 0.1)

func stop() -> void:
	active = false
	for dock_timer : Timer in dock_timers.values():
		dock_timer.stop()

func _dock_interval(dock_type : int) -> float:
	return spawn_interval * production_mult * director_interval_mult * float(dock_interval_mult.get(dock_type, 1.0))

func _on_dock_timer(dock_type : int) -> void:
	if (!active or ships.is_empty()):
		return
	if (director_skip_chance > 0.0 and pending_bosses.is_empty() and randf() < director_skip_chance):
		return
	if (pending_bosses.is_empty() and over_limits(dock_type)):
		return
	for boss : BoatStats in pending_bosses:
		if (dock_type_of(boss) == dock_type):
			if (start_build_ship(boss)):
				pending_bosses.erase(boss)
			return
	var pool : Array = Global.CATALOG.units if Global.test_enemy_all_units else ships
	var candidates : Array = pool.filter(
		func(stats : EntityStats) -> bool: return !stats.is_boss and dock_type_of(stats) == dock_type)
	if (candidates.is_empty()):
		return
	start_build_ship(_scaled(candidates.pick_random(), stat_mult, false))

func boss_copy(stats : BoatStats, health_mult : float, coin_reward : int) -> BoatStats:
	var copy : BoatStats = _scaled(stats, health_mult, true)
	copy.boss_coin_reward = coin_reward
	return copy

func build_pending_bosses() -> void:
	for boss : BoatStats in pending_bosses.duplicate():
		if (start_build_ship(boss)):
			pending_bosses.erase(boss)

func take_unlaunched_bosses() -> Array[BoatStats]:
	var result : Array[BoatStats] = pending_bosses.duplicate()
	pending_bosses.clear()
	for dock : int in constructors:
		var constructor : ShipConstructor = constructors[dock]
		if (constructor.is_building() and constructor.boat_stats.is_boss):
			result.append(constructor.cancel_build())
	return result

func launch_now(stats : BoatStats) -> void:
	var constructor : ShipConstructor = constructors[dock_type_of(stats)]
	spawn_ship_event.emit(constructor.spawn_position(), stats, team_stats)

func scaled_copy(stats : BoatStats) -> BoatStats:
	return _scaled(stats, stat_mult, false)

func over_limits(dock_type : int) -> bool:
	if (live_cap <= 0 and sub_cap <= 0 and boss_skip_chance <= 0.0):
		return false
	var context : BattleContext = BattleContext.of(self)
	if (context == null):
		return false
	var live : int = 0
	var subs : int = 0
	var boss_alive : bool = false
	for node : Entity in context.entities:
		if (!is_instance_valid(node) or node.is_queued_for_deletion() or node.team_stats.team_id != team_stats.team_id):
			continue
		live += 1
		var boat : BoatStats = node.entity_stats as BoatStats
		if (boat and boat.can_submerge):
			subs += 1
		if (node.entity_stats.is_boss):
			boss_alive = true
	for dock : int in constructors:
		var pending : BoatStats = (constructors[dock] as ShipConstructor).boat_stats
		if (pending):
			live += 1
			if (pending.can_submerge):
				subs += 1
	if (live_cap > 0 and live >= live_cap):
		return true
	if (sub_cap > 0 and dock_type == BaseDock.Type.SUB and subs >= sub_cap):
		return true
	return boss_alive and boss_skip_chance > 0.0 and randf() < boss_skip_chance

func _scaled(stats : BoatStats, mult : float, boss : bool) -> BoatStats:
	var copy : BoatStats = stats.duplicate()
	copy.health *= mult
	copy.is_boss = boss
	return copy

func _set_turrets(count : int) -> void:
	var gun_scene : PackedScene = Enums.gun_scene(Enums.Guns.SMALL_GUN)
	count = min(count, turret_offsets.size())
	while (turrets.size() < count):
		var turret : BaseTurret = BaseTurret.new()
		add_child(turret)
		turret.setup(team_stats, gun_scene)
		turrets.append(turret)
	for i : int in turrets.size():
		turrets[i].position = base_center.position + turret_offsets[i]
