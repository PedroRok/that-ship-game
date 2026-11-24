class_name HudSfx
extends Node

const BUS : StringName = &"UI"

const CUES : Dictionary = {
	&"hover": {"stream": preload("res://assets/game/sounds/hud/hud_hover.ogg"), "db": -8.0},
	&"select": {"stream": preload("res://assets/game/sounds/hud/hud_select.ogg"), "db": -6.0},
	&"confirm": {"stream": preload("res://assets/game/sounds/hud/hud_confirm.ogg"), "db": -4.0},
	&"denied": {"stream": preload("res://assets/game/sounds/hud/hud_denied.ogg"), "db": -5.0},
	&"base_warning": {"stream": preload("res://assets/game/sounds/hud/hud_base_warning.ogg"), "db": -12.0},
}

signal cue_played(cue : StringName)

var _players : Dictionary = {}

func _ready() -> void:
	for cue : StringName in CUES:
		var player : AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = CUES[cue]["stream"]
		player.volume_db = float(CUES[cue]["db"])
		player.bus = BUS
		add_child(player)
		_players[cue] = player

func play(cue : StringName) -> void:
	var player : AudioStreamPlayer = _players.get(cue) as AudioStreamPlayer
	if (player):
		player.play()
		cue_played.emit(cue)
