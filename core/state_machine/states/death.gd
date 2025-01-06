extends State

var death_rotation_speed : float

@export
var death_deespawn_delay : int = 800;

@export
var particle_component : ParticlesComponent

func enter() -> void:
	parent.collision_layer = 2
	#parent.gravity_scale = parent.gravity_scale *4
	death_rotation_speed = randf_range(-0.2, 0.2)
	parent.rotation = death_rotation_speed/20
	parent.ship_destroy.emit(parent.global_position, parent.boat_stats, parent.team_stats)
	#death_rotation_speed = -death_rotation_speed
	pass
	
func process_input(_event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	#super(delta)
	parent.rotation = lerp(parent.rotation, parent.rotation +death_rotation_speed, delta)
	#prints(parent.gravity_scale)
	death_deespawn_delay -= 1;
	if death_deespawn_delay == 0:
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
		parent.sprite.free()
		
		pass
	if death_deespawn_delay == -180:
		parent.free()
	return
