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
	collision_shape.shape.radius = entity.entity_stats.radar_distance * (SHIP_AIR_RADAR_MULT if entity is ShipEntity else 1.0)
	pass

const SHIP_AIR_RADAR_MULT : float = 1.25
const BOMB_RADAR_SIZE : Vector2 = Vector2(720.0, 900.0)
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
		if (entity is AirEntity and !(entity as AirEntity).may_attack(target)):
			continue
		if (!reaches(enemy)):
			continue
		if (target is Base and entity is AirEntity and BattleContext.of(self).has_patrol()):
			continue
		var boat : BoatStats = entity.entity_stats as BoatStats if entity else null
		if (boat and boat.can_submerge and !box_shaped and (enemy.global_position.x - global_position.x) * entity.team_stats.direction < -8.0):
			continue
		if (entity is ShipEntity and !(entity as ShipEntity).in_range(target)):
			continue
		if (enemy.enabled):
			var priority : int = enemy.attack_priority + _preference(target)
			var enemy_distance : float = enemy.global_position.distance_to(global_position)
			if ((enemy_distance < distance && priority == highest_priority) || priority > highest_priority):
				distance = enemy_distance
				highest_priority = priority
				selected_enemy = enemy
	return selected_enemy


func _preference(target : Node2D) -> int:
	var role : BoatStats = entity.entity_stats as BoatStats if entity else null
	var unit : Entity = target as Entity
	if (!role or !unit):
		return 0
	if (role.prefers_air and unit.entity_stats is AirPlaneState):
		return RunData.TARGET_PREFERENCE
	if (role.prefers_submerged and unit.is_submerged()):
		return RunData.TARGET_PREFERENCE
	return 0

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

func reaches(hitbox : SimpleHitboxComponent) -> bool:
	if (box_shaped or !(entity is ShipEntity)):
		return true
	var target : Entity = hitbox.get_hitbox_parent() as Entity
	if (target and target.entity_stats is AirPlaneState):
		return true
	var shape_node : CollisionShape2D = hitbox.get_child(0) as CollisionShape2D
	var rect : RectangleShape2D = shape_node.shape as RectangleShape2D if shape_node else null
	if (!rect):
		return hitbox.global_position.distance_to(global_position) <= entity.entity_stats.radar_distance
	var xf : Transform2D = shape_node.global_transform
	var local : Vector2 = xf.affine_inverse() * global_position
	var outside : Vector2 = (local.abs() - rect.size * 0.5).max(Vector2.ZERO)
	return (outside * xf.get_scale()).length() <= entity.entity_stats.radar_distance

var box_shaped : bool = false

func use_bomb_box() -> void:
	var box : RectangleShape2D = RectangleShape2D.new()
	box.size = BOMB_RADAR_SIZE
	var shape_node : CollisionShape2D = get_child(0) as CollisionShape2D
	shape_node.shape = box
	shape_node.position = Vector2.ZERO
	box_shaped = true

func _physics_process(_delta : float) -> void:
	if (box_shaped and !Engine.is_editor_hint()):
		global_rotation = 0.0

func target_for(gun : Gun) -> Node2D:
	var best : Node2D = null
	var best_priority : int = -99999
	var best_distance : float = INF
	for item : Variant in enemy_hitbox:
		var hitbox : SimpleHitboxComponent = item as SimpleHitboxComponent
		if (!is_instance_valid(hitbox) or !hitbox.enabled or !reaches(hitbox)):
			continue
		var target : Node2D = hitbox.get_hitbox_parent()
		if (!target or !gun.can_target(target) or gun.target_distance(target) > gun.effective_range()):
			continue
		var distance : float = hitbox.global_position.distance_to(global_position)
		if (hitbox.attack_priority > best_priority or (hitbox.attack_priority == best_priority and distance < best_distance)):
			best = target
			best_priority = hitbox.attack_priority
			best_distance = distance
	return best
