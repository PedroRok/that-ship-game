class_name AirPuff
extends Node2D

const CLOUD_TONES : Array[Color] = [Color(1.0, 1.0, 1.0), Color(0.9, 0.95, 1.0), Color(0.74, 0.85, 0.96)]
const WIND : Vector2 = Vector2(-8.0, 0.0)
const WATER_MARGIN : float = 4.0
const SPARK : Color = Color(1.0, 0.97, 0.75)
const GLOW : Color = Color(1.0, 0.55, 0.1)
const FLARE_SECONDS : float = 1.5
const FLARE_COUNT : int = 9
const FLARE_FALL : float = 20.0
const FLARE_ANGLE_JITTER : float = 0.3
const FLARE_DELAY_MAX : float = 0.15
const FLARE_EMIT_INTERVAL : float = 0.02
const FLARE_EMIT_JITTER : float = 1.5
const FLARE_CLOUD_SECONDS : float = 0.25
const FLARE_SMOKE_SECONDS : float = 6.0
const BOOST_SMOKE_SECONDS : float = 20.0
const BOOST_PARTICLES : int = 8
const BOOST_JITTER : float = 4.5
const CLOUD_HOLD : float = 0.4
const CLOUD_DRIFT : float = 0.15
const MOTE_ALPHA : float = 0.85
const MOTE_BIG_CHANCE : float = 0.35

static var tint : Color = Color.WHITE

var age : float = 0.0
var sparks : Array[Vector2] = []
var falls : Array[float] = []
var delays : Array[float] = []
var sways : Array[Vector3] = []
var life : float = 0.0

var _motes : PackedVector2Array = PackedVector2Array()
var _sizes : PackedFloat32Array = PackedFloat32Array()
var _shades : PackedByteArray = PackedByteArray()
var _emitted : float = 0.0
var _chunk_end : float = FLARE_CLOUD_SECONDS
var _chunk : AirPuff

static func smoke(source : Node2D, where : Vector2) -> void:
	var cloud : AirPuff = AirPuff.new()
	cloud.life = BOOST_SMOKE_SECONDS
	for _index : int in BOOST_PARTICLES:
		var at : Vector2 = _scatter(BOOST_JITTER)
		if (_over_water(where.y + at.y)):
			continue
		cloud._add_mote(at)
	_place(source.get_parent(), where, cloud)

static func flares(source : Node2D, where : Vector2, forward : Vector2) -> void:
	var puff : AirPuff = AirPuff.new()
	for index : int in FLARE_COUNT:
		var spread : float = lerpf(-1.3, 1.3, float(index) / float(FLARE_COUNT - 1))
		spread += randf_range(-FLARE_ANGLE_JITTER, FLARE_ANGLE_JITTER)
		puff.sparks.append((-forward).rotated(spread) * randf_range(35.0, 100.0))
		puff.falls.append(FLARE_FALL * randf_range(0.4, 1.8))
		puff.delays.append(randf_range(0.0, FLARE_DELAY_MAX))
		puff.sways.append(Vector3(randf_range(1.0, 6.0), randf_range(4.0, 11.0), randf_range(0.0, TAU)))
	_place(source.get_parent(), where, puff)

static func _place(parent : Node, where : Vector2, puff : AirPuff) -> void:
	puff.z_index = 1800
	parent.add_child(puff)
	puff.global_position = where

static func _scatter(radius : float) -> Vector2:
	return Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius

static func _over_water(world_y : float) -> bool:
	return world_y >= ShipEntity.WATER_LEVEL - WATER_MARGIN

func _ready() -> void:
	if (!sparks.is_empty()):
		return
	set_process(false)
	var lasting : float = life * randf_range(0.85, 1.0)
	var fade : Tween = create_tween()
	fade.tween_interval(lasting * CLOUD_HOLD)
	fade.tween_property(self, "modulate:a", 0.0, lasting * (1.0 - CLOUD_HOLD))
	fade.tween_callback(queue_free)
	var drift : Vector2 = WIND * lasting + Vector2(randf_range(-1.0, 1.0), 0.0) * CLOUD_DRIFT * lasting
	create_tween().tween_property(self, "position", drift, lasting).as_relative()

func _add_mote(at : Vector2) -> void:
	_motes.append(at.round())
	_sizes.append(2.0 if randf() < MOTE_BIG_CHANCE else 1.0)
	_shades.append(randi() % CLOUD_TONES.size())

func _process(delta : float) -> void:
	age += delta
	_emit_trails()
	if (age >= FLARE_SECONDS):
		_release_chunk()
		queue_free()
	queue_redraw()

func _emit_trails() -> void:
	while (_emitted <= minf(age, FLARE_SECONDS)):
		if (_emitted >= _chunk_end):
			_release_chunk()
			_chunk_end += FLARE_CLOUD_SECONDS
		if (_chunk == null):
			_chunk = AirPuff.new()
			_chunk.life = FLARE_SMOKE_SECONDS
		for index : int in sparks.size():
			if (_emitted >= delays[index]):
				var at : Vector2 = _spark_point(index, _emitted - delays[index]) + _scatter(FLARE_EMIT_JITTER)
				if (!_over_water(global_position.y + at.y)):
					_chunk._add_mote(at)
		_emitted += FLARE_EMIT_INTERVAL

func _release_chunk() -> void:
	if (_chunk):
		_place(get_parent(), global_position, _chunk)
		_chunk = null

func _notification(what : int) -> void:
	if (what == NOTIFICATION_PREDELETE and is_instance_valid(_chunk)):
		_chunk.free()

func _draw() -> void:
	for index : int in _motes.size():
		var color : Color = CLOUD_TONES[_shades[index]] * tint
		color.a = MOTE_ALPHA
		_square(_motes[index], _sizes[index], color)
	if (sparks.is_empty()):
		return
	var fade : float = clampf(1.0 - age / FLARE_SECONDS, 0.0, 1.0)
	var glow : float = 4.0 if int(age * 20.0) % 2 == 0 else 3.0
	for index : int in sparks.size():
		if (age < delays[index]):
			continue
		var point : Vector2 = _spark_point(index, age - delays[index]).round()
		if (_over_water(global_position.y + point.y)):
			continue
		_square(point, glow, Color(GLOW, minf(fade * 1.8, 1.0)))
		_square(point, 2.0, Color(SPARK, minf(fade * 2.0, 1.0)))

func _spark_point(index : int, time : float) -> Vector2:
	var velocity : Vector2 = sparks[index]
	var sway : Vector3 = sways[index]
	var side : Vector2 = velocity.orthogonal().normalized() * sway.x * (sin(time * sway.y + sway.z) - sin(sway.z))
	return velocity * time + side + Vector2(0.0, falls[index] * time * time)

func _square(point : Vector2, size : float, color : Color) -> void:
	draw_rect(Rect2(point - Vector2.ONE * floorf(size * 0.5), Vector2.ONE * size), color)
