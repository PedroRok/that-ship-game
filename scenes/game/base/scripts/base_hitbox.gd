class_name BaseHitboxComponent
extends Area2D

@export
var base : Base
@export
var health_component : BaseHealthComponent

func handle_hit(damage : Damage, _direction : float) -> void:
	health_component.handle_hit(damage)
	pass
	
