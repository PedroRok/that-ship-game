class_name WaveManager
extends Node

signal wave_started(wave_number : int, wave : WaveData)

@export
var table : WaveTable

@export
var enemy_base : AutoBase

@export
var waves_per_run : int = 15

var wave_index : int = -1
var running : bool = false

@onready
var wave_timer : Timer = Timer.new()

func _ready() -> void:
	wave_timer.one_shot = true
	wave_timer.timeout.connect(next_wave)
	add_child(wave_timer)

func start() -> void:
	running = true
	wave_index = -1
	next_wave()

func stop() -> void:
	running = false
	wave_timer.stop()
	enemy_base.stop()

func current_wave_number() -> int:
	return wave_index + 1

func next_wave() -> void:
	if (!running):
		return
	wave_index += 1
	var wave : WaveData = table.get_wave(wave_index)
	enemy_base.apply_wave(wave)
	wave_timer.start(wave.duration)
	wave_started.emit(current_wave_number(), wave)
