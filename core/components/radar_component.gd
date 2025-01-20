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

func check_radar(team_id: int, direction: int) -> Node2D:
	var nearest_enemy_area : Area2D = _get_nearest_enemy()
	if (nearest_enemy_area):
		return nearest_enemy_area.get_hitbox_parent()
	return null

func _get_nearest_enemy() -> Node:
	var distance : float = 99999
	var selected_enemy : Node2D = null
	for enemy : SimpleHitboxComponent in enemy_hitbox:
		if (enemy.enabled):
			var enemy_distance : float = enemy.global_position.distance_to(global_position)
			if (enemy_distance < distance):
				distance = enemy_distance
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
		enemy_hitbox.erase(area) # TODO: Change this in future, this is very consuming
	pass
