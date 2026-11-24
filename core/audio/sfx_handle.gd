class_name SfxHandle
extends RefCounted

var voice : SfxVoice
var serial : int = 0

func _init(target : SfxVoice) -> void:
	voice = target
	serial = target.serial

func active() -> bool:
	return is_instance_valid(voice) and voice.busy and voice.serial == serial

func fade(time : float) -> void:
	if (active()):
		voice.fade_out(time)

func set_gain(value : float) -> void:
	if (active()):
		voice.gain = value
