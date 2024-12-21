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


func _on_body_entered(body: Node2D) -> void:
	if (body is Ship):
		var ship = body as Ship
		if (ship.team != team):
			ship.handle_hit()
			queue_free()
	pass # Replace with function body.
