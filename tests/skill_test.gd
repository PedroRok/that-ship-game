extends Node

const OUT_DIR : String = "res://extras/art_preview/skills/"

var failures : int = 0

func check(ok : bool, label : String) -> void:
	print("PASS  " if ok else "FAIL  ", label)
	if (!ok):
		failures += 1

func _shot(file : String) -> void:
	if (DisplayServer.get_name() == "headless"):
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + file)

func _wait(seconds : float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _ready() -> void:
	SaveManager.use_test_directory()
	if (DisplayServer.get_name() != "headless"):
		get_window().size = Vector2i(1280, 720)
		Loc.set_language("pt_BR")
	Global.run = null
	Global.player_stats = Global.player_stats.duplicate()
	Global.player_stats.creative = false
	Global.player_stats.upgrade_levels = {}
	Global.player_stats.add_entity(Global.CATALOG.find_unit("small"))
	await _unlocks()
	await _battle()
	print("---- ", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _unlocks() -> void:
	var stats : PlayerStats = Global.player_stats
	check(stats.has_boat("skill_repair"), "repair is available from the start")
	check(!stats.has_boat("skill_supply") and !stats.has_boat("skill_flak") and !stats.has_boat("skill_bomb"), "the other skills start locked")
	stats.loadout = ["small", "skill_repair", "skill_bomb", "skill_boost"]
	stats.sanitize_loadout()
	check(stats.loadout == (["small", "skill_repair"] as Array[String]), "locked and removed skills leave the loadout")
	for id : String in ["r_unlock_supply", "r_unlock_flak", "r_unlock_bomb"]:
		stats.upgrade_levels[StringName(id)] = 1
	stats.loadout = ["small", "skill_repair", "skill_supply", "skill_flak", "skill_bomb"]
	stats.sanitize_loadout()
	check(stats.loadout.size() == 5 and stats.loadout_entities().size() == 1, "researched skills stay and are not spawnable units")
	var shop : ShopMenu = ShopMenu.new()
	add_child(shop)
	await get_tree().process_frame
	shop._set_filter("shop.skills")
	check(shop.grid.get_child_count() == 4, "skills filter lists the four skills")
	shop._select_skill(SkillCatalog.find("skill_repair"))
	check(shop.skill_info.visible and shop.skill_info_label.text == Loc.t("skill.repair_desc").to_upper(), "shop detail shows the skill description")
	await _wait(0.5)
	await _shot("shop_skill.png")
	shop.queue_free()
	var research : Node = (load("res://scenes/ui/research/research_menu.tscn") as PackedScene).instantiate()
	add_child(research)
	await _wait(0.5)
	await _shot("research_skills.png")
	research.queue_free()

func _spawn(game : GameRound, unit_name : String, base : Base, at : Vector2) -> Entity:
	var manager : ShipManager = game.get_node("ShipsManager") as ShipManager
	var before : int = manager.get_child_count()
	manager.handle_ship_spawn(at, Global.CATALOG.find_unit(unit_name), base.team_stats)
	var unit : Entity = manager.get_child(before) as Entity
	unit.entry_x = NAN
	unit.global_position = at
	return unit

func _health(unit : Entity) -> HealthComponent:
	return unit.get_node("HealthComponent") as HealthComponent

func _clear_enemies(game : GameRound) -> void:
	for unit : Entity in BattleContext.of(game.ally_base).entities.duplicate():
		if (unit.team_stats.team_id != 1):
			unit.queue_free()

func _barrage_flying(game : GameRound) -> void:
	var counts : Array[int] = [0, 0, 0]
	var left : float = game.ally_base.global_position.x
	for round_index : int in 6:
		for unit : Entity in BattleContext.of(game.ally_base).entities.duplicate():
			unit.queue_free()
		await _wait(0.3)
		seed(11 + round_index)
		var health : Array[HealthComponent] = []
		for index : int in 8:
			var unit : Entity = _spawn(game, "plane", game.ally_base, Vector2(left + 250.0 + 150.0 * float(index), 100.0 + 20.0 * float(index % 4)))
			health.append(_health(unit))
		await _wait(0.5)
		for component : HealthComponent in health:
			component.default_health = 1000.0
			component.actual_health = 1000.0
		game.skill_manager.command = SkillManager.COMMAND_MAX
		game.skill_manager.fire(SkillCatalog.FLAK)
		var worst : Array[float] = []
		for component : HealthComponent in health:
			worst.append(component.actual_health)
		for step : int in 55:
			await _wait(0.1)
			for index : int in health.size():
				if (is_instance_valid(health[index])):
					worst[index] = minf(worst[index], health[index].actual_health)
		for value : float in worst:
			counts[clampi(roundi((1000.0 - value) / SkillManager.FLAK_DAMAGE), 0, 2)] += 1
	var total : int = counts[0] + counts[1] + counts[2]
	var hurt : int = counts[1] + counts[2]
	check(hurt >= total / 2, "the barrage hurts flying allied aircraft (of %d: none %d, one burst %d, two or more %d)" % [total, counts[0], counts[1], counts[2]])
	for unit : Entity in BattleContext.of(game.ally_base).entities.duplicate():
		unit.queue_free()
	await _wait(1.5)

func _dark_pixels(file : String) -> int:
	await RenderingServer.frame_post_draw
	var image : Image = get_viewport().get_texture().get_image()
	image.save_png(OUT_DIR + file)
	var count : int = 0
	for y : int in range(45, 330, 2):
		for x : int in range(0, image.get_width(), 2):
			var pixel : Color = image.get_pixel(x, y)
			if (pixel.r < 0.35 and pixel.g < 0.4 and pixel.b < 0.45):
				count += 1
	return count

func _barrage_pixels(game : GameRound) -> void:
	if (DisplayServer.get_name() == "headless"):
		return
	game.camera.set_process(false)
	game.camera.global_position.x = (game.ally_base.global_position.x + game.enemy_base.global_position.x) * 0.5
	await _wait(5.0)
	game.skill_manager.command = SkillManager.COMMAND_MAX
	game.skill_manager.fire(SkillCatalog.FLAK)
	await _wait(2.8)
	var shown : int = await _dark_pixels("barrage_particles.png")
	(BattleContext.of(game.ally_base).flak_smoke as FlakBurstParticles).hide()
	var hidden : int = await _dark_pixels("barrage_without.png")
	check(shown > hidden + 500, "flak particles are visible mid map (dark pixels: with %d, hidden %d)" % [shown, hidden])
	game.camera.set_process(true)

func _gun_flak(game : GameRound) -> void:
	var context : BattleContext = BattleContext.of(game.ally_base)
	var shell : BulletFlak = (load("res://scenes/entities/bullets/flak.tscn") as PackedScene).instantiate() as BulletFlak
	context.bullets.add_child(shell)
	shell.global_position = Vector2(game.ally_base.global_position.x + 400.0, 150.0)
	var before : int = (context.flak_smoke as FlakBurstParticles).emitted if is_instance_valid(context.flak_smoke) else 0
	var radius : float = shell.burst_radius
	shell._burst()
	var system : FlakBurstParticles = context.flak_smoke as FlakBurstParticles
	check(system != null and system.emitted - before == FlakBurstParticles.grains_for(radius) + FlakBurstParticles.FLASH_GRAINS,
			"anti-air guns use the same dense particles")

func _battle() -> void:
	var game : GameRound = (load("res://scenes/ui/naval_hud/naval_round.tscn") as PackedScene).instantiate() as GameRound
	add_child(game)
	await _wait(0.5)
	game.wave_manager.stop()
	game.endless.set_process(false)
	var hud : Control = game.get("hud") as Control
	var manager : SkillManager = game.skill_manager
	var ui : GameUI = game.get_node("CanvasLayer/GameUI") as GameUI
	check(manager.command < 2.0, "the command bar starts empty (%.1f)" % manager.command)
	var before : float = manager.command
	manager._process(10.0)
	check(is_equal_approx(manager.command - before, 10.0), "the command bar gains one per second")
	check(!manager.activate(SkillCatalog.find("skill_supply")), "no skill without command")
	hud.call("_select", 4)
	check((hud.get("demo_unavailable") as Label).text == Loc.t("skill.bomb_desc").to_upper(), "battle HUD preview shows the skill description")

	manager.command = SkillManager.COMMAND_MAX
	var screws : int = ui.screw_label.total_value
	hud.call("quick_build", 2)
	check(is_equal_approx(roundf(manager.command), SkillManager.COMMAND_MAX - SkillCatalog.SUPPLY_COST), "supply spends command, not screws")
	await _wait(10.0)
	check(ui.screw_label.total_value >= screws + SkillManager.SUPPLY_AMOUNT, "supply screws are collected (%d -> %d)" % [screws, ui.screw_label.total_value])

	var water : float = game.ally_base.get_spawn_point().y
	var ship : Entity = _spawn(game, "medium", game.ally_base, Vector2(game.ally_base.global_position.x + 450.0, water))
	await _wait(0.5)
	manager.command = SkillManager.COMMAND_MAX
	check(!manager.fire(SkillCatalog.REPAIR, ship.global_position) and manager.command >= SkillManager.COMMAND_MAX - 1.0, "repair charges nothing without damaged units")
	_health(ship).actual_health = _health(ship).default_health * 0.2
	check(manager.fire(SkillCatalog.REPAIR, ship.global_position), "repair works on a damaged ship")
	await _wait(0.6)
	await _shot("repair.png")
	await _wait(3.0)
	var share : float = _health(ship).actual_health / _health(ship).default_health
	check(is_equal_approx(snappedf(share, 0.01), 0.7), "repair restores half of the health (%.2f)" % share)

	_clear_enemies(game)
	manager.command = SkillManager.COMMAND_MAX
	check(manager.fire(SkillCatalog.FLAK), "flak barrage fires")
	await _wait(0.8)
	var system : FlakBurstParticles = BattleContext.of(game.ally_base).flak_smoke as FlakBurstParticles
	check(system != null and system.emitted > FlakBurstParticles.grains_for(SkillManager.FLAK_RADIUS), "the barrage uses the shared flak particles")
	await _shot("flak.png")
	await _wait(5.0)

	_gun_flak(game)
	await _barrage_flying(game)
	await _barrage_pixels(game)

	var base_health : float = game.ally_base.health_component.health
	var enemy_health : float = game.enemy_base.health_component.health
	var target : Entity = _spawn(game, "mini", game.ally_base, Vector2(game.ally_base.global_position.x + 450.0, water))
	await _wait(0.3)
	target.set_deferred("freeze", true)
	_clear_enemies(game)
	seed(7)
	for spot : Vector2 in [target.global_position, game.ally_base.get_center_pos(), game.enemy_base.get_center_pos()]:
		manager.command = SkillManager.COMMAND_MAX
		manager.fire(SkillCatalog.BOMB, spot)
	await _wait(0.9)
	await _shot("bombs.png")
	await _wait(3.0)
	check(game.ally_base.health_component.health == base_health and game.enemy_base.health_component.health == enemy_health, "bombardment never hurts a base")
	check(!is_instance_valid(target) or target.destroyed or _health(target).actual_health < _health(target).default_health, "bombardment hurts allied units")
	manager.command = SkillManager.COMMAND_MAX
	hud.call("quick_build", 1)
	check(manager.is_targeting(SkillCatalog.REPAIR), "repair enters aiming")
	hud.call("quick_build", 1)
	check(!manager.is_targeting(), "selecting it again cancels the aim")
