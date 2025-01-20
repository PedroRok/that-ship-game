class_name HealthComponent
extends RichTextLabel

@export
var default_health : float = 10

@export
var entity : Entity

var actual_health : float

signal death_event

func _ready() -> void:
	if entity:
		default_health = entity.entity_stats.health
		actual_health = entity.entity_stats.health
	else:
		actual_health = default_health
	
func handle_hit(damage: Damage) -> bool:
	actual_health -= damage.damage
	if actual_health <= 0:
		death_event.emit()
		clear() # Removes the health text
		return false
	else:
		text = str(actual_health)
		return true

func get_health() -> float:
	return actual_health
