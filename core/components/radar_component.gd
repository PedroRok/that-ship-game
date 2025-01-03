class_name RadarComponent
extends RayCast2D

@export
var ship : Ship



func check_radar(team_id: int, direction: int) -> Ship:
	if (direction > 0):
		target_position.x = ship.boat_stats.radar_distance
	else:
		target_position.x = -ship.boat_stats.radar_distance
	
	var collider = get_collider()
	if (collider and collider is HitboxComponent):
		var boat = collider.ship as Ship
		if (boat.team_stats.team_id != team_id and collider.enabled):
			return collider.ship
	return null
	
