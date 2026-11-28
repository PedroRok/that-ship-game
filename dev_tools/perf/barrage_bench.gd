extends Node

const OUT_DIR : String = "res://extras/art_preview/barrage_bench/"
const WINDOW_SECONDS : float = 7.0

func _ready() -> void:
	SaveManager.use_test_directory()
	Global.run = null
	Global.player_stats = Global.player_stats.duplicate()
	get_window().size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var game : GameRound = (load("res://scenes/ui/naval_hud/naval_round.tscn") as PackedScene).instantiate() as GameRound
	add_child(game)
	await _wait(1.0)
	game.wave_manager.stop()
	game.endless.set_process(false)
	game.camera.set_process(false)
	game.camera.global_position.x = (game.ally_base.global_position.x + game.enemy_base.global_position.x) * 0.5
	var view : RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(view, true)
	print("adapter: ", RenderingServer.get_video_adapter_name())
	var args : PackedStringArray = OS.get_cmdline_user_args()
	if (args.has("scenario=bombs")):
		await _bombs_scenario(game, view)
	elif (args.has("scenario=deaths")):
		await _steady_scenario(game, view, "deaths", _drop_wrecks.bind(game), 2.0, 16.0)
	elif (args.has("scenario=bullets")):
		await _steady_scenario(game, view, "bullets", _fire_bullets.bind(game), 0.1, 3.0)
	elif (args.has("scenario=basefire")):
		_damage_base(game)
		await _steady_scenario(game, view, "basefire", Callable(), 1.0, 5.0)
	elif (args.has("scenario=trails")):
		await _moving_scenario(game, view, "trails", _launch_trails.bind(game), 0.5, [])
	elif (args.has("scenario=water")):
		await _moving_scenario(game, view, "water", _launch_torpedoes.bind(game), 0.4, ["medium", "cruiser", "destroyer", "frigate", "small", "medium"])
	elif (args.has("scenario=rain")):
		var weather : WeatherLayer = WeatherLayer.new()
		WeatherSky.apply(game, RunData.Weather.STORM)
		weather.setup(RunData.Weather.STORM, game.canvas_layer)
		game.add_child(weather)
		await _moving_scenario(game, view, "rain", _nothing, 1.0, ["medium", "cruiser"])
	elif (args.has("scenario=crash")):
		await _moving_scenario(game, view, "crash", _crash_planes.bind(game), 1.5, [])
	elif (args.has("scenario=impacts")):
		await _impacts_scenario(game, view)
	elif (args.has("scenario=unitfire")):
		await _unit_fire_scenario(game, view)
	else:
		await _barrage_scenario(game, view)
	get_tree().quit()

func _steady_scenario(game : GameRound, view : RID, label : String, action : Callable, every : float, warmup : float) -> void:
	seed(7)
	var on_base : bool = label != "deaths"
	if (label == "bullets"):
		game.enemy_base.health_component.health = 100000.0
	game.camera.zoom = Vector2(2.0, 2.0)
	game.camera.global_position = Vector2(game.enemy_base.global_position.x - (150.0 if on_base else 560.0), 330.0)
	if (action.is_valid()):
		var timer : Timer = Timer.new()
		timer.wait_time = every
		timer.timeout.connect(action)
		add_child(timer)
		timer.start()
	await _wait(warmup)
	await _measure(label, view, label + ".png")
	for index : int in 4:
		await _wait(0.37)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT_DIR + "%s_%d.png" % [label, index])

func _moving_scenario(game : GameRound, view : RID, label : String, action : Callable, every : float, ships : Array) -> void:
	seed(7)
	var left : float = game.enemy_base.global_position.x - 620.0
	var water : float = game.enemy_base.get_spawn_point().y
	game.camera.zoom = Vector2(2.0, 2.0)
	game.camera.global_position = Vector2(left + 250.0, 330.0)
	game.enemy_base.health_component.health = 100000.0
	for index : int in ships.size():
		var unit : Entity = _place_unit(game, str(ships[index]), Vector2(left + 120.0 + 80.0 * index, water))
		for gun : Gun in unit.get_guns():
			gun.disabled = true
	var timer : Timer = Timer.new()
	timer.wait_time = every
	timer.timeout.connect(action)
	add_child(timer)
	timer.start()
	await _wait(2.5)
	await _measure(label, view, label + ".png")
	for index : int in 3:
		await _wait(0.37)
		await _capture("%s_%d" % [label, index])

