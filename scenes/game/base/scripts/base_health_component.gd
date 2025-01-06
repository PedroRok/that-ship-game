class_name BaseHealthComponent 
extends Node

@export
var health : float = 100

@export
var label : Label

signal death_event

func handle_hit(damage : Damage) -> void:
	if health - damage.damage <= 0:
		emit_signal("death_event")
	health -= damage.damage
	label.text = str(health)
