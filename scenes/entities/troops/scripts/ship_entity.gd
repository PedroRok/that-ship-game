@tool
class_name ShipEntity
extends Entity

@onready 
var sprite: Sprite2D = $BoatSprite

func _ready() -> void:
	super._ready()
	if (!entity_stats):
		return
	sprite.texture = entity_stats.sprite
	if (Engine.is_editor_hint()):
		return
	if (team_stats.direction > 0):
		sprite.flip_h = false
	else:
		sprite.flip_h = true
	
