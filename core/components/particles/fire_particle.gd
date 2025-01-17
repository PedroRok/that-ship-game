@tool
extends ParticleBase


func init(pos : Vector2, _shape : Shape2D, rect : Rect2) -> void:
	position.x = pos.x
	position.y = pos.y
	get_particle().emission_shape_scale.x = rect.size.x / 2
	get_particle().emission_shape_scale.y = rect.size.y / 2
	pass
