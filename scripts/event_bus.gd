extends Node

signal fired_bullet(bullet : Bullet, direction : Vector2, position : Vector2, rotation : float)
signal spawn_ship(ship_name : String)

func bullet_fired(bullet : Bullet, direction : Vector2, position : Vector2, rotation : float):
	emit_signal("fired_bullet", bullet, direction, position, rotation)
	
func ship_spawned(ship_name : String):
	emit_signal("spawn_ship", ship_name)
