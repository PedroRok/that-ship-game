class_name HealthComponent
extends RichTextLabel

@export
var default_health : float = 10

@export
var entity : Entity

var actual_health : float
var fatal_damage : float = 0.0

signal death_event

func _ready() -> void:
	if entity:
		default_health = entity.entity_stats.health
		actual_health = entity.entity_stats.health
		if (!Engine.is_editor_hint()):
			var bar : HealthBar = HealthBar.new()
			entity.add_child.call_deferred(bar)
			bar.setup.call_deferred(entity, self)
	else:
		actual_health = default_health
	
func handle_hit(damage: Damage) -> bool:
	actual_health -= damage.damage
	if actual_health <= 0:
		if (fatal_damage <= 0.0):
			fatal_damage = damage.damage
		death_event.emit()
		clear()
		return false
	else:
		text = ""
		return true

func get_health() -> float:
	return actual_health
