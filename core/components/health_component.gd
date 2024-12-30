class_name HealthComponent
extends RichTextLabel

@export
var default_health : float = 10

@export
var ship : Ship

var actual_health : float

signal death_event

func _ready() -> void:
	if ship:
		default_health = ship.boat_stats.health
		actual_health = ship.boat_stats.health
	else:
		actual_health = default_health
	
func handle_hit(damage: float = 1):
	actual_health -= damage
	if actual_health <= 0:
		death_event.emit()
		clear() # Removes the health text
	else:
		text = str(actual_health)

func get_health() -> float:
	return actual_health
