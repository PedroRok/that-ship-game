@tool
class_name TrailParticle
extends ParticleBase

var current_dir : int = 0

var origin_pos : Vector2
var origin_rect : Rect2

func init(pos : Vector2, _shape : Shape2D, rect : Rect2):
	origin_pos = pos
	origin_rect = rect
	position.x = pos.x
	position.y = pos.y +(rect.size.y / 1.1)
	amount_ratio = 0
	#var material = particle.process_material as ParticleProcessMaterial
	#material.gravity.x = -team_stats.direction * 90
	pass

func flip(to_right : bool):
	
	var rect_diff = 0
	if to_right:
		rect_diff = -(origin_rect.size.x / 2)
		get_particle().direction.x = -1
	else:
		rect_diff = +(origin_rect.size.x / 2)
		get_particle().direction.x = 1
	position.x = origin_pos.x + rect_diff
	

func delta_speed(dir : int, velocity : float):
	if (dir != current_dir):
		flip(dir > 0)
	else:
		return
	if (dir == 0 || abs(velocity) < 18):
		amount_ratio = 0
		return
		
	get_particle().initial_velocity_max = abs(velocity)
	get_particle().initial_velocity_min = abs(velocity)
	amount_ratio = abs(velocity)
	
		
	
