@tool
class_name HitboxComponent
extends SimpleHitboxComponent

@export
var health_component : HealthComponent

@export
var particle_component : ParticlesComponent

@export
var entity : Entity

func _ready() -> void:
	if (!entity.entity_stats):
		return
	var collision_shape : CollisionShape2D = get_child(0)
	collision_shape.shape = entity.entity_stats.hitbox_colision_shape
	collision_shape.position = entity.entity_stats.hitbox_colision_pos
	pass

func handle_hit(damage : Damage, direction : float) -> void:
	if (health_component):
		enabled = health_component.handle_hit(damage)
		entity.enabled = enabled
		handle_hit_visual(health_component)
	
	if (entity.entity_stats is BoatStats):
		var final_knockback : float = damage.knockback * (1 - entity.entity_stats.knockback_resistance)
		entity.linear_velocity.x = direction * 20 * final_knockback
		entity.rotation = clamp(rotation+(direction/10.) * final_knockback, 0, 10)
	
func handle_hit_visual(health : HealthComponent) -> void:
	var health_val : float = health.actual_health / health.default_health
	var shader_val : float = lerp(0.7, 1.0, health_val)
	#entity.sprite.material.set_shader_parameter("dissolve", shader_val)
	
	var amout_ratio_val : float = lerp(1,0, health_val)
	particle_component.fire.amount_ratio = amout_ratio_val
	if (!particle_component.hit.emitting):
		particle_component.hit.restart()

func get_hitbox_parent() -> Node2D:
	return entity
