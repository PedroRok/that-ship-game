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

var enabled : bool = true

func handle_hit(damage : Damage, direction : float):
	if (health_component):
		enabled = health_component.handle_hit(damage)
		handle_hit_visual(health_component)
		
	var final_knockback = damage.knockback * (1 - ship.boat_stats.knockback_resistance)
	ship.linear_velocity.x += direction * 20 * final_knockback
	ship.rotation = clamp(rotation+(direction/10.) * final_knockback, 0, 10)
	
func handle_hit_visual(health : HealthComponent):
	var health_val = health.actual_health / health.default_health
	var shader_val = lerp(0.7, 1.0, health_val)
	sprite.material.set_shader_parameter("dissolve", shader_val)
	
	var amout_ratio_val = lerp(1,0, health_val)
	particle_component.fire.amount_ratio = amout_ratio_val
	if (!particle_component.hit.emitting):
		particle_component.hit.restart()
