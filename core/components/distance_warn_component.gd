class_name DistanceWarnComponent
extends RadarComponent


func _ready() -> void:
	if (!entity.entity_stats):
		return
	var collision_shape : CollisionShape2D = get_child(0)
	#collision_shape.shape.radius = entity.entity_stats.
	pass

var is_too_low : bool = false

func _on_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	super._on_area_shape_entered(area_rid, area, area_shape_index, local_shape_index)
	if (area is WaterHitbox):
		is_too_low = true


func _on_area_shape_exited(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	super._on_area_shape_exited(area_rid, area, area_shape_index, local_shape_index)
	if (area is WaterHitbox):
		is_too_low = false
	pass
