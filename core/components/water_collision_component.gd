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
	shape = _wide_enough(ship.entity_stats.water_colision_shape)
	position = ship.entity_stats.water_colision_pos
	pass

const MIN_WATER_WIDTH : float = 34.0

func _wide_enough(source : Shape2D) -> Shape2D:
	var rect : RectangleShape2D = source as RectangleShape2D
	if (!rect or rect.size.x >= MIN_WATER_WIDTH):
		return source
	var copy : RectangleShape2D = rect.duplicate() as RectangleShape2D
	copy.size.x = MIN_WATER_WIDTH
	return copy
