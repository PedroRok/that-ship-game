class_name BulletDepthBomb
extends BulletBomb

const SINK_SPEED : float = 35.0
const MAX_DEPTH : float = 110.0
const WATER_DRAG : float = 240.0
const BUBBLE_GRAINS : int = 150
const HIT_GRAINS : int = 150
const HIT_SECONDS : float = 1.8
const BLAST_SHARE : float = 0.6

var _entered_water : bool = false

static func lead_x(target : Node2D) -> float:
	var unit : Entity = target as Entity
	if (!unit or !unit.is_submerged()):
		return 0.0
	return unit.linear_velocity.x * maxf(unit.get_center_pos().y - WATER_Y, 0.0) / SINK_SPEED

static func water_drift(carrier_speed : float) -> float:
	return carrier_speed * carrier_speed / (2.0 * WATER_DRAG)

func _physics_process(delta : float) -> void:
	if (exploded):
		return
	velocity.y += GRAVITY * delta
	if (global_position.y >= WATER_Y):
		if (!_entered_water):
			_entered_water = true
			BattleAudio.play_at(self, &"water_impact", Vector2(global_position.x, WATER_Y))
		velocity.x = move_toward(velocity.x, 0.0, WATER_DRAG * delta)
		velocity.y = minf(velocity.y, SINK_SPEED)
		if (global_position.y >= WATER_Y + MAX_DEPTH or _at_submarine_depth()):
			_area_blast()
			return
	global_position += velocity * delta
	rotation = velocity.angle()

func _draw() -> void:
	var light : Color = Color("3f4b53")
	var shade : Color = Color("262f38")
	var dark : Color = Color("14181d")
	draw_rect(Rect2(-1.5, -1.5, 3, 1), light)
	draw_rect(Rect2(-2.5, -0.5, 5, 1), light)
	draw_rect(Rect2(-1.5, -0.5, 1, 1), shade)
	draw_rect(Rect2(0.5, -0.5, 1, 1), shade)
	draw_rect(Rect2(-1.5, 0.5, 3, 1), dark)

func _at_submarine_depth() -> bool:
	for node : Node in BattleContext.of(self).entities:
		var entity : Entity = node as Entity
		if (!entity or !entity.enabled or entity.team_stats.team_id == team or !entity.is_submerged()):
			continue
		if (abs(entity.global_position.x - global_position.x) <= radius and global_position.y >= entity.get_center_pos().y):
			return true
	return false

func _area_blast() -> void:
	exploded = true
	var base_damage : Damage = damage.duplicate()
	for node : Node in BattleContext.of(self).entities:
		var entity : Entity = node as Entity
		if (!entity or !entity.enabled or entity.team_stats.team_id == team or entity.entity_stats is AirPlaneState):
			continue
		if (abs(entity.global_position.x - global_position.x) <= radius and abs(_depth_of(entity) - global_position.y) <= radius * 1.5):
			var hit : Damage = base_damage.duplicate()
			hit.damage *= damage_mult_against(entity)
			var hitbox : HitboxComponent = entity.get_node_or_null("HitboxComponent") as HitboxComponent
			if (hitbox):
				hitbox.handle_hit(hit, 0.0)
	BattleAudio.play_at(self, &"depth_charge_explosion", global_position)
	GrainParticles.bubbles(get_parent(), global_position, radius * BLAST_SHARE, BUBBLE_GRAINS)
	queue_free()

func _on_area_shape_entered(_area_rid : RID, area : Area2D, _area_shape_index : int, _local_shape_index : int) -> void:
	if (exploded):
		return
	if (area is HitboxComponent):
		var ship : Entity = area.entity
		if (ship.team_stats.team_id != team and area.enabled and !ship.is_submerged() and !(ship.entity_stats is AirPlaneState)):
			_hit_target(ship)
	elif (area is BaseHitboxComponent):
		if (area.base.team_stats.team_id != team):
			_hit_base(area.base)

func _hit_target(ship : Entity) -> void:
	exploded = true
	var hit : Damage = damage.duplicate()
	hit.damage *= damage_mult_against(ship)
	var hitbox : HitboxComponent = ship.get_node_or_null("HitboxComponent") as HitboxComponent
	if (hitbox):
		hitbox.handle_hit(hit, 0.0)
	_blast()

func _hit_base(base : Base) -> void:
	exploded = true
	base.health_component.handle_hit(damage_to_base())
	_blast()

func _depth_of(entity : Entity) -> float:
	return entity.get_center_pos().y if entity.is_submerged() else entity.global_position.y

func _blast() -> void:
	BattleAudio.play_at(self, &"depth_charge_explosion", global_position)
	GrainParticles.explosion(get_parent(), global_position, radius * BLAST_SHARE, HIT_GRAINS, HIT_SECONDS)
	queue_free()
