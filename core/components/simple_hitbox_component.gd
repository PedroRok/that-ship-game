class_name SimpleHitboxComponent
extends Area2D

var enabled : bool = true

@export
var name_entity : String

@export
var attack_priority : int = 0

func get_hitbox_parent() -> Node2D:
	return null

func is_hitbox_enabled() -> bool:
	return enabled
