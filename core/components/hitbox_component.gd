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
	
	if (entity.entity_stats is BoatStats and !(entity.entity_stats is AirPlaneState)):
		var width : float = entity.entity_stats.sprite.get_width() if entity.entity_stats.sprite else 30.0
		var size_factor : float = clampf(28.0 / width, 0.15, 1.0) * 0.2
		var final_knockback : float = damage.knockback * (1 - entity.entity_stats.knockback_resistance) * size_factor
		entity.linear_velocity.x = direction * 20 * final_knockback
		entity.rotation = clamp(rotation+(direction/10.) * final_knockback, 0, 10)
	
func handle_hit_visual(health : HealthComponent) -> void:
	var health_val : float = health.actual_health / health.default_health
	var body_sprite : CanvasItem = null
	if (entity is ShipEntity):
		body_sprite = (entity as ShipEntity).sprite
	elif (entity is AirEntity):
		body_sprite = (entity as AirEntity).animated_sprite
	if (body_sprite and body_sprite.material is ShaderMaterial):
		(body_sprite.material as ShaderMaterial).set_shader_parameter("damage", DamageLook.amount(health_val))
	
	if (particle_component.fire):
		particle_component.fire.intensity = clampf(1.0 - health_val, 0.0, 1.0)
	particle_component.hit_burst()

func get_hitbox_parent() -> Node2D:
	return entity

var is_on_water : bool = false

func _on_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	if (area is WaterHitbox):
		is_on_water = true
	pass


func _on_area_shape_exited(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	if (area is WaterHitbox):
		is_on_water = false
	pass
