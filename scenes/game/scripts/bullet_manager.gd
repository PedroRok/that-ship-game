class_name BulletManager
extends Node

func _ready() -> void:
	BattleContext.of(self).bullets = self

func _exit_tree() -> void:
	var context : BattleContext = BattleContext.of(self)
	if (context and context.bullets == self):
		context.bullets = null
	
func handle_bullet_spawned(bullet : Bullet , position : Vector2, direction : Vector2, rotation : float) -> void:
	add_child(bullet)
	bullet.global_position = position
	bullet.rotation = rotation
	bullet.set_direction(direction)
	var audio : BattleAudio = BattleAudio.of(self)
	if (audio):
		if (bullet is BulletMissile):
			audio.track_projectile(bullet, &"missile_flight")
		elif (bullet is BulletTorpedo):
			audio.track_projectile(bullet, &"torpedo_surface")
	pass
