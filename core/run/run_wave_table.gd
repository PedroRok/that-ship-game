class_name RunWaveTable
extends WaveTable

var pool : Array[BoatStats] = []
var tier : BaseTier
var boss : BoatStats
var extra_boss : BoatStats
var base_health_mult : float = 1.0
var boss_risk_mult : float = 1.0
var wave_duration : float = 40.0

func _boss_health(stats : BoatStats) -> float:
	return (RunData.BOMBER_HEALTH_MULT if stats.name == RunData.BOMBER_BOSS_NAME else 3.0) * boss_risk_mult

func get_wave(index : int) -> WaveData:
	var wave : WaveData = WaveData.new()
	wave.ships = pool
	wave.duration = wave_duration
	wave.stat_mult = base_health_mult * pow(RunData.WAVE_RAMP_HEALTH, index)
	if (index == 0):
		wave.base_tier = tier
		if (boss):
			wave.boss = boss
			wave.boss_health_mult = _boss_health(boss)
	elif (index == 2 and extra_boss):
		wave.boss = extra_boss
		wave.boss_health_mult = _boss_health(extra_boss)
	return wave
