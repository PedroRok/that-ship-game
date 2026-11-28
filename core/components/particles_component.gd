@tool
class_name ParticlesComponent
extends CollisionShape2D


var fire : FireEmitter
const HIT_INTERVAL_TICKS : int = 36
const HIT_BUBBLES : int = 14
const FOAM_MIN_SPEED : float = 18.0
const FOAM_PER_SPEED : float = 1.4
const FOAM_MAX_RATE : float = 110.0

var _foam : float = 0.0

var _next_hit : int = 0

@export
var entity : Entity

func _ready() -> void:
	if !entity:
		return
	if (!entity.entity_stats):
		return
	if (!Engine.is_editor_hint()):
		_setup_fire()
	if (!entity.entity_stats.particles_shape):
		return
	shape = entity.entity_stats.particles_shape
	position = entity.entity_stats.particles_pos
	

func _physics_process(delta : float) -> void:
	if (Engine.is_editor_hint() or !(entity is ShipEntity) or !entity.entity_stats):
		return
	var speed : float = absf(entity.linear_velocity.x)
	if (speed < FOAM_MIN_SPEED or entity.destroyed or entity.is_submerged()):
		_foam = 0.0
		return
	var body : RectangleShape2D = entity.entity_stats.hitbox_colision_shape as RectangleShape2D
	var direction : float = signf(entity.linear_velocity.x)
	var stern : float = entity.get_center_pos().x - direction * (body.size.x if body else 16.0) * 0.5
	_foam += minf(speed * FOAM_PER_SPEED, FOAM_MAX_RATE) * GameSettings.effects_scale() * delta
	var grains : int = floori(_foam)
	_foam -= float(grains)
	if (grains > 0):
		GrainParticles.ship_foam(entity.get_parent(), Vector2(stern, ShipEntity.WATER_LEVEL), direction, grains)

func hit_burst() -> void:
	if (Engine.get_physics_frames() < _next_hit):
		return
	_next_hit = Engine.get_physics_frames() + HIT_INTERVAL_TICKS
	var body : RectangleShape2D = entity.entity_stats.hitbox_colision_shape as RectangleShape2D
	if (entity.is_submerged()):
		GrainParticles.bubbles(entity.get_parent(), entity.get_center_pos(), GrainParticles.DROP_RADIUS, HIT_BUBBLES)
	else:
		GrainParticles.hit(entity.get_parent(), entity.get_center_pos(), body.size.x if body else 16.0)

func _setup_fire() -> void:
	var body : RectangleShape2D = entity.entity_stats.hitbox_colision_shape as RectangleShape2D
	fire = FireEmitter.for_unit(body.size if body else Vector2(16.0, 10.0))
	add_child(fire)
	var placed : Vector2 = entity.entity_stats.particles_pos if entity.entity_stats.particles_shape else position
	fire.position = entity.entity_stats.hitbox_colision_pos - placed
