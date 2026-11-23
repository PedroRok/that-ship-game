@tool
class_name RadarComponent
extends Area2D

@export
var entity : Entity

var enemy_hitbox : Array

var target_enemy : Node2D

func _ready() -> void:
	if (!entity.entity_stats):
		return
	var collision_shape : CollisionShape2D = get_child(0)
	collision_shape.shape.radius = entity.entity_stats.radar_distance
	pass

const RECHECK_FRAMES : int = 6
var _cached_target : Node2D
var _next_check_frame : int = 0

func check_radar(_team_id: int, _direction: int) -> Node2D:
	var frame : int = Engine.get_physics_frames()
	if (frame < _next_check_frame and (_cached_target == null or (is_instance_valid(_cached_target) and !_cached_target.is_queued_for_deletion()))):
		return _cached_target
	_next_check_frame = frame + RECHECK_FRAMES + int(get_instance_id() % 3) - 1
	var nearest_enemy_area : Area2D = _get_nearest_enemy()
	_cached_target = nearest_enemy_area.get_hitbox_parent() if nearest_enemy_area else null
	return _cached_target

func _get_nearest_enemy() -> Node:
	var distance : float = 99999
	var highest_priority : int = -99999
	var selected_enemy : Node2D = null
	for enemy : SimpleHitboxComponent in enemy_hitbox:
		var target : Node2D = enemy.get_hitbox_parent()
		if (entity and !entity.can_target(target)):
			continue
		var boat : BoatStats = entity.entity_stats as BoatStats if entity else null
		if (boat and boat.can_submerge and (enemy.global_position.x - global_position.x) * entity.team_stats.direction < -8.0):
			continue
		if (entity is ShipEntity and !(entity as ShipEntity).in_range(target)):
			continue
		if (enemy.enabled):
			var enemy_distance : float = enemy.global_position.distance_to(global_position)
			if ((enemy_distance < distance && enemy.attack_priority == highest_priority) || enemy.attack_priority > highest_priority):
				distance = enemy_distance
				highest_priority = enemy.attack_priority
				selected_enemy = enemy
	return selected_enemy


func _on_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	if (enemy_hitbox.has(area)): return
	if (area is SimpleHitboxComponent):
		if (area.get_hitbox_parent().team_stats.team_id != entity.team_stats.team_id and area.enabled):
			enemy_hitbox.append(area)
	pass


func _on_area_shape_exited(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	if (enemy_hitbox.has(area)):
		enemy_hitbox.erase(area)
	pass
