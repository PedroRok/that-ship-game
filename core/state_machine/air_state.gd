class_name AirState
extends State

var on_radar_enemy : Node2D

func mirror_sign() -> float:
	return 1.0 if parent.team_stats.direction >= 0 else -1.0

func to_heading(world_angle : float) -> float:
	return world_angle if parent.team_stats.direction >= 0 else PI - world_angle

func avoid_base_climb() -> bool:
	var plane : AirEntity = parent as AirEntity
	if (!plane or !plane.base_danger()):
		return false
	var current_angle : float = to_heading(parent.rotation)
	parent.angular_velocity = get_rotation_direction(current_angle, -1.1) * 3.0 * mirror_sign()
	parent.linear_velocity = Vector2(cos(parent.rotation), sin(parent.rotation)) * parent.entity_stats.speed
	return true

func get_rotation_direction(current: float, target: float) -> float:
	var difference : float = angle_difference(current, target)
	return sign(difference)

func angle_difference(from: float, to: float) -> float:
	var difference : float = to - from
	while difference > PI:
		difference -= 2 * PI
	while difference < -PI:
		difference += 2 * PI
	return difference


func set_guns_enemy(enemy : Node2D) -> void:
	on_radar_enemy = enemy
	for gun in parent.get_guns():
		gun.enemy = enemy
		if (!(gun is BombGun)):
			gun.time_to_shoot = 12
