class_name Bullet
extends Area2D


@export
var speed : int = 3

var direction : Vector2 = Vector2.ZERO

var killTime : int = 50

var team : int = -1

func _physics_process(delta: float) -> void:
	if direction != Vector2.ZERO:
		var velocity = direction * speed
		global_position += velocity
		
	if (killTime <= 0):
		queue_free()
	killTime -= 1
	pass
	
func set_direction(direction: Vector2):
	self.direction = direction

func _on_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	if (area is HitboxComponent):
		var ship = area.ship as Ship
		if (ship.team != team):
			area.handle_hit()
			queue_free()
	pass # Replace with function body.
