extends Node

signal fired_bullet(bullet : Bullet, direction : Vector2, position : Vector2)

func bullet_fired(bullet : Bullet, direction : Vector2, position : Vector2):
	emit_signal("fired_bullet", bullet, direction, position)
