class_name SfxVoice
extends Node2D

enum Kind { ONE_SHOT, LOOP, BUILD }

const SILENT : float = 0.0005
const SMOOTH_RATE : float = 9.0
const PANNING : float = 0.6
const DISTANCE_EXPONENT : float = 1.5

const FAR_MUFFLE : float = 0.55
const MAX_ZOOM : float = 2.0

static var view_zoom : float = 1.0

var kind : Kind = Kind.ONE_SHOT
var event : StringName = &""
var priority : int = 0
var serial : int = 0
var level : float = 1.0
var gain : float = 1.0
var audible : float = 0.0
var follow : Node2D
var busy : bool = false

var _range : Vector3 = Vector3.ONE
var _looping : bool = false
var _dry : AudioStreamPlayer2D
var _wet : AudioStreamPlayer2D
var _dry_gain : float = 0.0
var _wet_gain : float = 0.0
var _fade_time : float = 0.0
var _fade_left : float = -1.0

func _init() -> void:
	_dry = _make_player(BattleAudio.BUS_NEAR)
	_wet = _make_player(BattleAudio.BUS_FAR)

func _make_player(bus : StringName) -> AudioStreamPlayer2D:
	var player : AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	player.bus = bus
	player.max_distance = 1000000.0
	player.attenuation = 0.0
	player.panning_strength = PANNING
	add_child(player)
	return player

func start(stream : AudioStream, pitch : float, level_db : float, voice_event : StringName, voice_kind : Kind, listener : Vector2, at : Vector2, target : Node2D = null, initial_gain : float = 1.0) -> void:
	serial += 1
	busy = true
	kind = voice_kind
	event = voice_event
	priority = SfxCatalog.priority_of(voice_event)
	_range = SfxCatalog.range_of(voice_event)
	_looping = SfxCatalog.is_loop(voice_event)
	level = db_to_linear(level_db)
	gain = initial_gain
	follow = target
	global_position = at
	_fade_left = -1.0
	for player : AudioStreamPlayer2D in [_dry, _wet]:
		player.stop()
		player.stream = stream
		player.pitch_scale = pitch
	update_mix(listener, 0.0, true)
	if (_looping):
		var offset : float = randf() * stream.get_length()
		if (_dry_gain > SILENT):
			_dry.play(offset)
		if (_wet_gain > SILENT):
			_wet.play(offset)
		if (!_dry.playing and !_wet.playing):
			_dry.play(offset)
	else:
		if (_dry_gain > SILENT or _wet_gain <= SILENT):
			_dry.play(0.0)
		if (_wet_gain > SILENT):
			_wet.play(0.0)

func fade_out(time : float) -> void:
	if (!busy):
		return
	if (_fade_left >= 0.0 and _fade_left <= time):
		return
	_fade_time = maxf(time, 0.001)
	_fade_left = _fade_time

func is_fading() -> bool:
	return _fade_left >= 0.0

func release() -> void:
	busy = false
	follow = null
	audible = 0.0
	_fade_left = -1.0
	_dry.stop()
	_wet.stop()
	_dry.stream = null
	_wet.stream = null

func distance_gain(distance : float) -> float:
	var near : float = _range.x * 0.5
	if (distance <= near):
		return 1.0
	return pow(clampf(1.0 - (distance - near) / (_range.z - near), 0.0, 1.0), DISTANCE_EXPONENT)

func update_mix(listener : Vector2, delta : float, instant : bool = false) -> void:
	if (!busy):
		return
	if (follow):
		if (is_instance_valid(follow) and follow.is_inside_tree()):
			global_position = follow.global_position
		else:
			follow = null
	var fade : float = 1.0
	if (_fade_left >= 0.0):
		_fade_left -= delta
		if (_fade_left <= 0.0):
			release()
			return
		fade = _fade_left / _fade_time
	var distance : float = global_position.distance_to(listener)
	var zoom : float = clampf(view_zoom, 1.0, MAX_ZOOM)
	var muffle : float = clampf(smoothstep(_range.x, _range.y, distance / zoom) + FAR_MUFFLE * (MAX_ZOOM - zoom) / (MAX_ZOOM - 1.0), 0.0, 1.0)
	var total : float = level * gain * distance_gain(distance)
	var dry_target : float = total * cos(muffle * PI * 0.5)
	var wet_target : float = total * sin(muffle * PI * 0.5)
	if (instant):
		_dry_gain = dry_target
		_wet_gain = wet_target
	else:
		var blend : float = 1.0 - exp(-SMOOTH_RATE * delta)
		_dry_gain = lerpf(_dry_gain, dry_target, blend)
		_wet_gain = lerpf(_wet_gain, wet_target, blend)
	audible = (_dry_gain + _wet_gain) * fade
	if (instant):
		_dry.volume_db = linear_to_db(maxf(_dry_gain, 0.00001))
		_wet.volume_db = linear_to_db(maxf(_wet_gain, 0.00001))
		return
	_apply_layer(_dry, _dry_gain * fade, _wet)
	_apply_layer(_wet, _wet_gain * fade, _dry)
	if (!_dry.playing and !_wet.playing):
		release()

func _apply_layer(player : AudioStreamPlayer2D, value : float, other : AudioStreamPlayer2D) -> void:
	player.volume_db = linear_to_db(maxf(value, 0.00001))
	if (value > SILENT * 2.0):
		if (!player.playing and other.playing):
			player.play(other.get_playback_position())
	elif (player.playing and other.playing):
		player.stop()
