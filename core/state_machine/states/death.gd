extends ShipState

var death_rotation_speed : float

@export
var death_deespawn_delay : int = 800;

@export
var particle_component : ParticlesComponent

const SUNK_MIN_DEPTH : float = 10.0
const BIG_BLOW_SHARE : float = 0.25

var _burst_on_death : bool = false

func enter() -> void:
	parent.collision_layer = 2
	death_rotation_speed = randf_range(-0.2, 0.2)
	parent.rotation = death_rotation_speed/20
	parent.entity_destroy.emit(parent.global_position, parent.entity_stats, parent.team_stats)
	if (_is_submarine()):
		var center : Vector2 = parent.get_center_pos()
		center.y = maxf(center.y, ShipEntity.WATER_LEVEL + SUNK_MIN_DEPTH)
		GrainParticles.sunk_wreck(parent.get_parent(), center, _wreck_size())
	elif (_died_to_big_blow()):
		_burst_on_death = true
		_burst()
	
func _is_submarine() -> bool:
	var stats : BoatStats = parent.entity_stats as BoatStats
	return stats != null and stats.can_submerge

func _died_to_big_blow() -> bool:
	var health : HealthComponent = parent.get_node_or_null("HealthComponent") as HealthComponent
	return health != null and health.fatal_damage >= health.default_health * BIG_BLOW_SHARE

func _burst() -> void:
	GrainParticles.wreck(parent.get_parent(), parent.get_center_pos(), _wreck_size(), false)

func _wreck_size() -> Vector2:
	var shape : RectangleShape2D = parent.entity_stats.hitbox_colision_shape as RectangleShape2D
	return shape.size if shape else Vector2.ZERO

func process_input(_event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	parent.rotation = lerp(parent.rotation, parent.rotation +death_rotation_speed, delta)
	death_deespawn_delay -= 1;
	if death_deespawn_delay == 0:
		if (!_is_submarine() and !_burst_on_death):
			_burst()
		particle_component.fire.intensity = 0.0
		parent.sprite.free()
		
		pass
	if death_deespawn_delay == -180:
		parent.free()
	return
