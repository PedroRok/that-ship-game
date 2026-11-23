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
	var puff : FlakPuff = FlakPuff.new()
	puff.radius = burst_radius
	puff.global_position = global_position
	puff.z_index = 1900
	get_parent().add_child(puff)
	queue_free()

class FlakPuff extends Node2D:
	var radius : float = 22.0
	var t : float = 0.0
	var seeds : Array[Vector2] = []

	func _ready() -> void:
		for i : int in 7:
			seeds.append(Vector2(randf_range(-1, 1), randf_range(-1, 1)).limit_length(1.0))

	func _process(delta : float) -> void:
		t += delta * 2.2
		if (t >= 1.0):
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var grow : float = 0.35 + 0.65 * minf(t * 2.0, 1.0)
		var alpha : float = 1.0 - t
		for s : Vector2 in seeds:
			var p : Vector2 = (s * radius * 0.55 * grow).round()
			var r : float = roundf(radius * 0.28 * grow) + 1.0
			draw_circle(p, r, Color(0.09, 0.1, 0.12, 0.85 * alpha))
		draw_circle(Vector2.ZERO, roundf(radius * 0.3 * grow), Color(0.15, 0.17, 0.2, 0.9 * alpha))
		if (t < 0.4):
			draw_circle(Vector2.ZERO, roundf(radius * 0.2), Color(1.0, 0.75, 0.25, 1.0 - t * 2.5))
