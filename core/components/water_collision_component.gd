@tool
class_name WaterCollisionComponent
extends CollisionShape2D

@export
var ship : ShipEntity

func _ready() -> void:
	if (!ship):
		return
	if (!ship.entity_stats):
		return
	shape = ship.entity_stats.water_colision_shape
	position = ship.entity_stats.water_colision_pos
	pass
