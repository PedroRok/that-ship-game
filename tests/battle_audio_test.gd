extends Node

const SOUND_ROOT : String = "res://assets/game/sounds/"
const LOADOUT : Array[String] = ["small", "medium", "cruiser", "flak", "torpedo", "plane", "submarine"]
const DEFERRED : Array[String] = ["objective_complete", "objective_failed", "upgrade_installed"]
const TIME_SCALE : float = 3.0

var failures : int = 0
var events : Array[Dictionary] = []
var peak_db : float = -200.0
var max_counts : Dictionary = {}

func _check(ok : bool, label : String) -> void:
	if (!ok):
		failures += 1
	print("PASS  " if ok else "FAIL  ", label)

func _ready() -> void:
	SaveManager.use_test_directory()
	_check_assets()
	Global.run = null
	Global.player_stats = Global.player_stats.duplicate()
	Global.player_stats.loadout.clear()
	for unit_name : String in LOADOUT:
		var stats : BoatStats = Global.CATALOG.find_unit(unit_name)
		if (!Global.player_stats.has_boat(unit_name)):
			Global.player_stats.unlocked_entities.append(stats)
		Global.player_stats.loadout.append(unit_name)
	var master : int = AudioServer.get_bus_index(&"Master")
	var master_db : float = AudioServer.get_bus_volume_db(master)
	AudioServer.set_bus_volume_db(master, -80.0)
	var game : GameRound = (load("res://scenes/ui/naval_hud/naval_round.tscn") as PackedScene).instantiate() as GameRound
	add_child(game)
	await get_tree().process_frame
	var audio : BattleAudio = BattleAudio.of(game)
	_check(audio != null and audio.get_parent() == game, "battle owns a BattleAudio registered in its context")
	if (!audio):
		_finish(master, master_db)
		return
	audio.sound_started.connect(func(event : StringName, at : Vector2) -> void: events.append({"event": event, "at": at, "t": Time.get_ticks_msec()}))
	var hud : Node = game.get("hud")
	var sandbox : Control = hud.get("demo") as Control
	var preview : BattleContext = sandbox.get("context") as BattleContext
	_check(preview != null and !preview.audio_enabled and preview.audio == null and BattleAudio.of(sandbox.get("viewport") as Node) == null, "HUD preview viewport stays silent")
	await _hud_cues(game, hud)
	await _projectile_cues(game, audio)
	await _dock_sequence(game)
	await _dense_battle(game, audio)
	var seen : Dictionary = {}
	for entry : Dictionary in events:
		seen[entry["event"]] = int(seen.get(entry["event"], 0)) + 1
	print("  events: ", seen)
	print("  max simultaneous voices (one-shot/loop/build): ", max_counts)
	for wanted : StringName in [&"light_cannon", &"hull_impact", &"naval_engine", &"dock_build", &"naval_launch", &"air_launch", &"air_engine", &"sub_propeller"]:
		_check(seen.has(wanted), "battle played %s" % wanted)
	_check(int(max_counts.get(SfxVoice.Kind.ONE_SHOT, 0)) <= BattleAudio.ONE_SHOT_CAP, "one-shot voices stay within %d" % BattleAudio.ONE_SHOT_CAP)
	_check(int(max_counts.get(SfxVoice.Kind.LOOP, 0)) <= BattleAudio.LOOP_CAP, "engine loops stay within %d" % BattleAudio.LOOP_CAP)
	_check(int(max_counts.get(SfxVoice.Kind.BUILD, 0)) <= BattleAudio.BUILD_CAP, "construction voices stay within %d" % BattleAudio.BUILD_CAP)
	if (DisplayServer.get_name() == "headless"):
		print("SKIP  peak measurement needs a real audio driver (run without --headless)")
	else:
		print("  WorldSFX peak under load: %.1f dBFS" % peak_db)
		_check(peak_db <= 0.0, "world mix stays below 0 dBFS")
	var context : BattleContext = BattleContext.of(game)
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(context.audio == null, "audio is released when the battle leaves the tree")
	_finish(master, master_db)

