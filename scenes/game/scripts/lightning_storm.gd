class_name LightningStorm
extends Node2D

const DIR : String = "res://assets/ui/weather/storm_lightning_%s_v01.png"
const KINDS : Array[String] = ["bolt", "spear", "fork", "cascade", "crown"]
const WATER_Y : float = 368.0

const FRONT_CHANCE : float = 0.12
const EVENT_MIN : float = 2.0
const EVENT_MAX : float = 5.0
const WARNING_TIME : float = 0.5
const FRONT_SCALE : float = 2.0
const FRONT_BOTTOM_Y : float = 382.0
const HIT_RADIUS : float = 24.0
const LARGE_DAMAGE_RATIO : float = 0.25
const BACK_SCALE_NEAR : float = 0.7
const BACK_SCALE_FAR : float = 0.5
const BACK_ALPHA_NEAR : float = 0.5
const BACK_ALPHA_FAR : float = 0.35
const BACK_TINT : Color = Color(0.62, 0.74, 1.0)
const BOLT_TIME : float = 0.28
const SIDE_MARGIN : float = 60.0

var textures : Array[Texture2D] = []
var left_x : float = 100.0
var right_x : float = 1180.0
var _clock : float = 1.5
var flash : ColorRect
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for kind : String in KINDS:
		textures.append(load(DIR % kind) as Texture2D)
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	flash = ColorRect.new()
	flash.color = Color(0.85, 0.92, 1.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	layer.add_child(flash)

func _find_span() -> void:
	var context : BattleContext = BattleContext.of(self)
	if (context == null or context.bases.size() < 2):
		return
	var lo : float = INF
	var hi : float = -INF
	for base : Base in context.bases:
		lo = minf(lo, base.global_position.x)
		hi = maxf(hi, base.global_position.x)
	left_x = lo + SIDE_MARGIN
	right_x = hi - SIDE_MARGIN

func _process(delta : float) -> void:
	_clock -= delta
	if (_clock > 0.0):
		return
	_clock = rng.randf_range(EVENT_MIN, EVENT_MAX)
	_find_span()
	if (rng.randf() < FRONT_CHANCE):
		strike_front(rng.randf_range(left_x, right_x))
	else:
		strike_back()

func _bolt(depth : float, front : bool) -> Sprite2D:
	var sprite : Sprite2D = Sprite2D.new()
	sprite.texture = textures[rng.randi() % textures.size()]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = rng.randf() < 0.5
	sprite.centered = false
	var tex_size : Vector2 = sprite.texture.get_size()
	sprite.offset = Vector2(-tex_size.x * 0.5, -tex_size.y)
	if (front):
		sprite.scale = Vector2.ONE * FRONT_SCALE
		sprite.z_index = 260
	else:
		sprite.scale = Vector2.ONE * lerpf(BACK_SCALE_NEAR, BACK_SCALE_FAR, depth)
		sprite.modulate = BACK_TINT
		sprite.modulate.a = lerpf(BACK_ALPHA_NEAR, BACK_ALPHA_FAR, depth)
		sprite.z_index = -1700
	return sprite

func _flash(strength : float, fade : float) -> void:
	var tween : Tween = create_tween()
	tween.tween_property(flash, "modulate:a", strength, 0.03)
	tween.tween_property(flash, "modulate:a", 0.0, fade)

func strike_back() -> void:
	var depth : float = rng.randf()
	var sprite : Sprite2D = _bolt(depth, false)
	sprite.position = Vector2(rng.randf_range(left_x - 200.0, right_x + 200.0), WATER_Y - 6.0 - depth * 10.0)
	add_child(sprite)
	_flash(0.06 * (1.0 - depth * 0.5), 0.25)
	var tween : Tween = create_tween()
	var alpha : float = sprite.modulate.a
	tween.tween_property(sprite, "modulate:a", alpha * 0.4, 0.06)
	tween.tween_property(sprite, "modulate:a", alpha, 0.05)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(sprite.queue_free)

func strike_front(x : float) -> void:
	var mark : ColorRect = ColorRect.new()
	mark.color = Color(0.8, 0.9, 1.0, 0.9)
	mark.size = Vector2(HIT_RADIUS * 2.0, 2.0)
	mark.position = Vector2(x - HIT_RADIUS, WATER_Y + 2.0)
	mark.z_index = 260
	add_child(mark)
	var warn : Tween = create_tween()
	warn.set_loops(5)
	warn.tween_property(mark, "modulate:a", 0.15, WARNING_TIME / 10.0)
	warn.tween_property(mark, "modulate:a", 1.0, WARNING_TIME / 10.0)
	await get_tree().create_timer(WARNING_TIME).timeout
	if (!is_inside_tree()):
		return
	mark.queue_free()
	var sprite : Sprite2D = _bolt(0.0, true)
	sprite.position = Vector2(x, FRONT_BOTTOM_Y)
	add_child(sprite)
	_flash(0.55, 0.4)
	apply_damage(x)
	var tween : Tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.5, 0.05)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.05)
	tween.tween_interval(BOLT_TIME)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(sprite.queue_free)

func _hitbox_of(entity : Entity) -> HitboxComponent:
	for child : Node in entity.get_children():
		if (child is HitboxComponent):
			return child as HitboxComponent
	return null

func is_large(entity : Entity) -> bool:
	var stats : EntityStats = entity.entity_stats
	return stats.is_boss or stats.unit_class == Enums.UnitClass.HEAVY

func apply_damage(x : float) -> int:
	var context : BattleContext = BattleContext.of(self)
	var hits : int = 0
	if (context == null):
		return hits
	for entity : Entity in context.entities.duplicate():
		if (!is_instance_valid(entity) or !entity.enabled or entity.is_submerged()):
			continue
		if (absf(entity.get_center_pos().x - x) > HIT_RADIUS):
			continue
		var hitbox : HitboxComponent = _hitbox_of(entity)
		if (hitbox == null or hitbox.health_component == null):
			continue
		var damage : Damage = Damage.new()
		if (is_large(entity)):
			damage.damage = entity.entity_stats.health * LARGE_DAMAGE_RATIO
		else:
			damage.damage = hitbox.health_component.get_health() + 1.0
		damage.knockback = 0
		hitbox.handle_hit(damage, 0.0)
		hits += 1
	return hits
