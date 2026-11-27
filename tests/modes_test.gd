extends Node

const OUT_DIR : String = "res://extras/art_preview/modes_2026-11-25/"

var _failed : int = 0

func _ready() -> void:
	SaveManager.use_test_directory()
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	Global.player_stats = Global.player_stats.duplicate()
	for item : Variant in Global.CATALOG.units:
		var stats : BoatStats = item
		if (!Global.player_stats.has_boat(stats.name)):
			Global.player_stats.add_entity(stats)
	await _escort()
	await _defend()
	await _endless()
	print("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)

func _check(ok : bool, text : String) -> void:
	if (!ok):
		_failed += 1
	print("PASS  " if ok else "FAIL  ", text)

func _wait(seconds : float) -> void:
	await get_tree().create_timer(seconds).timeout

func _start(objective : int) -> GameRound:
	var run : RunState = RunState.create(100 + objective)
	Global.run = run
	var entry : Dictionary = run.map.get_node(0)
	entry["objective"] = objective
	entry["type"] = RunData.NodeType.BATTLE
	entry["weather"] = RunData.Weather.CLEAR
	run.pending_node = 0
	run.focus_node = 0
	run.stage = RunData.Stage.BRIEFING
	run.start_battle()
	return _open()

func _open() -> GameRound:
	var game : GameRound = (load("res://scenes/ui/naval_hud/naval_round.tscn") as PackedScene).instantiate() as GameRound
	add_child(game)
	return game

func _close(game : GameRound) -> void:
	game.queue_free()
	Engine.time_scale = 1.0
	await _wait(0.5)

func _shot(game : GameRound, x : float, file : String) -> void:
	game.camera.set_process(false)
	game.camera.zoom = Vector2.ONE
	game.camera.global_position.x = x
	await _wait(0.4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + file)
	game.camera.set_process(true)

func _spawn(game : GameRound, unit_name : String, base : Base, offset : float = 0.0) -> Entity:
	var manager : ShipManager = game.get_node("ShipsManager") as ShipManager
	var before : int = manager.get_child_count()
	var stats : BoatStats = Global.CATALOG.find_unit(unit_name)
	var at : Vector2 = base.get_spawn_point()
	if (stats is AirPlaneState):
		at.y = 100.0
	manager.handle_ship_spawn(at + Vector2(offset, 0), stats, base.team_stats)
	return manager.get_child(before) as Entity

func _escort() -> void:
	var game : GameRound = _start(RunData.Objective.ESCORT)
	await _wait(0.3)
	game.campaign.commander.base = null
	var escort : Entity = game.campaign.escort
	_check(escort != null and escort.get_guns().is_empty(), "escort has no weapons")
	_check(escort.entity_stats.health >= RunData.ESCORT_HEALTH, "escort has more health (%.0f)" % escort.entity_stats.health)
	_spawn(game, "small", game.enemy_base, -600.0)
	escort.entity_stats.radar_distance = 4000
	var from : float = escort.global_position.x
	await _wait(4.0)
	_check(escort.global_position.x - from > 40.0, "escort keeps sailing (%.0f px in 4 s)" % (escort.global_position.x - from))
	await _shot(game, escort.global_position.x, "escort.png")
	await _close(game)

func _defend() -> void:
	var game : GameRound = _start(RunData.Objective.DEFEND)
	await _wait(0.3)
	var battle : CampaignBattle = game.campaign
	battle.commander.base = null
	var total : float = battle.defend_left
	await _wait(2.0)
	_check(battle.defend_left == total and battle.defend_prep > 0.0, "countdown waits during preparation")
	var center : float = battle.defense_point.global_position.x
	var enemy : Entity = _spawn(game, "medium", game.enemy_base)
	enemy.entry_x = NAN
	enemy.global_position = battle.defense_point.global_position
	_check(battle._team_in_zone(false), "living enemy contests the zone")
	enemy.destroyed = true
	_check(!battle._team_in_zone(false), "destroyed enemy does not contest")
	enemy.queue_free()
	battle.defend_prep = 0.0
	battle.defend_left = 600.0
	battle.defend_target = 600.0
	var planes : Array[Entity] = [_spawn(game, "plane", game.ally_base), _spawn(game, "heli_scout", game.ally_base),
			_spawn(game, "plane", game.enemy_base)]
	Engine.time_scale = 4.0
	await _wait(60.0)
	var worst : Array[float] = [0.0, 0.0, 0.0]
	var seen : Array[bool] = [false, false, false]
	for sample : int in 40:
		await _wait(0.5)
		for i : int in planes.size():
			if (is_instance_valid(planes[i]) and !planes[i].destroyed):
				seen[i] = true
				worst[i] = maxf(worst[i], absf(planes[i].global_position.x - center))
	Engine.time_scale = 1.0
	for i : int in planes.size():
		_check(!seen[i] or worst[i] < 400.0, "aircraft %d stays around the buoy (max %.0f px, observed %s)" % [i, worst[i], seen[i]])
	for unit : Entity in planes:
		if (is_instance_valid(unit)):
			unit.queue_free()
	var raider : Entity = _spawn(game, "plane", game.enemy_base)
	Engine.time_scale = 4.0
	await _wait(60.0)
	var far : float = 0.0
	var contests : int = 0
	for sample : int in 40:
		await _wait(0.5)
		if (is_instance_valid(raider)):
			far = maxf(far, absf(raider.global_position.x - center))
			contests += int(battle._team_in_zone(false))
	Engine.time_scale = 1.0
	_check(is_instance_valid(raider) and far < 300.0 and contests > 30, "lone enemy aircraft circles and contests (max %.0f px, %d/40)" % [far, contests])
	await _shot(game, center, "defend.png")
	await _close(game)
	_check(!BattleContext.of(self).has_patrol(), "patrol area cleared after the battle")

func _endless() -> void:
	Global.run = null
	var game : GameRound = _open()
	await _wait(1.0)
	var director : EndlessDirector = game.endless
	var manager : ShipManager = game.get_node("ShipsManager") as ShipManager
	_check(director != null and director.level == 1, "endless starts at level 1")
	_check(!manager.gear_drops, "no gear drops in endless")
	var first : int = director.roster.size()
	var rate : float = director.commander.base_rate
	_spawn(game, "plane", game.ally_base)
	_spawn(game, "plane", game.ally_base, 30.0)
	director.level_up()
	_check(director.roster.size() > first, "level up brings a counter unit (%s)" % str(director.roster.map(func(u : BoatStats) -> String: return u.name)))
	director.elapsed = RunData.ENDLESS_LEVEL_SECONDS * 8.0
	await _wait(1.0)
	_check(director.level >= 9 and director.commander.base_rate > rate, "time raises threat (level %d)" % director.level)
	_check((game.enemy_base as AutoBase).ships.size() == director.roster.size(), "enemy base builds from the director roster")
	await _wait(8.0)
	await _shot(game, game.enemy_base.global_position.x - 500.0, "endless.png")
	var gears : int = Global.player_stats.gear
	var coins : int = Global.player_stats.boss_coin
	game.base_death_event(game.ally_base.team_stats)
	await _wait(5.0)
	_check(Global.player_stats.gear == gears and Global.player_stats.boss_coin == coins, "no rewards at the end")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "endless_result.png")
	await _close(game)
