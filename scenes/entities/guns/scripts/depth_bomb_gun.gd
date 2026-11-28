class_name DepthBombGun
extends BombGun

func _init() -> void:
	sfx_event = &"bomb_release"
	hits_submerged = true

func can_target(target : Node2D) -> bool:
	var entity : Entity = target as Entity
	if (!entity):
		return true
	return !(entity.entity_stats is AirPlaneState)
