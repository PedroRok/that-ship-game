class_name AirState
extends State

var on_radar_enemy : Node2D

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
		gun.time_to_shoot = 12
