extends Node

const FORMAT : int = 1
const BUILD : String = "2026-11-28d"
const SNAPSHOT_SECONDS : float = 3.0
const FOLDER : String = "playtest/"
const DATA_FILE : String = "battles.jsonl"
const ID_FILE : String = "player_id.txt"
const FORCE_ARG : String = "playtest_force"

var _game : GameRound
var _run : RunState
var _record : Dictionary = {}
var _names : Array[String] = []
var _time : float = 0.0
var _snapshot_clock : float = 0.0
var _queues : Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = 1000
	process_physics_priority = 1000
	_add_translation("en", "Export playtest data", "Battle decisions are recorded on this computer.", "Saved: %s", "Nothing recorded yet.")
	_add_translation("pt_BR", "Exportar dados de teste", "Suas decisões de batalha são gravadas neste computador.", "Salvo: %s", "Nada gravado ainda.")
	get_tree().node_added.connect(_on_node_added)

func _add_translation(locale : String, button : String, notice : String, saved : String, empty : String) -> void:
	var translation : Translation = Translation.new()
	translation.locale = locale
	translation.add_message("playtest.export", button)
	translation.add_message("playtest.notice", notice)
	translation.add_message("playtest.saved", saved)
	translation.add_message("playtest.empty", empty)
	TranslationServer.add_translation(translation)

