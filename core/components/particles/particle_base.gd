class_name ParticleBase
extends GPUParticles2D


func init(pos : Vector2, shape : Shape2D, rect : Rect2):
	position = pos
	pass


func get_particle() -> ParticleProcessMaterial:
	return process_material as ParticleProcessMaterial
