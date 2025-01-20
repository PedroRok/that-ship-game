class_name BaseHitboxComponent
extends SimpleHitboxComponent

@export
var base : Base
@export
var health_component : BaseHealthComponent

func handle_hit(damage : Damage, _direction : float) -> void:
	health_component.handle_hit(damage)
	pass
	
func get_hitbox_parent() -> Node2D:
	return base