func _on_node_added(node : Node) -> void:
	if (node is GameRound):
		node.ready.connect(_start.bind(node as GameRound), CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	elif (node is MainMenu):
		node.ready.connect(_add_button.bind(node as MainMenu), CONNECT_ONE_SHOT | CONNECT_DEFERRED)

func _directory() -> String:
	return "user://" + FOLDER

func _recording_allowed() -> bool:
	if (OS.get_cmdline_user_args().has(FORCE_ARG)):
		return true
	return BattleLog.enabled() and SaveManager.directory == "user://" and DisplayServer.get_name() != "headless"

func _start(game : GameRound) -> void:
	_finish()
	if (!is_instance_valid(game) or !_recording_allowed()):
		return
	_game = game
	_run = Global.run if (game.campaign != null) else null
	_names = []
	_time = 0.0
	_snapshot_clock = 0.0
	_queues = {}
	var fleet : Array = []
	for stats : EntityStats in Global.player_stats.loadout_entities():
		var guns : Array[int] = []
		var boat : BoatStats = stats as BoatStats
		if (boat):
			for index : int in boat.gun_slots.size():
				guns.append(Global.gun_type_for(boat.name, index, boat.gun_slots[index]))
		fleet.append([_unit_id(stats.name), Global.screw_cost(stats), guns])
	var skills : Array[String] = []
	for entry_name : String in Global.player_stats.loadout:
		if (SkillCatalog.find(entry_name)):
			skills.append(entry_name)
	_record = {"v": FORMAT, "build": BUILD, "at": int(Time.get_unix_time_from_system()), "fleet": fleet,
			"skills": skills, "creative": Global.creative_mode,
			"up": Global.player_stats.upgrade_levels.duplicate(), "dist": int(game.base_distance), "ev": [], "res": null}
	if (_run != null):
		var entry : Dictionary = _run.map.get_node(_run.pending_node)
		_record.merge({"obj": int(entry["objective"]), "floor": int(entry["col"]), "type": int(entry["type"]),
				"weather": _run.battle_weather(), "seed": _run.seed_value, "node": _run.pending_node, "hp": _run.base_hp,
				"hpmax": _run.base_max_hp})
	else:
		_record["obj"] = -1
	if (game.skill_manager):
		game.skill_manager.skill_used.connect(_on_skill)
	var screws : BarValue = _screw_bar()
	if (screws):
		screws.value_change.connect(_on_screws)
	game.tree_exiting.connect(_finish)
	_remember_queues()

func _ui() -> GameUI:
	return _game.get_node_or_null("CanvasLayer/GameUI") as GameUI

func _screw_bar() -> BarValue:
	var ui : GameUI = _ui()
	return ui.screw_label if ui else null

func _unit_id(unit_name : String) -> int:
	var found : int = _names.find(unit_name)
	if (found < 0):
		_names.append(unit_name)
		found = _names.size() - 1
	return found

func _remember_queues() -> void:
	for dock : int in _game.ally_base.queues:
		_queues[dock] = (_game.ally_base.queues[dock] as Array).duplicate()

func _on_screws(_value : int) -> void:
	if (_record.is_empty() or !is_instance_valid(_game)):
		return
	for dock : int in _game.ally_base.queues:
		var now : Array = _game.ally_base.queues[dock]
		var before : Array = _queues.get(dock, [])
		if (now.size() > before.size()):
			for index : int in range(before.size(), now.size()):
				_event("u", [_unit_id((now[index] as BoatStats).name)])
		elif (now.size() < before.size()):
			_event("c", [])
	_remember_queues()

func _on_skill(skill_id : StringName, where : Vector2) -> void:
	_event("x", [String(skill_id), _across(where.x), int(where.y)])

func _across(x : float) -> int:
	var from : float = _game.ally_base.global_position.x
	var span : float = maxf(_game.enemy_base.global_position.x - from, 1.0)
	return roundi((x - from) / span * 100.0)

func _event(kind : String, data : Array) -> void:
	if (_record.is_empty()):
		return
	(_record["ev"] as Array).append([snappedf(_time, 0.1), kind, data, _state()])

func _state() -> Array:
	var ally : Dictionary = {}
	var enemy : Dictionary = {}
	var ally_front : float = 0.0
	var enemy_front : float = 100.0
	for unit : Entity in BattleContext.of(_game).entities:
		if (!unit.enabled or unit.destroyed or unit.entity_stats == null or unit.team_stats == null):
			continue
		var id : int = _unit_id(unit.entity_stats.name)
		var across : int = _across(unit.global_position.x)
		if (unit.team_stats.team_id == 1):
			ally[id] = int(ally.get(id, 0)) + 1
			ally_front = maxf(ally_front, across)
		else:
			enemy[id] = int(enemy.get(id, 0)) + 1
			enemy_front = minf(enemy_front, across)
	var screws : BarValue = _screw_bar()
	var escort : int = -1
	var hunted : int = 0
	var enemy_bank : int = -1
	var battle : CampaignBattle = _game.campaign
	if (battle):
		hunted = battle.hunted
		if (is_instance_valid(battle.escort)):
			escort = _across(battle.escort.global_position.x)
		enemy_bank = int(battle.commander.bank)
	return [screws.total_value if screws else 0, int(_game.ally_base.health_component.health),
			int(_game.enemy_base.health_component.health), int(ally_front), int(enemy_front), _pairs(ally), _pairs(enemy),
			escort, hunted, enemy_bank]

func _pairs(table : Dictionary) -> Array[int]:
	var result : Array[int] = []
	for key : int in table:
		result.append(key)
		result.append(int(table[key]))
	return result

func _physics_process(delta : float) -> void:
	if (_record.is_empty() or !is_instance_valid(_game)):
		return
	if (_game.game_ended):
		_finish()
		return
	_time += delta
	_snapshot_clock -= delta
	if (_snapshot_clock <= 0.0):
		_snapshot_clock = SNAPSHOT_SECONDS
		_event("s", [])

func _process(_delta : float) -> void:
	if (!_record.is_empty() and is_instance_valid(_game)):
		_remember_queues()

func _finish() -> void:
	if (_record.is_empty()):
		return
	var result : Array = [0, snappedf(_time, 0.1), 0]
	if (is_instance_valid(_game) and _game.game_ended):
		var success : bool = false
		if (_run != null and _game.ally_base.health_component.health > 0.0):
			success = bool(_run.node_result.get("success", false)) or _run.result == RunData.Result.WON
		result = [1 if success else 2, snappedf(_time, 0.1), int(_game.ally_base.health_component.health)]
	_record["res"] = result
	_record["names"] = _names
	_append(JSON.stringify(_record))
	_record = {}
	_game = null
	_run = null

func _append(line : String) -> void:
	DirAccess.make_dir_recursive_absolute(_directory())
	var path : String = _directory() + DATA_FILE
	var file : FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if (file == null):
		push_warning("Could not write playtest data: %s" % error_string(FileAccess.get_open_error()))
		return
	file.seek_end()
	file.store_line(line)
	file.close()

func _player_id() -> String:
	var path : String = _directory() + ID_FILE
	if (FileAccess.file_exists(path)):
		return FileAccess.get_file_as_string(path).strip_edges()
	var id : String = Crypto.new().generate_random_bytes(4).hex_encode()
	DirAccess.make_dir_recursive_absolute(_directory())
	var file : FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if (file):
		file.store_string(id)
		file.close()
	return id

func export_to(folder : String) -> String:
	var path : String = _directory() + DATA_FILE
	if (!FileAccess.file_exists(path)):
		return ""
	var packed : PackedByteArray = FileAccess.get_file_as_bytes(path).compress(FileAccess.COMPRESSION_GZIP)
	var target : String = folder.path_join("shiping_playtest_%s_%d.gz" % [_player_id(), int(Time.get_unix_time_from_system())])
	var file : FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if (file == null):
		push_warning("Could not export playtest data: %s" % error_string(FileAccess.get_open_error()))
		return ""
	file.store_buffer(packed)
	file.close()
	return target

func _add_button(menu : MainMenu) -> void:
	if (!is_instance_valid(menu)):
		return
	var footer : HBoxContainer = menu.content.get_child(menu.content.get_child_count() - 1) as HBoxContainer
	if (footer == null):
		return
	var button : Button = menu._button("playtest.export", false, 8)
	button.custom_minimum_size.x = 320
	button.tooltip_text = "playtest.notice"
	footer.add_child(button)
	footer.move_child(button, 1)
	var status : Label = menu._label("playtest.notice", 8, RunScreen.TEXT_SOFT)
	menu.content.add_child(status)
	menu.content.move_child(status, footer.get_index())
	button.pressed.connect(_on_export_pressed.bind(status))

func _on_export_pressed(status : Label) -> void:
	var folder : String = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	var target : String = export_to(folder)
	if (target.is_empty()):
		status.text = "playtest.empty"
		return
	status.text = (Loc.t("playtest.saved") % target).to_upper()
	OS.shell_show_in_file_manager(target)
