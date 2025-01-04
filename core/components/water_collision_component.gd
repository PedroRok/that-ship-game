@tool
class_name WaterCollisionComponent
extends CollisionShape2D

@export
var ship : Ship

func _ready() -> void:
	if (!ship.boat_stats):
		return
	shape = ship.boat_stats.water_colision_shape
	position = ship.boat_stats.water_colision_pos
	pass
