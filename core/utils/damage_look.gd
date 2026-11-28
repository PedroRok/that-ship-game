class_name DamageLook
extends RefCounted

const FIRST_HIT : float = 0.3

static func amount(health_ratio : float) -> float:
	var ratio : float = clampf(health_ratio, 0.0, 1.0)
	return lerpf(FIRST_HIT, 1.0, 1.0 - ratio) if ratio < 1.0 else 0.0
