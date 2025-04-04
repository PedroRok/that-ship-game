class_name BaseHealthComponent 
extends Node

@export
var health : float = 100

@export
var label : Label

signal death_event

var is_dead : bool = false

func handle_hit(damage : Damage) -> void:
	if health <= 0:
		if (!is_dead):
			emit_signal("death_event")
			is_dead = true
		return
	health -= damage.damage
	if health < 0:
		health = 0
	label.text = str(health)
	
