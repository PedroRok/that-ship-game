class_name RunFlow
extends RefCounted

static func menu_for(stage : int) -> Global.Menu:
	match stage:
		RunData.Stage.BRIEFING:
			return Global.Menu.RUN_BRIEFING
		RunData.Stage.BATTLE:
			return Global.Menu.GAME
		RunData.Stage.NODE_DONE:
			return Global.Menu.RUN_NODE_DONE
		RunData.Stage.RELIC:
			return Global.Menu.RUN_RELIC
		RunData.Stage.EVENT:
			return Global.Menu.RUN_EVENT
		RunData.Stage.SHIPYARD:
			return Global.Menu.RUN_SHIPYARD
		RunData.Stage.ENDED:
			return Global.Menu.RUN_END
	return Global.Menu.RUN_MAP

static func has_saved_run() -> bool:
	return Global.run != null or SaveManager.has_run()

static func start_new_run() -> void:
	SaveManager.delete_run()
	Global.run = RunState.create()
	if (Global.player_stats.campaigns_started == 0):
		Global.run.soften_first_floor()
	Global.player_stats.campaigns_started += 1
	Global.save_game()
	advance()

static func continue_run() -> void:
	if (Global.run == null):
		Global.run = SaveManager.load_run()
	if (Global.run == null):
		return
	advance()

static func advance() -> void:
	var run : RunState = Global.run
	if (run == null):
		Global.change_scene(Global.Menu.CAMPAIGN_SELECT)
		return
	persist()
	Global.change_scene(menu_for(run.stage))

static func persist() -> void:
	var run : RunState = Global.run
	if (run == null):
		return
	if (run.stage == RunData.Stage.ENDED):
		SaveManager.delete_run()
	else:
		SaveManager.save_run(run)

static func leave_to_menu() -> void:
	Global.run = null
	SaveManager.delete_run()
	Global.start_mode = Global.StartMode.NONE
	Global.change_scene(Global.Menu.CAMPAIGN_SELECT)

static func abandon() -> void:
	if (Global.run):
		Global.run.abandon()
	leave_to_menu()
