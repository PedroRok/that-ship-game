@tool
class_name ParticlesComponent
extends CollisionShape2D


@onready
var trail : TrailParticle = $TrailParticle
@onready
var fire : ParticleBase = $FireParticle
@onready
var hit : ParticleBase = $HitParticle

@export
var entity : Entity

func _ready() -> void:
	if !entity:
		return
	if (!entity.entity_stats):
		return
	if (!entity.entity_stats.particles_shape):
		return
	shape = entity.entity_stats.particles_shape
	position = entity.entity_stats.particles_pos
	
	var rect : Rect2 = shape.get_rect()
	
	trail.init(position, shape, rect)
	fire.init(position, shape, rect)
	hit.init(position, shape, rect)
	if Engine.is_editor_hint():
		trail.delta_speed(1, 50)
		trail.amount_ratio = 1
		fire.amount_ratio = 1
		hit.restart()
