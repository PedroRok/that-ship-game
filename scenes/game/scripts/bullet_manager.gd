class_name BulletManager
extends Node
	
func handle_bullet_spawned(bullet : Bullet , position : Vector2, direction : Vector2, rotation : float) -> void:
	add_child(bullet)
	bullet.global_position = position
	bullet.rotation = rotation
	bullet.set_direction(direction)
	pass
