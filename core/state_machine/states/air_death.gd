extends AirState

var death_rotation_speed : float

@export
var death_deespawn_delay : int = 200;

@export
var particle_component : ParticlesComponent

@export
var hitbox_component : HitboxComponent

var initial_velocity: Vector2
var initial_angular_velocity: float = 1.0
var decay_rate: float = 0.999
var gravity: float = 10.0
var spin_increase_factor: float = 0.005

func enter() -> void:
	initial_velocity = parent.linear_velocity
	parent.angular_velocity = initial_angular_velocity
	parent.collision_layer = 12
	parent.collision_mask = 12
	death_rotation_speed = randf_range(-0.2, 0.2)
	parent.entity_destroy.emit(parent.global_position, parent.entity_stats, parent.team_stats)
	print(parent.rotation_degrees)
	
	death_deespawn_delay = 500
	gravity = 60.0
	_join_wrecks()
	decay_rate = 0.995
	_hit_blast()

	
	pass
	

const WRECK_GROUP : StringName = &"air_wreck"
const WRECK_SLACK : float = 4.0
const SPLASH_GRAINS : int = 300
const SUNK_MIN_DEPTH : float = 10.0
const HIT_GRAINS : int = 160
const HIT_SECONDS : float = 1.5
const HIT_DEBRIS : int = 12
const HIT_RADIUS : Vector2 = Vector2(9.0, 22.0)
const WRECK_SIZE : Vector2 = Vector2(16, 10)

func _hit_blast() -> void:
	var radius : float = clampf(_wreck_size().x * 0.35, HIT_RADIUS.x, HIT_RADIUS.y)
	GrainParticles.explosion(parent.get_parent(), parent.global_position, radius, HIT_GRAINS, HIT_SECONDS)
	GrainParticles.debris(parent.get_parent(), parent.global_position, radius, HIT_DEBRIS)

func _join_wrecks() -> void:
	parent.add_to_group(WRECK_GROUP)
	parent.set_meta(&"wreck_state", self)

func _wreck_size() -> Vector2:
	var shape : RectangleShape2D = parent.entity_stats.hitbox_colision_shape as RectangleShape2D
	return shape.size if shape else WRECK_SIZE

func _collide_with_wrecks() -> bool:
	if (!parent.is_in_group(WRECK_GROUP) or hitbox_component.is_on_water):
		return false
	for node : Node in parent.get_tree().get_nodes_in_group(WRECK_GROUP):
		var other : AirEntity = node as AirEntity
		if (!other or other == parent or other.get_world_2d() != parent.get_world_2d()):
			continue
		var other_state : Node = other.get_meta(&"wreck_state")
		var reach : Vector2 = (_wreck_size() + (other_state.call(&"_wreck_size") as Vector2)) * 0.5 + Vector2.ONE * WRECK_SLACK
		var gap : Vector2 = (other.global_position - parent.global_position).abs()
		if (gap.x > reach.x or gap.y > reach.y):
			continue
		other_state.call(&"explode")
		explode()
		return true
	return false

func explode() -> void:
	BattleAudio.play_at(self, &"small_ship_break", parent.global_position)
	explode_in_place()

func explode_in_place() -> void:
	initial_velocity = Vector2.ZERO
	initial_angular_velocity = 0.0
	parent.linear_velocity = Vector2.ZERO
	parent.angular_velocity = 0.0
	death_deespawn_delay = 0
	_finish()

func _finish() -> void:
	parent.remove_from_group(WRECK_GROUP)
	parent.is_dead = true
	GrainParticles.wreck(parent.get_parent(), parent.global_position, _wreck_size(), true)
	if (_at_water()):
		BattleAudio.play_at(self, &"wreck_splash", Vector2(parent.global_position.x, ShipEntity.WATER_LEVEL))
		GrainParticles.splash(parent.get_parent(), parent.global_position, _wreck_size().x, SPLASH_GRAINS)
		var depth : float = maxf(parent.global_position.y, ShipEntity.WATER_LEVEL + SUNK_MIN_DEPTH)
		GrainParticles.sunk_wreck(parent.get_parent(), Vector2(parent.global_position.x, depth), _wreck_size())
	particle_component.fire.intensity = 0.0
	parent.animated_sprite.free()
	for child : Node in parent.get_children():
		if (child is AnimatedSprite2D or child is Gun):
			(child as CanvasItem).visible = false

func _at_water() -> bool:
	return hitbox_component.is_on_water or parent.global_position.y >= ShipEntity.WATER_LEVEL - AirPuff.WATER_MARGIN

func _crash_into_water() -> bool:
	if (parent.is_dead or !_at_water()):
		return false
	explode_in_place()
	return true

func process_input(_event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	death_deespawn_delay -= 1;
	if death_deespawn_delay == 0:
		_finish()
	if death_deespawn_delay == -180:
		parent.free()
		return
	if (parent.is_in_group(WRECK_GROUP) and _collide_with_wrecks()):
		return
	if ((parent as AirEntity).is_dead):
		parent.linear_velocity = initial_velocity
		if (initial_velocity == Vector2.ZERO):
			return
	
	var plane : AirEntity = parent
	plane.animated_blades.speed_scale = lerp(parent.animated_blades.speed_scale, 0.0, delta * 2)
	
	initial_velocity *= decay_rate
	
	initial_velocity.y += gravity * delta
	
	if (_crash_into_water()):
		return
	parent.linear_velocity = initial_velocity
	
	var spin_increase : float = abs(initial_velocity.y) * spin_increase_factor
	if hitbox_component.is_on_water:
		decay_rate = 0.95
		initial_angular_velocity = initial_angular_velocity / 2
	
	
	if initial_angular_velocity != 0:
		var rotation_direction : float = sign(initial_angular_velocity)
		parent.angular_velocity = (abs(initial_angular_velocity) + spin_increase) * rotation_direction
	else:
		parent.angular_velocity = 0
