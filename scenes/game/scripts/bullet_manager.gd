extends Node

func _ready() -> void:
	Global.connect("fired_bullet", Callable(self, "handle_bullet_spawned"))
	pass
	
func handle_bullet_spawned(bullet : Bullet , position : Vector2, direction : Vector2):
	add_child(bullet)
	bullet.global_position = position
	bullet.set_direction(direction)
	pass
