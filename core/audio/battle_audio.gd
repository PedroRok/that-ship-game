class_name BattleAudio
extends Node

const BUS_NEAR : StringName = &"WorldSFX"
const BUS_FAR : StringName = &"WorldSFX_Distant"

const ONE_SHOT_CAP : int = 24
const LOOP_CAP : int = 8
const BUILD_CAP : int = 6
const SPARE_VOICES : int = 8
const STEAL_FADE : float = 0.05
const ENGINE_RELEASE : float = 0.22
const ENGINE_DELAY : float = 0.7
const ENGINE_RAMP : float = 1.4
const ENGINE_IDLE : float = 0.35
const ENGINE_RUNWAY : float = 0.25
const SURFACED_SUB_GAIN : float = 0.6
const ENGINE_HYSTERESIS : float = 0.85
const PITCH_SEMITONES : float = 0.35
const LEVEL_JITTER_DB : float = 1.0
const ENGINE_PITCH_SEMITONES : float = 0.5
const BUILD_GAP_MIN : float = 0.15
const BUILD_GAP_MAX : float = 0.8
const BUILD_RELEASE : float = 0.3
const RECENT_WINDOW : float = 0.25
const MEMORY_LIMIT : int = 512

class EngineState extends RefCounted:
	var entity : Entity
	var event : StringName = &""
	var handle : SfxHandle
	var pitch : float = 1.0
	var take : int = 0
	var born : float = 0.0
	var dead : bool = false

class BuildState extends RefCounted:
	var node : Node2D
	var handle : SfxHandle
	var next_at : float = 0.0

signal sound_started(event : StringName, at : Vector2)

var camera : Camera2D
var context : BattleContext
var listener : AudioListener2D

var _voices : Array[SfxVoice] = []
var _engines : Dictionary = {}
var _builds : Dictionary = {}
var _recent : Array[Dictionary] = []
var _last_take : Dictionary = {}
var _clock : float = 0.0
var _base_damage : Dictionary = {}

const BASE_DAMAGE_HOLD : float = 0.35
const BASE_DAMAGE_RELEASE : float = 0.2

static func of(node : Node) -> BattleAudio:
	if (!node or !node.is_inside_tree()):
		return null
	var battle : BattleContext = BattleContext.of(node)
	if (!battle or !battle.audio_enabled or !is_instance_valid(battle.audio)):
		return null
	return battle.audio

static func play_at(node : Node, event : StringName, at : Vector2, emitter : Object = null, underwater : bool = false) -> SfxHandle:
	var audio : BattleAudio = of(node)
	if (!audio):
		return null
	return audio.play(event, at, emitter, underwater)

static func start_build(constructor : Node2D) -> void:
	var audio : BattleAudio = of(constructor)
	if (audio):
		audio.begin_build_ambience(constructor)

static func stop_build(constructor : Node2D) -> void:
	var audio : BattleAudio = of(constructor)
	if (audio):
		audio.end_build_ambience(constructor)

func _ready() -> void:
	context = BattleContext.of(self)
	context.audio = self
	listener = AudioListener2D.new()
	add_child(listener)
	listener.make_current()
	listener.global_position = listener_position()

func _exit_tree() -> void:
	if (context and context.audio == self):
		context.audio = null
	for voice : SfxVoice in _voices:
		voice.release()
	_engines.clear()
	_builds.clear()

static func base_damaged(base : Node2D) -> void:
	var audio : BattleAudio = of(base)
	if (audio):
		audio.pulse_base_damage(base)

func pulse_base_damage(base : Node2D) -> void:
	var key : int = base.get_instance_id()
	var state : Dictionary = _base_damage.get(key, {"node": base, "handle": null})
	state["last"] = _clock
	_base_damage[key] = state

