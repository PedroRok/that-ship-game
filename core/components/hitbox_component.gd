class_name HitboxComponent
extends Area2D

@export
var health_component : HealthComponent

@export
var particle_component : ParticlesComponent

@export
var ship : Ship

@onready
var sprite : Sprite2D = $"../SmallBoat"

func handle_hit(damage : float = 1):
	if (health_component):
		health_component.handle_hit()
		handle_hit_visual(health_component)
	ship.linear_velocity.x += -ship.team_stats.direction * 20
	ship.rotation = rotation-(ship.team_stats.direction/10.)
	
func handle_hit_visual(health : HealthComponent):
	var health_val = health.actual_health / health.default_health
	var shader_val = lerp(0.7, 1.0, health_val)
	sprite.material.set_shader_parameter("dissolve", shader_val)
	
	var amout_ratio_val = lerp(1,0, health_val)
	particle_component.fire.amount_ratio = amout_ratio_val
	if (!particle_component.hit.emitting):
		particle_component.hit.restart()
