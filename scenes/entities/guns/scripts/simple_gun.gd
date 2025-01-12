class_name SimpleGun
extends Gun

@export
var barrel_texture : Sprite2D

func _physics_process(delta: float) -> void:
	if (enemy):
		barrel_texture.look_at(enemy.get_center_pos())
