class_name Bullet
extends Area2D


@export
var speed : int = 3

@export
var damage : Damage

var direction : Vector2 = Vector2.ZERO

var killTime : int = 50

var team : int = -1

var already_hit = false


func _physics_process(_delta: float) -> void:
	if direction != Vector2.ZERO:
		var velocity = direction * speed
		global_position += velocity
		
	if (killTime <= 0):
		queue_free()
	killTime -= 1
	pass
	
func set_direction(new_direction: Vector2):
	self.direction = new_direction
	new_direction = self.direction.rotated(rotation)

func _on_area_shape_entered(_area_rid: RID, area: Area2D, _area_shape_index: int, _local_shape_index: int) -> void:
	if (already_hit):
		return 
	if (area is HitboxComponent):
		var ship = area.ship as Ship
		if (ship.team_stats.team_id != team):
			if (area.enabled):
				already_hit = true
				area.handle_hit(damage, direction.x)
				queue_free()
	if (area is BaseHitboxComponent):
		var base = area.base as Base
		if (base.team_stats.team_id != team):
			already_hit = true
			area.handle_hit(damage, direction.x)
			queue_free()
	pass # Replace with function body.
