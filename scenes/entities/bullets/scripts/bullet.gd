class_name Bullet
extends Area2D

@export
var bullet_stats : BulletStats

@export
var damage : Damage

var direction : Vector2 = Vector2.ZERO

var team : int = -1

var already_hit : Array[Area2D]

var target : Node2D

func _physics_process(_delta: float) -> void:
	if direction != Vector2.ZERO:
		var velocity : Vector2 = direction * bullet_stats.speed
		global_position += velocity
		
	if (bullet_stats.killTime <= 0):
		queue_free()
	bullet_stats.killTime -= 1
	pass
	
func set_direction(new_direction: Vector2) -> void:
	self.direction = new_direction
	new_direction = self.direction.rotated(rotation)

func _on_area_shape_entered(_area_rid: RID, area: Area2D, _area_shape_index: int, _local_shape_index: int) -> void:
	if (already_hit.has(area) || bullet_stats.piercing <= already_hit.size()):
		return 
	if (area is HitboxComponent):
		var ship : Entity = area.entity
		if (ship.team_stats.team_id != team):
			if (area.enabled):
				already_hit.append(area)
				area.handle_hit(damage, direction.x)
				if (bullet_stats.piercing <= already_hit.size()):
					remove_bullet()
	if (area is BaseHitboxComponent):
		var base : Base = area.base
		if (base.team_stats.team_id != team):
			already_hit.append(area)
			area.handle_hit(damage, direction.x)
			if (bullet_stats.piercing <= already_hit.size()):
				remove_bullet()
	pass # Replace with function body.

func remove_bullet() -> void:
	queue_free()