func _nothing() -> void:
	pass

func _crash_planes(game : GameRound) -> void:
	var left : float = game.enemy_base.global_position.x - 620.0
	var names : Array[String] = ["plane", "bomber", "heli_scout"]
	for index : int in names.size():
		var unit : Entity = _place_unit(game, names[index], Vector2(left + 130.0 + 120.0 * index, 330.0))
		_kill.call_deferred(unit)

func _launch_trails(game : GameRound) -> void:
	var left : float = game.enemy_base.global_position.x - 620.0
	var scene : PackedScene = load("res://scenes/entities/bullets/missile.tscn") as PackedScene
	for index : int in 4:
		var missile : BulletMissile = scene.instantiate() as BulletMissile
		missile.team = game.ally_base.team_stats.team_id
		missile.launch_forward = true
		BattleContext.of(game.ally_base).bullets.add_child(missile)
		missile.global_position = Vector2(left + 40.0, 200.0 + 35.0 * index)
		missile.set_direction(Vector2(1.0, randf_range(-0.15, 0.15)))
	game.skill_manager.command = SkillManager.COMMAND_MAX
	game.skill_manager.fire(SkillCatalog.BOMB, Vector2(left + 330.0, 368.0))

func _launch_torpedoes(game : GameRound) -> void:
	var left : float = game.enemy_base.global_position.x - 620.0
	var scene : PackedScene = load("res://scenes/entities/bullets/torpedo.tscn") as PackedScene
	for index : int in 2:
		var torpedo : BulletTorpedo = scene.instantiate() as BulletTorpedo
		torpedo.team = game.ally_base.team_stats.team_id
		BattleContext.of(game.ally_base).bullets.add_child(torpedo)
		torpedo.global_position = Vector2(left + 20.0, 378.0 + 22.0 * index)
		torpedo.set_direction(Vector2.RIGHT)

func _impacts_scenario(game : GameRound, view : RID) -> void:
	seed(7)
	var left : float = game.enemy_base.global_position.x - 420.0
	var water : float = game.enemy_base.get_spawn_point().y
	game.camera.zoom = Vector2(3.0, 3.0)
	game.camera.global_position = Vector2(left + 220.0, 320.0)
	game.enemy_base.health_component.health = 100000.0
	var fleet : Array[Entity] = []
	for entry : Array in [["medium", 90.0, water], ["cruiser", 220.0, water], ["bomber", 130.0, 270.0], ["heli_scout", 270.0, 280.0]]:
		fleet.append(_place_unit(game, str(entry[0]), Vector2(left + float(entry[1]), float(entry[2]))))
	await get_tree().physics_frame
	for unit : Entity in fleet:
		var health : HealthComponent = unit.get_node("HealthComponent") as HealthComponent
		health.default_health = 100000.0
		health.actual_health = 100000.0
		unit.set_deferred("freeze", true)
		for gun : Gun in unit.get_guns():
			gun.disabled = true
	var timer : Timer = Timer.new()
	timer.wait_time = 0.25
	timer.timeout.connect(_strike.bind(game, fleet, left))
	add_child(timer)
	timer.start()
	await _wait(3.0)
	await _measure("impacts", view, "impacts.png")
	for index : int in 4:
		await _wait(0.37)
		await _capture("impacts_%d" % index)

