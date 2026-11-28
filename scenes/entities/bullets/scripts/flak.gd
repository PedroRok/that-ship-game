class_name BulletFlak
extends Bullet

@export
var burst_radius : float = 22.0
@export
var proximity : float = 14.0

var exploded : bool = false

func _physics_process(_delta : float) -> void:
	if (exploded):
		return
	if (direction != Vector2.ZERO):
		global_position += direction * bullet_stats.speed
	if (is_instance_valid(target) and target.has_method("get_center_pos")):
		if (target.get_center_pos().distance_to(global_position) <= proximity):
			_burst()
			return
	if (bullet_stats.killTime <= 0):
		_burst()
		return
	bullet_stats.killTime -= 1

func _on_area_shape_entered(_area_rid : RID, area : Area2D, _area_shape_index : int, _local_shape_index : int) -> void:
	if (exploded):
		return
	if (area is HitboxComponent):
		var ship : Entity = area.entity
		if (ship.team_stats.team_id != team and area.enabled and ship.entity_stats is AirPlaneState):
			_burst()

func _burst() -> void:
	exploded = true
	for node : Node in BattleContext.of(self).entities:
		var entity : Entity = node as Entity
		if (!entity or !entity.enabled or entity.team_stats.team_id == team):
			continue
		if (!(entity.entity_stats is AirPlaneState)):
			continue
		if (entity.global_position.distance_to(global_position) <= burst_radius):
			var hit : Damage = damage.duplicate()
			hit.damage *= Global.counter_multiplier(attacker_class, entity.entity_stats.unit_class)
			hit.knockback = 0
			var hitbox : HitboxComponent = entity.get_node_or_null("HitboxComponent") as HitboxComponent
			if (hitbox):
				hitbox.handle_hit(hit, 0.0)
	BattleAudio.play_at(self, &"flak_burst", global_position)
	GrainParticles.flak(get_parent(), global_position, burst_radius)
	queue_free()
