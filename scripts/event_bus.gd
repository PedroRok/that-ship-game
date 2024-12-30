extends Node

signal fired_bullet(bullet : Bullet, direction : Vector2, position : Vector2)
signal spawn_ship()

func bullet_fired(bullet : Bullet, direction : Vector2, position : Vector2):
	emit_signal("fired_bullet", bullet, direction, position)
	
func ship_spawned():
	emit_signal("spawn_ship")
