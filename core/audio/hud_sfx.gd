class_name HudSfx
extends Node

const BUS : StringName = &"UI"

const CUES : Dictionary = {
	&"alert_air_threat": {"streams": [preload("res://assets/game/sounds/hud/alert_air_threat_a_r01.ogg")], "db": -3.0},
	&"alert_boss": {"streams": [preload("res://assets/game/sounds/hud/alert_boss_e_r03.ogg")], "db": -4.0},
	&"alert_sub_threat": {"streams": [preload("res://assets/game/sounds/hud/alert_sub_threat_b_r01.ogg")], "db": -3.0},
	&"hud_command_ready": {"streams": [preload("res://assets/game/sounds/hud/hud_command_ready_b_r01.ogg")], "db": -2.0},
	&"objective_complete": {"streams": [preload("res://assets/game/sounds/hud/objective_complete_b_r01.ogg")], "db": -2.0},
	&"objective_failed": {"streams": [preload("res://assets/game/sounds/hud/objective_failed_b_r02.ogg")], "db": -2.0},
	&"pickup_gear": {"streams": [preload("res://assets/game/sounds/hud/pickup_gear_c_r01.ogg")], "db": -2.0},
	&"pickup_screw": {"streams": [preload("res://assets/game/sounds/hud/pickup_screw_b_r01.ogg")], "db": -2.0},
	&"result_defeat": {"streams": [preload("res://assets/game/sounds/hud/result_defeat_a_r02.ogg")], "db": -3.0},
	&"shop_purchase": {"streams": [preload("res://assets/game/sounds/hud/shop_purchase_a_r01.ogg")], "db": -2.0},
	&"skill_bomb_warning": {"streams": [preload("res://assets/game/sounds/hud/skill_bomb_warning_e_r01.ogg")], "db": -3.0},
	&"thunder_distant": {"streams": [preload("res://assets/game/sounds/hud/thunder_distant_a_r01.ogg"), preload("res://assets/game/sounds/hud/thunder_distant_b_r01.ogg"), preload("res://assets/game/sounds/hud/thunder_distant_c_r01.ogg")], "db": -2.0},
	&"upgrade_installed": {"streams": [preload("res://assets/game/sounds/hud/upgrade_installed_b_r01.ogg")], "db": -2.0},
	&"hover": {"stream": preload("res://assets/game/sounds/hud/hud_hover.ogg"), "db": -8.0},
	&"select": {"stream": preload("res://assets/game/sounds/hud/hud_select.ogg"), "db": -6.0},
	&"confirm": {"stream": preload("res://assets/game/sounds/hud/hud_confirm.ogg"), "db": -4.0},
	&"denied": {"stream": preload("res://assets/game/sounds/hud/hud_denied.ogg"), "db": -5.0},
	&"base_warning": {"stream": preload("res://assets/game/sounds/hud/hud_base_warning.ogg"), "db": -12.0},
}

signal cue_played(cue : StringName)

var _players : Dictionary = {}
var _last_takes : Dictionary = {}

func _ready() -> void:
	for cue : StringName in CUES:
		var players : Array[AudioStreamPlayer] = []
		for stream : AudioStream in CUES[cue].get("streams", [CUES[cue].get("stream")]):
			var player : AudioStreamPlayer = AudioStreamPlayer.new()
			player.stream = stream
			player.volume_db = float(CUES[cue]["db"])
			player.bus = BUS
			add_child(player)
			players.append(player)
		_players[cue] = players

func play(cue : StringName) -> void:
	if (!_players.has(cue)):
		return
	var players : Array[AudioStreamPlayer] = _players[cue]
	var take : int = 0
	if (players.size() > 1):
		var last : int = int(_last_takes.get(cue, -1))
		take = randi() % players.size()
		if (take == last):
			take = (take + 1 + randi() % (players.size() - 1)) % players.size()
		_last_takes[cue] = take
	players[take].play()
	cue_played.emit(cue)

static func configure_pickup(player : AudioStreamPlayer, cue : StringName) -> void:
	var definition : Dictionary = CUES[cue]
	player.stream = definition["streams"][0] as AudioStream
	player.volume_db = float(definition["db"])
