extends Node
func _ready() -> void:
	SaveManager.use_test_directory()
	Global.run = null
	Global.player_stats = Global.player_stats.duplicate()
	for starter : String in ["mini", "small"]:
		if (!Global.player_stats.has_boat(starter)):
			Global.player_stats.add_entity(Global.CATALOG.find_unit(starter))
	var flag : bool = Global.test_enemy_all_units
	var game : GameRound = (load("res://scenes/ui/naval_hud/naval_round.tscn") as PackedScene).instantiate() as GameRound
	add_child(game)
	Engine.time_scale = 8.0
	await get_tree().create_timer(1.5, true, false, true).timeout
	Engine.time_scale = 1.0
	var ok : bool = game.campaign == null and game.wave_manager != null and game.wave_manager.running
	print("PASS  " if ok else "FAIL  ", "classic mode uses the wave manager (wave %d)" % game.wave_manager.current_wave_number())
	print("PASS  " if Global.test_enemy_all_units == flag else "FAIL  ", "debug spawn flag untouched outside the campaign")
	var shown : float = float(game.get("enemy_max_hp"))
	var bar_ok : bool = is_equal_approx(shown, game.enemy_base.health_component.health)
	print("PASS  " if bar_ok else "FAIL  ", "enemy health bar maximum matches the base (%.0f)" % shown)
	get_tree().quit(0 if ok and bar_ok else 1)
