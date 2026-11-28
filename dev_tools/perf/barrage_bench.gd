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
	_fire(game)
	await _wait(WINDOW_SECONDS + 6.0)
	await _measure("no barrage", view, false)
	for round_index : int in 2:
		_fire(game)
		await _measure("barrage", view, round_index == 0)
		await _wait(6.0)
	get_tree().quit()

func _fire(game : GameRound) -> void:
	game.skill_manager.command = SkillManager.COMMAND_MAX
	game.skill_manager.fire(SkillCatalog.FLAK)

func _wait(seconds : float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _measure(label : String, view : RID, shot : bool) -> void:
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
		if (shot and !taken and now - begin > 2800000):
			taken = true
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OUT_DIR + "barrage.png")
			last = Time.get_ticks_usec()
	var total : float = 0.0
	for value : float in frames:
		total += value
	frames.sort()
	var count : int = frames.size()
	print("%-11s frames %5d  avg %.2f ms  99%% %.2f ms  worst %.2f ms  gpu %.2f ms  render cpu %.2f ms  process %.2f ms" % [
			label, count, total / count, frames[int(count * 0.99)], frames[count - 1], gpu / count, render_cpu / count, script_time / count])
