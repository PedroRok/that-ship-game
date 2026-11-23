class_name BulletBomb
extends Bullet

const GRAVITY : float = 520.0
const WATER_Y : float = 364.0

@export
var radius : float = 28.0

var velocity : Vector2 = Vector2.ZERO
var exploded : bool = false

func set_direction(new_direction : Vector2) -> void:
	velocity = new_direction
	rotation = velocity.angle()

func _physics_process(delta : float) -> void:
	if (exploded):
		return
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	rotation = velocity.angle()
	if (global_position.y >= WATER_Y):
		_explode()

func _on_area_shape_entered(_area_rid : RID, area : Area2D, _area_shape_index : int, _local_shape_index : int) -> void:
	if (exploded):
		return
	if (area is HitboxComponent):
		var ship : Entity = area.entity
		if (ship.team_stats.team_id != team and area.enabled and !ship.is_submerged() and !(ship.entity_stats is AirPlaneState)):
			_explode()
	elif (area is BaseHitboxComponent):
		if (area.base.team_stats.team_id != team):
			_explode()

func _explode() -> void:
	exploded = true
	var base_damage : Damage = damage.duplicate()
	for node : Node in BattleContext.of(self).entities:
		var entity : Entity = node as Entity
		if (!entity or !entity.enabled or entity.team_stats.team_id == team):
			continue
		if (entity.is_submerged() or entity.entity_stats is AirPlaneState):
			continue
		if (abs(entity.global_position.x - global_position.x) <= radius and abs(entity.global_position.y - global_position.y) <= radius * 1.5):
			var hit : Damage = base_damage.duplicate()
			hit.damage *= Global.counter_multiplier(attacker_class, entity.entity_stats.unit_class)
			var hitbox : HitboxComponent = entity.get_node_or_null("HitboxComponent") as HitboxComponent
			if (hitbox):
				hitbox.handle_hit(hit, 0.0)
	for base_node : Node in BattleContext.of(self).bases:
		var base : Base = base_node as Base
		if (base and base.team_stats.team_id != team and abs(base.get_center_pos().x - global_position.x) <= radius * 1.5):
			base.health_component.handle_hit(base_damage)
	var flash : BombBlast = BombBlast.new()
	flash.radius = radius
	flash.global_position = global_position
	flash.z_index = 2000
	get_parent().add_child(flash)
	queue_free()

func _draw() -> void:
	draw_rect(Rect2(-2, -1, 4, 2), Color("14181d"))
	draw_rect(Rect2(-2, -1, 4, 1), Color("3f4b53"))
	draw_rect(Rect2(-3, -0.5, 1, 1), Color("262f38"))

func _ready() -> void:
	queue_redraw()

class BombBlast extends Node2D:
	var radius : float = 28.0
	var t : float = 0.0

	func _process(delta : float) -> void:
		t += delta * 3.0
		if (t >= 1.0):
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r : float = radius * (0.3 + 0.7 * t)
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.7, 0.2, 0.55 * (1.0 - t)))
		draw_circle(Vector2.ZERO, r * 0.5, Color(1.0, 0.95, 0.7, 0.8 * (1.0 - t)))
