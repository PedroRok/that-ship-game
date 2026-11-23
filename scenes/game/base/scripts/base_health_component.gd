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
	health -= damage.damage * _damage_taken_mult()
	if health < 0:
		health = 0
	label.text = str(snappedf(health, 0.1))
	

func _damage_taken_mult() -> float:
	var base : Base = get_parent() as Base
	if (base == null or base.team_stats == null or base.team_stats.team_id != 1):
		return 1.0
	return Global.modify(Enums.UpgradeTarget.BASE, &"damage_taken", 1.0)
