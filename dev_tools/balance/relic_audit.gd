extends Node

const OUT_FILE : String = "res://extras/balance_reports/relic_audit_latest.md"

var lines : PackedStringArray = []

func _ready() -> void:
	SaveManager.use_test_directory()
	SaveManager.slot = 1
	var ids : Array = [&""]
	ids.append_array(RunData.RELICS.keys())
	ids.append_array(RunData.RISKS.keys())
	lines.append("| item | screws | base max | unit hp | speed | radar | gun interval | gun dmg | base dmg taken | build time | bomb dmg | bomb cd | gear drop | heal | reward | enemy hp | time |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for item : Variant in ids:
		await _trial(item as StringName)
	var file : FileAccess = FileAccess.open(OUT_FILE, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("\n".join(lines))
	get_tree().quit()

func _trial(id : StringName) -> void:
	var stats : PlayerStats = Global.player_stats.duplicate()
	stats.unlocked_entities = []
	stats.loadout = []
	stats.upgrade_levels = {}
	Global.player_stats = stats
	stats.add_entity(Global.CATALOG.find_unit("small"))
	var run : RunState = RunState.create(5)
	Global.run = run
	if (RunData.RELICS.has(id)):
		run.relics.append(id)
		run._recompute_max_hp()
		run.base_hp = run.base_max_hp
	var entry : Dictionary = run.map.get_node(0)
	entry["type"] = RunData.NodeType.BATTLE
	entry["objective"] = RunData.Objective.ESCORT
	entry["weather"] = RunData.Weather.CLEAR
	run.pending_node = 0
	run.stage = RunData.Stage.BRIEFING
	if (RunData.RISKS.has(id)):
		run.risks.append(id)
	run.start_battle()
	var game : GameRound = load("res://scenes/ui/naval_hud/naval_round.tscn").instantiate() as GameRound
	add_child(game)
	await get_tree().process_frame
	var ui : GameUI = game.get_node("CanvasLayer/GameUI") as GameUI
	var screws : int = ui.screw_label.total_value
	var unit_stats : BoatStats = Global.CATALOG.find_unit("small")
	var upgraded : EntityStats = Global.upgraded_entity(unit_stats)
	var build : float = Global.modify(Enums.UpgradeTarget.BASE, &"build_time", 1.0)
	var hp_before : float = game.ally_base.health_component.health
	var damage : Damage = Damage.new()
	damage.damage = 10.0
	(game.ally_base.health_component as BaseHealthComponent).handle_hit(damage)
	var taken : float = hp_before - game.ally_base.health_component.health
	lines.append("| %s | %d | %d | %.2f | %.0f | %d | %.1f | %.2f | %.1f | %.2f | %.2f | %.2f | %.2f | %.0f | %.2f | %.2f | %.0f |" % [
		str(id) if id != &"" else "(none)", screws, run.base_max_hp, upgraded.health, upgraded.speed, int(upgraded.radar_distance),
		Global.modify(Enums.UpgradeTarget.GUN, &"shoot_interval", 100.0), Global.modify(Enums.UpgradeTarget.GUN, &"damage", 1.0),
		taken, build, Global.modify(Enums.UpgradeTarget.SKILL, &"bomb_damage", 10.0), Global.modify(Enums.UpgradeTarget.SKILL, &"bomb_cooldown", 10.0),
		Global.modify(Enums.UpgradeTarget.BASE, &"gear_drop_chance", 0.26), run.modify(RunData.T_RUN, &"heal_after_battle", 0.0),
		run.modify(RunData.T_RUN, &"reward_mult", 1.0), run.modify(RunData.T_RUN, &"enemy_health", 1.0), game.campaign.time_limit])
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
