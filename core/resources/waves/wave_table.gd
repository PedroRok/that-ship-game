class_name WaveTable
extends Resource

@export
var waves : Array[WaveData]
@export
var endless_boss_every : int = 5

func get_wave(index : int) -> WaveData:
	if (index < waves.size()):
		return waves[index]
	var extra : int = index - waves.size() + 1
	var wave : WaveData = _last_regular_wave().duplicate()
	wave.stat_mult *= pow(1.1, extra)
	wave.base_tier = null
	if (endless_boss_every > 0 and extra % endless_boss_every == 0):
		var boss_wave : WaveData = _last_boss_wave()
		if (boss_wave):
			wave.boss = boss_wave.boss
			wave.boss_health_mult = boss_wave.boss_health_mult * pow(1.1, extra)
			wave.boss_coin_reward = boss_wave.boss_coin_reward
	return wave

func _last_regular_wave() -> WaveData:
	for i : int in range(waves.size() - 1, -1, -1):
		if (waves[i].boss == null):
			return waves[i]
	return waves.back()

func _last_boss_wave() -> WaveData:
	for i : int in range(waves.size() - 1, -1, -1):
		if (waves[i].boss != null):
			return waves[i]
	return null