func _update_base_damage(here : Vector2) -> void:
	var event : StringName = &"base_damage"
	for key : int in _base_damage.keys():
		var state : Dictionary = _base_damage[key]
		var node : Node2D = state["node"] as Node2D
		var handle : SfxHandle = state["handle"] as SfxHandle
		var expired : bool = !is_instance_valid(node) or !node.is_inside_tree() or _clock - float(state["last"]) > BASE_DAMAGE_HOLD
		if (expired):
			if (handle):
				handle.fade(BASE_DAMAGE_RELEASE)
			_base_damage.erase(key)
			continue
		if (handle and handle.active()):
			continue
		var at : Vector2 = node.global_position
		if (at.distance_to(here) >= SfxCatalog.range_of(event).z):
			continue
		var voice : SfxVoice = _acquire(SfxVoice.Kind.LOOP, SfxCatalog.priority_of(event), LOOP_CAP)
		if (!voice):
			continue
		var streams : Array[AudioStream] = SfxCatalog.streams(event)
		voice.start(streams[key % streams.size()], 1.0, SfxCatalog.trim_of(event), event, SfxVoice.Kind.LOOP, here, at, node, 1.0)
		state["handle"] = SfxHandle.new(voice)
		sound_started.emit(event, at)

func _update_zoom() -> void:
	SfxVoice.view_zoom = camera.zoom.x if is_instance_valid(camera) else 1.0

func listener_position() -> Vector2:
	if (is_instance_valid(camera) and camera.is_inside_tree()):
		return camera.get_screen_center_position()
	var viewport : Viewport = get_viewport()
	return viewport.get_visible_rect().size * 0.5 if viewport else Vector2.ZERO

func play(event : StringName, at : Vector2, emitter : Object = null, underwater : bool = false) -> SfxHandle:
	if (!context or !context.audio_enabled or !SfxCatalog.has_event(event)):
		return null
	_update_zoom()
	var here : Vector2 = listener_position()
	var reach : Vector3 = SfxCatalog.range_of(event)
	if (at.distance_to(here) >= reach.z):
		return null
	if (_is_duplicate(event, at)):
		return null
	var streams : Array[AudioStream] = SfxCatalog.streams(event)
	if (streams.is_empty()):
		return null
	var voice : SfxVoice = _acquire(SfxVoice.Kind.ONE_SHOT, SfxCatalog.priority_of(event), ONE_SHOT_CAP)
	if (!voice):
		return null
	var take : int = _pick_take(event, emitter, streams.size())
	var pitch : float = pow(2.0, randf_range(-PITCH_SEMITONES, PITCH_SEMITONES) / 12.0)
	var level_db : float = SfxCatalog.trim_of(event) + randf_range(-LEVEL_JITTER_DB, LEVEL_JITTER_DB)
	voice.start(streams[take], pitch, level_db, event, SfxVoice.Kind.ONE_SHOT, here, at, null, 1.0, underwater)
	_remember(event, at)
	sound_started.emit(event, at)
	return SfxHandle.new(voice)

func begin_build_ambience(constructor : Node2D) -> void:
	var key : int = constructor.get_instance_id()
	if (_builds.has(key)):
		return
	var state : BuildState = BuildState.new()
	state.node = constructor
	state.next_at = _clock
	_builds[key] = state

func end_build_ambience(constructor : Node2D) -> void:
	var key : int = constructor.get_instance_id()
	var state : BuildState = _builds.get(key) as BuildState
	if (!state):
		return
	if (state.handle):
		state.handle.fade(BUILD_RELEASE)
	_builds.erase(key)

func stop_all_builds_for(base : Base) -> void:
	for constructor : ShipConstructor in base.constructors.values():
		if (is_instance_valid(constructor)):
			end_build_ambience(constructor)

func _process(delta : float) -> void:
	_clock += delta
	if (!context.audio_enabled):
		for voice : SfxVoice in _voices:
			if (voice.busy):
				voice.release()
		return
	_update_zoom()
	var here : Vector2 = listener_position()
	listener.global_position = here
	_update_builds(here)
	_update_base_damage(here)
	_update_engines(here)
	for voice : SfxVoice in _voices:
		if (voice.busy):
			voice.update_mix(here, delta)