func _strike(game : GameRound, fleet : Array[Entity], left : float) -> void:
	for unit : Entity in fleet:
		var damage : Damage = Damage.new()
		damage.damage = 0.01
		damage.knockback = 0
		(unit.get_node("HitboxComponent") as HitboxComponent).handle_hit(damage, 0.0)
	var scene : PackedScene = load("res://scenes/entities/bullets/missile.tscn") as PackedScene
	for goal : Vector2 in [fleet[1].get_center_pos(), fleet[2].get_center_pos(), game.enemy_base.get_center_pos() + Vector2(0.0, -40.0)]:
		var missile : BulletMissile = scene.instantiate() as BulletMissile
		missile.team = game.ally_base.team_stats.team_id
		missile.launch_forward = true
		BattleContext.of(game.ally_base).bullets.add_child(missile)
		missile.global_position = Vector2(left - 20.0, goal.y + randf_range(-6.0, 6.0))
		missile.set_direction(goal - missile.global_position)

func _unit_fire_scenario(game : GameRound, view : RID) -> void:
	seed(7)
	var left : float = game.enemy_base.global_position.x - 640.0
	var water : float = game.enemy_base.get_spawn_point().y
	game.camera.zoom = Vector2(3.0, 3.0)
	game.camera.global_position = Vector2(left + 140.0, 330.0)
	var names : Array[String] = ["medium", "cruiser", "destroyer", "frigate", "bomber", "plane", "heli_scout"]
	var fleet : Array[Entity] = []
	for index : int in 14:
		var unit_name : String = names[index % names.size()]
		var flying : bool = index % names.size() >= 4
		var at : Vector2 = Vector2(left + 20.0 + 45.0 * (index % 7) + 20.0 * (index / 7), 250.0 + 45.0 * (index / 7) if flying else water)
		fleet.append(_place_unit(game, unit_name, at))
	await get_tree().physics_frame
	for unit : Entity in fleet:
		_hurt(unit, 0.75)
		unit.set_deferred("freeze", true)
		for gun : Gun in unit.get_guns():
			gun.disabled = true
	await _wait(4.0)
	await _measure("unitfire", view, "unitfire.png")

func _place_unit(game : GameRound, unit_name : String, at : Vector2) -> Entity:
	var manager : ShipManager = game.get_node("ShipsManager") as ShipManager
	var before : int = manager.get_child_count()
	manager.handle_ship_spawn(at, Global.CATALOG.find_unit(unit_name), game.enemy_base.team_stats)
	var unit : Entity = manager.get_child(before) as Entity
	unit.entry_x = NAN
	unit.global_position = at
	return unit

func _hurt(unit : Entity, share : float) -> void:
	var damage : Damage = Damage.new()
	damage.damage = (unit.get_node("HealthComponent") as HealthComponent).default_health * share
	damage.knockback = 0
	(unit.get_node("HitboxComponent") as HitboxComponent).handle_hit(damage, 0.0)

func _capture(file : String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + file + ".png")

func _drop_wrecks(game : GameRound) -> void:
	var manager : ShipManager = game.get_node("ShipsManager") as ShipManager
	var left : float = game.enemy_base.global_position.x - 800.0
	var water : float = game.enemy_base.get_spawn_point().y
	var names : Array[String] = ["medium", "cruiser", "submarine", "plane", "bomber", "heli_scout"]
	var heights : Array[float] = [water, water, water, 190.0, 230.0, 270.0]
	for index : int in names.size():
		var at : Vector2 = Vector2(left + 90.0 * index, heights[index])
		var before : int = manager.get_child_count()
		manager.handle_ship_spawn(at, Global.CATALOG.find_unit(names[index]), game.enemy_base.team_stats)
		var unit : Entity = manager.get_child(before) as Entity
		unit.entry_x = NAN
		unit.global_position = at
		if (names[index] == "submarine"):
			(unit as ShipEntity).start_submerged(ShipEntity.DIVE_DEPTH)
		_kill.call_deferred(unit)

func _kill(unit : Entity) -> void:
	await get_tree().physics_frame
	var damage : Damage = Damage.new()
	damage.damage = 100000.0
	damage.knockback = 0
	(unit.get_node("HitboxComponent") as HitboxComponent).handle_hit(damage, 0.0)

