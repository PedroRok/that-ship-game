extends Node

const OUT_DIR : String = "res://extras/art_preview/modes_2026-11-25/"

var _failed : int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.use_test_directory()
	get_window().size = Vector2i(1280, 720)
	Global.player_stats = Global.player_stats.duplicate()
	BattleIntro.force_show = true
	var run : RunState = RunState.create(101)
	Global.run = run
	run.pending_node = 0
	run.focus_node = 0
	run.stage = RunData.Stage.BRIEFING
	run.start_battle()
	var game : Node = (load("res://scenes/ui/naval_hud/naval_round.tscn") as PackedScene).instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	await _wait(0.15)
	var intro : BattleIntro = game.get_node("BattleIntro") as BattleIntro
	_check(intro._root.modulate.a < 0.9, "intro fades in")
	await _shot("intro_fade_in.png")
	await _until(intro, BattleIntro.MISSION_DELAY - 0.5)
	_check(!intro._mission.visible, "mission waits before showing")
	await _until(intro, BattleIntro.LIST_DELAY - 0.2)
	_check(!intro._panel.visible and !intro._weather.visible, "mission shows first")
	await _until(intro, BattleIntro.WEATHER_DELAY - 0.2)
	_check(intro._panel.visible and !intro._weather.visible, "enemy fleet shows second")
	await _until(intro, BattleIntro.WEATHER_DELAY + BattleIntro.PANEL_FADE + 0.1)
	_check(is_equal_approx(intro._weather.modulate.a, 1.0), "weather shows third")
	_check(is_equal_approx(intro._root.modulate.a, 1.0) and is_equal_approx(intro._panel.modulate.a, 1.0), "intro fully visible (root %.2f, list %.2f, t %.2f)" % [intro._root.modulate.a, intro._panel.modulate.a, intro._time])
	await _shot("intro_full.png")
	intro.close()
	await _wait(0.2)
	_check(intro._root.modulate.a < 0.9, "intro fades out")
	await _shot("intro_fade_out.png")
	await _wait(1.55)
	var info : BattleInfoPanel = game.find_child("BattleInfo", true, false) as BattleInfoPanel
	_check(info.visible and info.modulate.a < 0.9, "compact mission fades in after the intro")
	await _wait(0.8)
	_check(is_equal_approx(info.modulate.a, 1.0), "compact mission ends opaque")
	_check(info._notice.visible and info._notice.modulate.a > 0.9, "weather notice shows under the compact mission")
	await _shot("intro_after.png")
	await _wait(BattleInfoPanel.WEATHER_SECONDS + 0.5)
	_check(info._notice.modulate.a < 0.1, "weather notice goes away")
	BattleIntro.force_show = false
	print("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)

func _until(intro : BattleIntro, time : float) -> void:
	while (intro._time < time):
		await get_tree().process_frame

func _check(ok : bool, text : String) -> void:
	if (!ok):
		_failed += 1
	print("PASS  " if ok else "FAIL  ", text)

func _wait(seconds : float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _shot(file : String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + file)
