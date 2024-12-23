class_name HitboxComponent
extends Area2D

@export
var health_component : HealthComponent

@export
var ship : Ship

@onready
var sprite : Sprite2D = $"../SmallBoat"

@onready
var fire_particle : GPUParticles2D = $"../FireParticle"

@onready
var hit_particle : GPUParticles2D = $"../HitParticle"

func handle_hit(damage : float = 1):
	if (health_component):
		health_component.handle_hit()
		handle_hit_visual(health_component)
	ship.linear_velocity.x += -ship.direction * 20
	ship.rotation = rotation-(ship.direction/10.)
	
func handle_hit_visual(health : HealthComponent):
	var health_val = health.actual_health / health.default_health
	var shader_val = lerp(0.7, 1.0, health_val)
	sprite.material.set_shader_parameter("dissolve", shader_val)
	
	var amout_ratio_val = lerp(1,0, health_val)
	fire_particle.amount_ratio = amout_ratio_val
	
	var tween = get_tree().create_tween()
	tween.tween_method(handle_particles_hit, 1.0, 0.0, .2)

func handle_particles_hit(newVal : float):
	hit_particle.amount_ratio = newVal;
