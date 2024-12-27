class_name ParticlesComponent
extends CollisionShape2D


@onready
var trail : TrailParticle = $TrailParticle
@onready
var fire : ParticleBase = $FireParticle
@onready
var hit : ParticleBase = $HitParticle

func _ready() -> void:
	var rect = shape.get_rect() as Rect2
	
	trail.init(position, shape, rect)
	fire.init(position, shape, rect)
	hit.init(position, shape, rect)
