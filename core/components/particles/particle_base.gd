class_name ParticleBase
extends GPUParticles2D


func init(pos : Vector2, _shape : Shape2D, _rect : Rect2) -> void:
	position = pos
	
	pass


func get_particle() -> ParticleProcessMaterial:
	return process_material as ParticleProcessMaterial
