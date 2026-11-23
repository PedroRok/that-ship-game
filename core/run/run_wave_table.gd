class_name RunWaveTable
extends WaveTable

var pool : Array[BoatStats] = []
var tier : BaseTier
var boss : BoatStats
var extra_boss : BoatStats
var base_health_mult : float = 1.0
var base_interval : float = 6.0
var wave_duration : float = 40.0

func get_wave(index : int) -> WaveData:
	var wave : WaveData = WaveData.new()
	wave.ships = pool
	wave.duration = wave_duration
	wave.stat_mult = base_health_mult * pow(RunData.WAVE_RAMP_HEALTH, index)
	wave.spawn_interval = maxf(2.5, base_interval * pow(RunData.WAVE_RAMP_INTERVAL, index))
	if (index == 0):
		wave.base_tier = tier
		if (boss):
			wave.boss = boss
			wave.boss_health_mult = 3.0
	elif (index == 2 and extra_boss):
		wave.boss = extra_boss
		wave.boss_health_mult = 3.0
	return wave
