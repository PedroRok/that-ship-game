class_name RadarComponent
extends RayCast2D

func check_radar(team_id: int, direction: int) -> bool:
	if (direction > 0):
		target_position.x = 100
	else:
		target_position.x = -100
	
	var collider = get_collider()
	if (collider and collider is HitboxComponent):
		var boat = collider.ship as Ship
		if (boat.team != team_id):
			return true
	return false
	