func active_counts() -> Dictionary:
	var counts : Dictionary = {SfxVoice.Kind.ONE_SHOT: 0, SfxVoice.Kind.LOOP: 0, SfxVoice.Kind.BUILD: 0}
	for voice : SfxVoice in _voices:
		if (voice.busy and !voice.is_fading()):
			counts[voice.kind] = int(counts[voice.kind]) + 1
	return counts

func _acquire(kind : SfxVoice.Kind, priority : int, cap : int) -> SfxVoice:
	var count : int = 0
	var victim : SfxVoice = null
	var free_voice : SfxVoice = null
	for voice : SfxVoice in _voices:
		if (!voice.busy):
			if (!free_voice):
				free_voice = voice
			continue
		if (voice.kind != kind or voice.is_fading()):
			continue
		count += 1
		if (voice.priority > priority):
			continue
		if (!victim or voice.priority < victim.priority or (voice.priority == victim.priority and voice.audible < victim.audible)):
			victim = voice
	if (count >= cap):
		if (!victim or (victim.priority == priority and kind != SfxVoice.Kind.ONE_SHOT)):
			return null
		victim.fade_out(STEAL_FADE)
	if (free_voice):
		return free_voice
	if (_voices.size() >= ONE_SHOT_CAP + LOOP_CAP + BUILD_CAP + SPARE_VOICES):
		if (victim):
			victim.release()
			return victim
		return null
	var created : SfxVoice = SfxVoice.new()
	add_child(created)
	_voices.append(created)
	return created

func _pick_take(event : StringName, emitter : Object, count : int) -> int:
	if (count <= 1):
		return 0
	var key : String = "%s:%d" % [event, emitter.get_instance_id() if emitter else 0]
	var last : int = int(_last_take.get(key, -1))
	var take : int = randi() % count
	if (take == last):
		take = (take + 1 + randi() % (count - 1)) % count
	if (_last_take.size() > MEMORY_LIMIT):
		_last_take.clear()
	_last_take[key] = take
	return take

func _is_duplicate(event : StringName, at : Vector2) -> bool:
	var gap : float = SfxCatalog.gap_of(event)
	if (gap <= 0.0):
		return false
	for entry : Dictionary in _recent:
		if (entry["event"] == event and _clock - float(entry["time"]) < gap and (entry["pos"] as Vector2).distance_to(at) < SfxCatalog.DUPLICATE_RADIUS):
			return true
	return false

func _remember(event : StringName, at : Vector2) -> void:
	if (SfxCatalog.gap_of(event) <= 0.0):
		return
	while (!_recent.is_empty() and _clock - float(_recent[0]["time"]) > RECENT_WINDOW):
		_recent.pop_front()
	_recent.append({"event": event, "pos": at, "time": _clock})

func _update_builds(here : Vector2) -> void:
	var reach : Vector3 = SfxCatalog.range_of(&"dock_build")
	for key : int in _builds.keys():
		var state : BuildState = _builds[key]
		if (!is_instance_valid(state.node) or !state.node.is_inside_tree()):
			if (state.handle):
				state.handle.fade(BUILD_RELEASE)
			_builds.erase(key)
			continue
		if (state.handle and state.handle.active()):
			continue
		if (state.handle):
			state.handle = null
			state.next_at = _clock + randf_range(BUILD_GAP_MIN, BUILD_GAP_MAX)
			continue
		if (_clock < state.next_at):
			continue
		var at : Vector2 = state.node.global_position
		if (at.distance_to(here) >= reach.z):
			state.next_at = _clock + 0.5
			continue
		var voice : SfxVoice = _acquire(SfxVoice.Kind.BUILD, SfxCatalog.priority_of(&"dock_build"), BUILD_CAP)
		if (!voice):
			state.next_at = _clock + 0.5
			continue
		var streams : Array[AudioStream] = SfxCatalog.streams(&"dock_build")
		var take : int = _pick_take(&"dock_build", state.node, streams.size())
		voice.start(streams[take], 1.0, SfxCatalog.trim_of(&"dock_build"), &"dock_build", SfxVoice.Kind.BUILD, here, at, state.node)
		state.handle = SfxHandle.new(voice)
		sound_started.emit(&"dock_build", at)

