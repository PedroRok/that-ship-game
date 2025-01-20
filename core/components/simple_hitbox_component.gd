class_name SimpleHitboxComponent
extends Area2D

var enabled : bool = true

func get_hitbox_parent() -> Node2D:
	return null

func is_hitbox_enabled() -> bool:
	return enabled
