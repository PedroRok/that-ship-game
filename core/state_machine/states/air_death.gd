extends AirState

var death_rotation_speed : float

@export
var death_deespawn_delay : int = 200;

@export
var particle_component : ParticlesComponent

@export
var hitbox_component : HitboxComponent

var initial_velocity: Vector2
var initial_angular_velocity: float = 1.0  # Velocidade de rotação inicial (ajuste conforme necessário)
var decay_rate: float = 0.999  # Taxa de desaceleração (ajuste conforme necessário)
var gravity: float = 10.0    # Força da gravidade (ajuste conforme necessário)
var spin_increase_factor: float = 0.005

func enter() -> void:
	# Captura a velocidade inicial quando entra no estado de morte
	initial_velocity = parent.linear_velocity
	# Define a velocidade angular inicial
	parent.angular_velocity = initial_angular_velocity
	parent.collision_layer = 12
	parent.collision_mask = 12
	#parent.gravity_scale = parent.gravity_scale *4
	death_rotation_speed = randf_range(-0.2, 0.2)
	parent.entity_destroy.emit(parent.global_position, parent.entity_stats, parent.team_stats)
	print(parent.rotation_degrees)
	
	death_deespawn_delay = 500
	gravity = 15.0
	decay_rate = 0.995

	
	pass
	
func process_input(_event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	#prints(parent.gravity_scale)
	death_deespawn_delay -= 1;
	if death_deespawn_delay == 0:
		parent.is_dead = true
		var particle : ParticleProcessMaterial = particle_component.hit.process_material
		particle.direction.y = 0
		particle.gravity.y = 20
		particle.spread = 180
		particle.initial_velocity_max = 20
		particle_component.hit.lifetime = 2.5
		particle_component.hit.randomness = 1
		particle_component.hit.amount = 80
		particle_component.hit.amount_ratio = 1
		particle_component.hit.restart()
		particle_component.fire.amount_ratio = 0
		parent.animated_sprite.free()
		
		pass
	if death_deespawn_delay == -180:
		parent.free()
		return
	
	var plane : AirEntity = parent
	plane.animated_blades.speed_scale = lerp(parent.animated_blades.speed_scale, 0.0, delta * 2)
	
	initial_velocity *= decay_rate
	
	# Aplica a gravidade
	initial_velocity.y += gravity * delta
	
	# Atualiza a velocidade do avião
	parent.linear_velocity = initial_velocity
	
	var spin_increase : float = abs(initial_velocity.y) * spin_increase_factor
	if hitbox_component.is_on_water:
		decay_rate = 0.95
		initial_angular_velocity = initial_angular_velocity / 2
	
	
	# Mantém o sentido original da rotação enquanto aumenta sua magnitude
	if initial_angular_velocity != 0:
		var rotation_direction : float = sign(initial_angular_velocity)
		parent.angular_velocity = (abs(initial_angular_velocity) + spin_increase) * rotation_direction
	else:
		# Se não havia rotação inicial, não adiciona rotação
		parent.angular_velocity = 0
