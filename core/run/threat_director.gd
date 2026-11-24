class_name ThreatDirector
extends RefCounted

var threat : float = 50.0
var interval_mult : float = 1.0
var skip_chance : float = 0.0
var _score : float = 0.0

func update(delta : float, ally_units : int, enemy_units : int, ally_base_fraction : float, enemy_base_fraction : float) -> void:
	var raw : float = raw_score(ally_units, enemy_units, ally_base_fraction, enemy_base_fraction)
	var blend : float = 1.0 - exp(-delta / maxf(RunData.DIRECTOR_SMOOTH_SECONDS, 0.01))
	_score = lerpf(_score, raw, blend)
	threat = 50.0 + 50.0 * _score
	interval_mult = interval_for(_score)
	skip_chance = skip_for(_score)

static func raw_score(ally_units : int, enemy_units : int, ally_base_fraction : float, enemy_base_fraction : float) -> float:
	var total : float = float(maxi(ally_units + enemy_units, RunData.DIRECTOR_MIN_UNITS))
	var units : float = clampf(float(ally_units - enemy_units) / total, -1.0, 1.0)
	var progress : float = clampf(1.0 - enemy_base_fraction, 0.0, 1.0)
	var base_hp : float = -(1.0 - clampf(ally_base_fraction, 0.0, 1.0))
	var weights : float = RunData.DIRECTOR_W_UNITS + RunData.DIRECTOR_W_PROGRESS + RunData.DIRECTOR_W_BASE_HP
	var blended : float = units * RunData.DIRECTOR_W_UNITS + progress * RunData.DIRECTOR_W_PROGRESS \
			+ base_hp * RunData.DIRECTOR_W_BASE_HP
	return clampf(blended / weights, -1.0, 1.0)

static func interval_for(score : float) -> float:
	return clampf(1.0 - score * RunData.DIRECTOR_RANGE, 1.0 - RunData.DIRECTOR_RANGE, 1.0 + RunData.DIRECTOR_RANGE)

static func skip_for(score : float) -> float:
	if (score >= 0.0):
		return 0.0
	return clampf(-score * RunData.DIRECTOR_MAX_SKIP, 0.0, RunData.DIRECTOR_MAX_SKIP)
