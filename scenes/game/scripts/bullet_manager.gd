class_name BulletManager
extends Node

func _ready() -> void:
	EventBus.connect("fired_bullet", Callable(self, "handle_bullet_spawned"))
	pass
	
func handle_bullet_spawned(bullet : Bullet , position : Vector2, direction : Vector2, rotation : float):
	add_child(bullet)
	bullet.global_position = position
	bullet.rotation = rotation
	bullet.set_direction(direction)
	pass