func _track(entity : Entity) -> void:
	var state : EngineState = EngineState.new()
	state.entity = entity
	state.born = _clock
	var id : int = entity.get_instance_id()
	var hashed : int = absi(hash(id))
	state.take = hashed % 3
	state.pitch = pow(2.0, (float((hashed >> 4) % 101) / 50.0 - 1.0) * ENGINE_PITCH_SEMITONES / 12.0)
	entity.entity_destroy.connect(func(_pos : Vector2, _stats : EntityStats, _team : TeamStats) -> void: state.dead = true)
	_engines[id] = state

func _engine_gain(state : EngineState) -> float:
	var entity : Entity = state.entity
	var ramp : float = clampf((_clock - state.born - ENGINE_DELAY) / ENGINE_RAMP, 0.0, 1.0)
	if (ramp <= 0.0):
		return 0.0
	var gain : float = 1.0
	if (entity is AirEntity):
		gain = ENGINE_RUNWAY if (entity as AirEntity).is_on_runway() else 1.0
	else:
		var top : float = maxf(entity.entity_stats.speed, 1.0)
		gain = lerpf(ENGINE_IDLE, 1.0, clampf(entity.linear_velocity.length() / top, 0.0, 1.0))
		var boat : BoatStats = entity.entity_stats as BoatStats
		if (boat and boat.can_submerge and !entity.is_submerged()):
			gain *= SURFACED_SUB_GAIN
	return gain * ramp

func _update_engines(here : Vector2) -> void:
	for node : Entity in context.entities:
		if (is_instance_valid(node) and !node.is_queued_for_deletion() and node.entity_stats and !_engines.has(node.get_instance_id())):
			_track(node)
	var ranked : Array[Dictionary] = []
	for key : int in _engines.keys():
		var state : EngineState = _engines[key]
		if (!is_instance_valid(state.entity) or !state.entity.is_inside_tree() or state.dead):
			if (state.handle):
				state.handle.fade(ENGINE_RELEASE)
			if (!is_instance_valid(state.entity) or !state.entity.is_inside_tree()):
				_engines.erase(key)
			else:
				state.handle = null
			continue
		var event : StringName = SfxCatalog.engine_event(state.entity)
		if (state.handle and (!state.handle.active() or state.event != event)):
			state.handle.fade(ENGINE_RELEASE)
			state.handle = null
		state.event = event
		var distance : float = state.entity.global_position.distance_to(here)
		if (distance >= SfxCatalog.range_of(event).z):
			if (state.handle):
				state.handle.fade(ENGINE_RELEASE)
				state.handle = null
			continue
		ranked.append({"state": state, "score": distance * (ENGINE_HYSTERESIS if state.handle else 1.0)})
	ranked.sort_custom(func(a : Dictionary, b : Dictionary) -> bool: return float(a["score"]) < float(b["score"]))
	for index : int in ranked.size():
		var state : EngineState = ranked[index]["state"]
		if (index >= LOOP_CAP):
			if (state.handle):
				state.handle.fade(ENGINE_RELEASE)
				state.handle = null
			continue
		var gain : float = _engine_gain(state)
		if (!state.handle):
			if (gain <= 0.0):
				continue
			var voice : SfxVoice = _acquire(SfxVoice.Kind.LOOP, 1, LOOP_CAP)
			if (!voice):
				continue
			var streams : Array[AudioStream] = SfxCatalog.streams(state.event)
			voice.start(streams[state.take % streams.size()], state.pitch, SfxCatalog.trim_of(state.event), state.event, SfxVoice.Kind.LOOP, here, state.entity.global_position, state.entity, 0.0)
			state.handle = SfxHandle.new(voice)
			sound_started.emit(state.event, state.entity.global_position)
		state.handle.set_gain(gain)
