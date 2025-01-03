class_name BaseHitbox
extends Area2D

@export
var base : Base

func handle_hit(damage : Damage, direction : float):
	print(damage.damage)
	pass
	