func _fire_bullets(game : GameRound) -> void:
	var scene : PackedScene = load("res://scenes/entities/bullets/bullet.tscn") as PackedScene
	var base : Vector2 = game.enemy_base.get_center_pos()
	for index : int in 4:
		var bullet : Bullet = scene.instantiate() as Bullet
		bullet.team = game.ally_base.team_stats.team_id
		BattleContext.of(game.ally_base).bullets.add_child(bullet)
		var from : Vector2 = Vector2(base.x - 330.0, 250.0 + 20.0 * index)
		var to : Vector2 = Vector2(base.x - 190.0 + randf_range(-60.0, 60.0), 380.0) if index % 2 == 0 else Vector2(base.x, base.y + randf_range(-50.0, 20.0))
		bullet.global_position = from
		bullet.set_direction((to - from).normalized())
		bullet.rotation = bullet.direction.angle()

func _damage_base(game : GameRound) -> void:
	var damage : Damage = Damage.new()
	damage.damage = game.enemy_base.health_component.health * 0.7
	game.enemy_base.health_component.handle_hit(damage)

func _barrage_scenario(game : GameRound, view : RID) -> void:
	_fire(game)
	await _wait(WINDOW_SECONDS + 6.0)
	await _measure("no barrage", view, "")
	for round_index : int in 2:
		_fire(game)
		await _measure("barrage", view, "barrage.png" if round_index == 0 else "")
		await _wait(6.0)

func _bombs_scenario(game : GameRound, view : RID) -> void:
	seed(7)
	game.camera.global_position.x = game.enemy_base.global_position.x - 300.0
	await _measure("no bombs", view, "")
	var timer : Timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_drop_bombs.bind(game))
	add_child(timer)
	timer.start()
	await _wait(3.0)
	await _measure("bombs", view, "bombs.png")
	timer.stop()

func _drop_bombs(game : GameRound) -> void:
	var target : Vector2 = game.enemy_base.get_center_pos()
	game.skill_manager.command = SkillManager.COMMAND_MAX
	game.skill_manager.fire(SkillCatalog.BOMB, Vector2(target.x - 380.0, target.y))
	var scene : PackedScene = load("res://scenes/entities/bullets/bomb.tscn") as PackedScene
	for index : int in 8:
		var bomb : BulletBomb = scene.instantiate() as BulletBomb
		bomb.team = game.ally_base.team_stats.team_id
		BattleContext.of(game.ally_base).bullets.add_child(bomb)
		bomb.global_position = Vector2(target.x - 480.0 + 70.0 * index, target.y - 90.0 - 8.0 * (index % 3))

func _fire(game : GameRound) -> void:
	game.skill_manager.command = SkillManager.COMMAND_MAX
	game.skill_manager.fire(SkillCatalog.FLAK)

func _wait(seconds : float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _measure(label : String, view : RID, shot : String) -> void:
	var frames : Array[float] = []
	var gpu : float = 0.0
	var render_cpu : float = 0.0
	var script_time : float = 0.0
	var last : int = Time.get_ticks_usec()
	var begin : int = last
	var taken : bool = false
	while (Time.get_ticks_usec() - begin < int(WINDOW_SECONDS * 1000000.0)):
		await get_tree().process_frame
		var now : int = Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(view)
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(view)
		script_time += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		if (!shot.is_empty() and !taken and now - begin > 2800000):
			taken = true
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OUT_DIR + shot)
			last = Time.get_ticks_usec()
	var total : float = 0.0
	for value : float in frames:
		total += value
	frames.sort()
	var count : int = frames.size()
	print("%-11s frames %5d  avg %.2f ms  99%% %.2f ms  worst %.2f ms  gpu %.2f ms  render cpu %.2f ms  process %.2f ms" % [
			label, count, total / count, frames[int(count * 0.99)], frames[count - 1], gpu / count, render_cpu / count, script_time / count])