func _finish(master : int, master_db : float) -> void:
	AudioServer.set_bus_volume_db(master, master_db)
	Engine.time_scale = 1.0
	print("---- ALL PASSED" if failures == 0 else "---- %d FAILED" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _check_assets() -> void:
	var legacy_oggs : int = 0
	var approved_oggs : int = 0
	var wavs : int = 0
	var deferred : int = 0
	var stack : Array[String] = [SOUND_ROOT]
	while (!stack.is_empty()):
		var dir_path : String = stack.pop_back()
		for sub : String in DirAccess.get_directories_at(dir_path):
			stack.append(dir_path.path_join(sub))
		for file : String in DirAccess.get_files_at(dir_path):
			if (file.ends_with(".wav")):
				wavs += 1
			if (dir_path.contains("/battle/") and file.ends_with(".ogg")):
				if (file.ends_with("_v14.ogg") or file.ends_with("_v16.ogg")):
					legacy_oggs += 1
				else:
					approved_oggs += 1
				for stem : String in DEFERRED:
					if (file.contains(stem)):
						deferred += 1
	_check(legacy_oggs == 63, "63 legacy battle sounds present (%d)" % legacy_oggs)
	_check(wavs == 0, "no WAV files under %s" % SOUND_ROOT)
	_check(deferred == 0, "deferred cues 19-21 were not copied")
	var missing : int = 0
	var bad_loops : int = 0
	var expected_approved : int = 0
	for event : StringName in SfxCatalog.EVENTS:
		var streams : Array[AudioStream] = SfxCatalog.streams(event)
		var definition : Dictionary = SfxCatalog.EVENTS[event]
		var approved : Array = definition.get("approved", [])
		var expected : int = approved.size() if !approved.is_empty() else String(definition["takes"]).length()
		expected_approved += approved.size()
		missing += absi(expected - streams.size())
		for stream : AudioStream in streams:
			var ogg : AudioStreamOggVorbis = stream as AudioStreamOggVorbis
			if (!ogg or ogg.loop != SfxCatalog.is_loop(event)):
				bad_loops += 1
	for event : StringName in [&"light_cannon", &"antiair_shot"]:
		var paths : Array[String] = []
		for stream : AudioStream in SfxCatalog.streams(event):
			paths.append(stream.resource_path.get_file())
		_check(paths.size() == 3 and paths.all(func(p : String) -> bool: return p.ends_with("_v16.ogg")), "%s loads its three v16 takes %s" % [event, paths])
	_check(missing == 0, "every catalog take loads as a stream")
	_check(approved_oggs == expected_approved, "all new battle OGGs are registered")
	_check(bad_loops == 0, "only configured voices loop")
	for cue : StringName in HudSfx.CUES:
		var definition : Dictionary = HudSfx.CUES[cue]
		var streams : Array = definition.get("streams", [definition.get("stream")])
		_check(!streams.is_empty() and streams.all(func(stream : AudioStream) -> bool: return stream is AudioStreamOggVorbis), "HUD cue %s loads" % cue)

func _projectile_cues(game : GameRound, audio : BattleAudio) -> void:
	var manager : BulletManager = (game.get_node("ShipsManager") as ShipManager).bullet_manager
	var here : Vector2 = audio.listener_position()
	var missile : BulletMissile = preload("res://scenes/entities/bullets/missile.tscn").instantiate() as BulletMissile
	missile.process_mode = Node.PROCESS_MODE_DISABLED
	manager.handle_bullet_spawned(missile, here + Vector2(1800.0, 0.0), Vector2.RIGHT, 0.0)
	await _wait(0.15)
	_check(_count(&"missile_flight") == 0, "missile loop waits until in range")
	missile.global_position = here
	await _wait(0.15)
	_check(_count(&"missile_flight") == 1, "entering range starts one missile loop")
	missile.remove_bullet()
	await _wait(0.25)
	_check(_count(&"missile_explosion") == 1, "missile detonation plays one explosion")
	var torpedo : BulletTorpedo = preload("res://scenes/entities/bullets/torpedo.tscn").instantiate() as BulletTorpedo
	torpedo.process_mode = Node.PROCESS_MODE_DISABLED
	manager.handle_bullet_spawned(torpedo, Vector2(here.x, BulletTorpedo.MAX_DEPTH_Y), Vector2.RIGHT, 0.0)
	await _wait(0.15)
	_check(_count(&"torpedo_surface") == 0, "deep torpedo keeps surface loop silent")
	torpedo.global_position.y = BulletTorpedo.MIN_DEPTH_Y
	await _wait(0.15)
	_check(_count(&"torpedo_surface") == 1, "near-surface torpedo starts one loop")
	torpedo.queue_free()
	await _wait(0.25)
	var tails : bool = audio._voices.any(func(voice : SfxVoice) -> bool:
		return voice.busy and voice.event in [&"missile_flight", &"torpedo_surface"])
	_check(audio._projectiles.is_empty() and !tails, "projectile voices release after removal")

func _wait(seconds : float, audio : BattleAudio = null) -> void:
	var until : int = Time.get_ticks_msec() + int(seconds * 1000.0 / Engine.time_scale)
	while (Time.get_ticks_msec() < until):
		await get_tree().process_frame
		if (audio):
			_sample(audio)

func _sample(audio : BattleAudio) -> void:
	var counts : Dictionary = audio.active_counts()
	for kind : int in counts:
		max_counts[kind] = maxi(int(max_counts.get(kind, 0)), int(counts[kind]))
	var bus : int = AudioServer.get_bus_index(BattleAudio.BUS_NEAR)
	peak_db = maxf(peak_db, maxf(AudioServer.get_bus_peak_volume_left_db(bus, 0), AudioServer.get_bus_peak_volume_right_db(bus, 0)))

func _dock_sequence(game : GameRound) -> void:
	var base : Base = game.ally_base
	var sub : BoatStats = Global.CATALOG.find_unit("submarine")
	var dock : BaseDock = base.docks[BaseDock.Type.SUB]
	game.camera.actual_h_pos = base.global_position.x
	game.camera.global_position.x = base.global_position.x
	events.clear()
	var accepted : bool = base.start_build_ship(sub)
	_check(accepted and dock.active, "submarine build accepted in an active sub dock")
	await _wait(1.0)
	var building : bool = _count(&"dock_build") > 0
	await _wait(sub.produce_cd + BaseDock.FILL_TIME + BaseDock.DOOR_TIME + 0.6)
	var order : Array[StringName] = []
	for entry : Dictionary in events:
		var event : StringName = entry["event"]
		if (event in [&"sub_dock_fill", &"dock_release", &"sub_launch", &"sub_dock_drain"] and !order.has(event)):
			order.append(event)
	await _wait(8.0 + BaseDock.DOOR_TIME + 0.5)
	for entry : Dictionary in events:
		if (entry["event"] == &"sub_dock_drain" and !order.has(&"sub_dock_drain")):
			order.append(&"sub_dock_drain")
	_check(building, "construction ambience plays while the unit is built")
	var builds_after : int = 0
	var finished_at : int = Time.get_ticks_msec() - int((8.0 + BaseDock.DOOR_TIME + 0.5) * 1000.0 / Engine.time_scale)
	var dock_at : Vector2 = dock.constructor.global_position
	for entry : Dictionary in events:
		if (entry["event"] == &"dock_build" and int(entry["t"]) > finished_at and (entry["at"] as Vector2).distance_to(dock_at) < 60.0):
			builds_after += 1
	_check(builds_after == 0, "construction ambience stops scheduling after completion")
	print("  sub dock order: ", order)
	_check(order == [&"sub_dock_fill", &"dock_release", &"sub_launch", &"sub_dock_drain"], "sub dock order is fill -> door -> launch -> drain")

var _heard : Array[StringName] = []

func _on_cue(cue : StringName) -> void:
	_heard.append(cue)

func _hud_step(_sfx : HudSfx, action : Callable) -> Array[StringName]:
	_heard.clear()
	action.call()
	await get_tree().process_frame
	return _heard.duplicate()
func _hud_cues(game : GameRound, hud : Node) -> void:
	var sfx : HudSfx = hud.get("sfx") as HudSfx
	var ui : GameUI = game.get_node("CanvasLayer/GameUI") as GameUI
	sfx.cue_played.connect(_on_cue)
	var heard : Array[StringName] = await _hud_step(sfx, func() -> void: hud.call("_on_card_hover", 1))
	_check(heard == [&"hover"], "pointer entry plays hover only (%s)" % [heard])
	heard = await _hud_step(sfx, func() -> void: hud.call("_on_card_focus", 1))
	_check(heard.is_empty(), "focus after hover on the same card is silent (%s)" % [heard])
	heard = await _hud_step(sfx, func() -> void: hud.call("_on_card_focus", 2))
	_check(heard == [&"select"], "keyboard focus change plays select (%s)" % [heard])
	heard = await _hud_step(sfx, func() -> void: hud.call("_on_card_hover", 9))
	_check(heard.is_empty(), "empty slot hover is silent (%s)" % [heard])
	ui.screw_label.change_value(-ui.screw_label.total_value)
	heard = await _hud_step(sfx, func() -> void: hud.call("quick_build", 0))
	_check(heard == [&"denied"], "rejected order plays denied (%s)" % [heard])
	ui.screw_label.change_value(100)
	heard = await _hud_step(sfx, func() -> void: hud.call("quick_build", 0))
	_check(heard == [&"confirm"], "accepted order plays confirm (%s)" % [heard])
	var health : BaseHealthComponent = game.ally_base.health_component
	var full : float = health.health
	health.health = full * 0.2
	heard = await _hud_step(sfx, func() -> void: pass)
	_check(heard == [&"base_warning"], "crossing critical base HP plays the warning (%s)" % [heard])
	heard = await _hud_step(sfx, func() -> void: pass)
	_check(heard.is_empty(), "warning plays once while HP stays low")
	health.health = full
	await get_tree().process_frame
	health.health = full * 0.2
	heard = await _hud_step(sfx, func() -> void: pass)
	_check(heard == [&"base_warning"], "warning rearms after recovery")
	health.health = full
	await _wait(0.5)

func _count(event : StringName) -> int:
	var total : int = 0
	for entry : Dictionary in events:
		if (entry["event"] == event):
			total += 1
	return total

func _dense_battle(game : GameRound, audio : BattleAudio) -> void:
	Engine.time_scale = TIME_SCALE
	var ui : GameUI = game.get_node("CanvasLayer/GameUI") as GameUI
	var manager : ShipManager = game.get_node("ShipsManager") as ShipManager
	var foe : TeamStats = game.enemy_base.team_stats
	var mid : float = (game.ally_base.global_position.x + game.enemy_base.global_position.x) * 0.5
	for step : int in range(14):
		ui.screw_label.change_value(80)
		for unit_name : String in ["small", "medium", "plane", "cruiser"]:
			ui.spawn_entity(Global.CATALOG.find_unit(unit_name))
		for unit_name : String in ["small", "medium", "flak", "torpedo"]:
			var stats : BoatStats = Global.CATALOG.find_unit(unit_name)
			manager.handle_ship_spawn(Vector2(mid + 240.0 + randf() * 160.0, game.enemy_base.get_spawn_point().y), stats, foe)
		if (step % 4 == 0):
			manager.handle_ship_spawn(Vector2(mid + 120.0, 100.0), Global.CATALOG.find_unit("plane"), foe)
		game.camera.actual_h_pos = mid
		await _wait(3.0, audio)
