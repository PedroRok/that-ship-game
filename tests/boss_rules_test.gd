extends Node

var failures : int = 0

func check(ok : bool, label : String) -> void:
	print("PASS  " if ok else "FAIL  ", label)
	if (!ok):
		failures += 1

func _ready() -> void:
	SaveManager.use_test_directory()
	Global.player_stats = Global.player_stats.duplicate()
	Global.player_stats.upgrade_levels = {}
	_modifiers()
	await _sector_boss()
	await _bomber()
	print("---- ", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _briefing(objective : int, weather : int = RunData.Weather.CLEAR) -> RunState:
	var run : RunState = RunState.create(200 + objective)
	Global.run = run
	var entry : Dictionary = run.map.get_node(0)
	entry["objective"] = objective
	entry["type"] = RunData.NodeType.BATTLE
	entry["weather"] = weather
	run.pending_node = 0
	run.focus_node = 0
	run.stage = RunData.Stage.BRIEFING
	return run

func _modifiers() -> void:
	var destroy : RunState = _briefing(RunData.Objective.DESTROY_BASE)
	check(!destroy.risk_applies(&"more_bosses") and !destroy.toggle_risk(&"more_bosses"), "no extra boss without a boss objective")
	check(destroy.risk_applies(&"forced_storm") and destroy.risk_applies(&"less_time"), "clear destroy node offers storm and less time")
	check(!_briefing(RunData.Objective.DESTROY_BASE, RunData.Weather.FOG).risk_applies(&"forced_storm"), "no forced storm over other weather")
	check(!_briefing(RunData.Objective.DEFEND).risk_applies(&"less_time"), "no less time on defend")
	check(_briefing(RunData.Objective.SHOOT_DOWN_BOMBER).risk_applies(&"more_bosses"), "bomber objective offers an extra boss")
	var plain : RunState = _briefing(RunData.Objective.DEFEAT_BOSS)
	var armored : RunState = _briefing(RunData.Objective.DEFEAT_BOSS)
	armored.toggle_risk(&"stronger_enemies")
	var before : float = RunBattleConfig.build_table(plain, plain.map.get_node(0)).get_wave(0).boss_health_mult
	var after : float = RunBattleConfig.build_table(armored, armored.map.get_node(0)).get_wave(0).boss_health_mult
	check(is_equal_approx(after, before * 1.25), "armored enemies also toughen bosses (%.2f -> %.2f)" % [before, after])

func _start(objective : int) -> GameRound:
	var run : RunState = _briefing(objective)
	run.toggle_risk(&"more_bosses")
	run.start_battle()
	var game : GameRound = (load("res://scenes/ui/naval_hud/naval_round.tscn") as PackedScene).instantiate() as GameRound
	add_child(game)
	await _wait(0.3)
	game.campaign.commander.base = null
	return game

func _wait(seconds : float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _hit_enemy_base(game : GameRound) -> void:
	var damage : Damage = Damage.new()
	damage.damage = 1.0
	(game.enemy_base.health_component as BaseHealthComponent).handle_hit(damage)
	await _wait(0.2)

func _bosses(game : GameRound, unit_name : String) -> Array[Entity]:
	var result : Array[Entity] = []
	for unit : Entity in BattleContext.of(game.enemy_base).entities:
		if (is_instance_valid(unit) and unit.entity_stats.name == unit_name and unit.entity_stats.is_boss):
			result.append(unit)
	return result

func _kill(unit : Entity) -> void:
	unit.entity_destroy.emit(unit.global_position, unit.entity_stats, unit.team_stats)

func _sector_boss() -> void:
	var game : GameRound = await _start(RunData.Objective.DEFEAT_BOSS)
	var battle : CampaignBattle = game.campaign
	check(battle.bosses_required == 2, "sector fight with an extra boss needs two kills")
	await _hit_enemy_base(game)
	await _hit_enemy_base(game)
	var bosses : Array[Entity] = _bosses(game, "boss_dreadnought")
	check(bosses.size() == 2, "hitting the base launches both bosses once (%d)" % bosses.size())
	check((battle.wave_manager.table as RunWaveTable).extra_boss == null and (game.enemy_base as AutoBase).pending_bosses.is_empty(), "no boss is left to spawn twice")
	if (bosses.size() == 2):
		_kill(bosses[0])
		check(!battle.done, "one dead boss does not win")
		_kill(bosses[1])
		check(battle.done and battle.boss_defeated, "both dead bosses win")
		check(Global.run.boss_coins == 2 * RunData.BOSS_COINS_ON_VICTORY, "each boss pays coins (%d)" % Global.run.boss_coins)
	await _close(game)

func _bomber() -> void:
	var game : GameRound = await _start(RunData.Objective.SHOOT_DOWN_BOMBER)
	var battle : CampaignBattle = game.campaign
	check(_bosses(game, RunData.BOMBER_BOSS_NAME).is_empty(), "the bomber starts held back")
	await _hit_enemy_base(game)
	var bombers : Array[Entity] = _bosses(game, RunData.BOMBER_BOSS_NAME)
	check(bombers.size() == 2 and battle.bosses_required == 2, "the extra boss is a second bomber (%d)" % bombers.size())
	check(_bosses(game, "boss_dreadnought").is_empty(), "no dreadnought joins the bomber objective")
	if (bombers.size() == 2):
		var gap : float = absf(bombers[0].global_position.x - bombers[1].global_position.x)
		check(gap > 60.0, "the two bombers do not spawn on top of each other (%.0f px)" % gap)
		check(is_equal_approx(bombers[0].entity_stats.health, bombers[1].entity_stats.health), "both bombers have the same health")
		_kill(bombers[0])
		check(!battle.done, "one dead bomber does not win")
		_kill(bombers[1])
		check(battle.done and battle.boss_defeated, "both dead bombers win")
		check(Global.run.boss_coins == 2 * RunData.BOSS_COINS_ON_VICTORY, "each bomber pays coins (%d)" % Global.run.boss_coins)
	await _close(game)

func _close(game : GameRound) -> void:
	game.queue_free()
	await _wait(0.5)
