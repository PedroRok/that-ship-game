class_name AirPuff
extends Node2D

const SMOKE : Color = Color(0.86, 0.9, 0.93)
const SHADE : Color = Color(0.5, 0.57, 0.65)
const SPARK : Color = Color(1.0, 0.97, 0.75)
const GLOW : Color = Color(1.0, 0.55, 0.1)
const SMOKE_SECONDS : float = 0.9
const FLARE_SECONDS : float = 1.5
const FLARE_COUNT : int = 9
const FLARE_FALL : float = 20.0

var life : float = SMOKE_SECONDS
var age : float = 0.0
var sparks : Array[Vector2] = []

static func smoke(source : Node2D, where : Vector2) -> void:
	_place(source, where, AirPuff.new())

static func flares(source : Node2D, where : Vector2, forward : Vector2) -> void:
	var puff : AirPuff = AirPuff.new()
	puff.life = FLARE_SECONDS
	for index : int in FLARE_COUNT:
		var spread : float = lerpf(-1.3, 1.3, float(index) / float(FLARE_COUNT - 1))
		puff.sparks.append((-forward).rotated(spread) * randf_range(50.0, 90.0))
	_place(source, where, puff)

static func _place(source : Node2D, where : Vector2, puff : AirPuff) -> void:
	puff.z_index = 1800
	source.get_parent().add_child(puff)
	puff.global_position = where

func _process(delta : float) -> void:
	age += delta
	if (age >= life):
		queue_free()
	queue_redraw()

func _draw() -> void:
	var fade : float = clampf(1.0 - age / life, 0.0, 1.0)
	if (sparks.is_empty()):
		_puff(Vector2.ZERO, 5.0 + roundf(age / life * 6.0), fade)
		return
	for velocity : Vector2 in sparks:
		for step : int in range(5, -1, -1):
			var past : float = maxf(age - float(step) * 0.08, 0.0)
			var point : Vector2 = (velocity * past + Vector2(0.0, FLARE_FALL * past * past)).round()
			if (step == 0):
				var glow : float = 4.0 if int(age * 20.0) % 2 == 0 else 3.0
				_square(point, glow, Color(GLOW, minf(fade * 1.8, 1.0)))
				_square(point, 2.0, Color(SPARK, minf(fade * 2.0, 1.0)))
			else:
				_puff(point, maxf(5.0 - float(step), 1.0), fade * (1.0 - float(step) * 0.12))

func _puff(point : Vector2, size : float, fade : float) -> void:
	var alpha : float = minf(fade * 1.5, 1.0)
	_square(point + Vector2(1, 1), size, Color(SHADE, alpha * 0.8))
	_square(point, size, Color(SMOKE, alpha))

func _square(point : Vector2, size : float, color : Color) -> void:
	draw_rect(Rect2(point - Vector2.ONE * floorf(size * 0.5), Vector2.ONE * size), color)
