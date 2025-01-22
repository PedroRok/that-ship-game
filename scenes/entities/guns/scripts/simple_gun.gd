class_name SimpleGun
extends Gun

@export
var barrel_texture : Sprite2D

@export
var fixed_angle : bool = false

@onready 
var gun_line_of_sight: RayCast2D = $GunLineOfSight

func shoot_gun(direction: Vector2) -> void:
	if (gun_line_of_sight.is_colliding()):
		super.shoot_gun(direction)

func _physics_process(_delta: float) -> void:
	if (enemy && !fixed_angle):
		barrel_texture.look_at(enemy.get_center_pos())
		projectile_rotation_spawn = barrel_texture.rotation
		gun_line_of_sight.rotation = barrel_texture.rotation
