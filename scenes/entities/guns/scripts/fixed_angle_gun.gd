class_name FixedAngleGun
extends Gun

@export
var direction : Vector2

func shoot_gun(direction: Vector2) -> void:
	super.shoot_gun(direction)
