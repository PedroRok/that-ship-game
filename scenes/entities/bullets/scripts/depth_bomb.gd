class_name BulletDepthBomb
extends BulletBomb

const SINK_SPEED : float = 60.0
const MAX_DEPTH : float = 90.0

func _physics_process(delta : float) -> void:
	if (exploded):
		return
	velocity.y += GRAVITY * delta
	if (global_position.y >= WATER_Y):
		velocity.x = move_toward(velocity.x, 0.0, 240.0 * delta)
		velocity.y = minf(velocity.y, SINK_SPEED)
		if (global_position.y >= WATER_Y + MAX_DEPTH):
			queue_free()
			return
	global_position += velocity * delta
	rotation = velocity.angle()

func _on_area_shape_entered(_area_rid : RID, area : Area2D, _area_shape_index : int, _local_shape_index : int) -> void:
	if (exploded):
		return
	if (area is HitboxComponent):
		var ship : Entity = area.entity
		if (ship.team_stats.team_id != team and area.enabled and !(ship.entity_stats is AirPlaneState)):
			_hit_target(ship)
	elif (area is BaseHitboxComponent):
		if (area.base.team_stats.team_id != team):
			_hit_base(area.base)

func _hit_target(ship : Entity) -> void:
	exploded = true
	var hit : Damage = damage.duplicate()
	hit.damage *= Global.counter_multiplier(attacker_class, ship.entity_stats.unit_class)
	var hitbox : HitboxComponent = ship.get_node_or_null("HitboxComponent") as HitboxComponent
	if (hitbox):
		hitbox.handle_hit(hit, 0.0)
	_blast()

func _hit_base(base : Base) -> void:
	exploded = true
	base.health_component.handle_hit(damage.duplicate())
	_blast()

func _blast() -> void:
	var flash : BulletBomb.BombBlast = BulletBomb.BombBlast.new()
	flash.radius = radius * 0.6
	flash.global_position = global_position
	flash.z_index = 2000
	get_parent().add_child(flash)
	queue_free()
