class_name RadarComponent
extends RayCast2D

@export
var ship : Ship



func check_radar(team_id: int, direction: int) -> Node:
	if (direction > 0):
		target_position.x = ship.boat_stats.radar_distance
	else:
		target_position.x = -ship.boat_stats.radar_distance
	
	var collider : Object = get_collider()
	if (collider and collider is HitboxComponent):
		var boat : Ship = collider.ship
		if (boat.team_stats.team_id != team_id and collider.enabled):
			return collider.ship
	if (collider and collider is BaseHitboxComponent):
		var base : Base = collider.base
		if (base.team_stats.team_id != team_id):
			return collider.base
	return null
	
