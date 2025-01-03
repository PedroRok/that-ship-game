class_name WaterCollisionComponent
extends CollisionShape2D

@export
var ship : Ship

func _ready() -> void:
	shape = ship.boat_stats.water_colision_shape
	position = ship.boat_stats.water_colision_pos
	pass
