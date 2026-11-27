class_name DebugOverlay
extends Node2D

const TOGGLE_KEY : Key = KEY_F3
const RANGE_COLOR : Color = Color(1.0, 0.85, 0.2, 0.45)
const HITBOX_COLOR : Color = Color(1.0, 0.25, 0.25, 0.9)
const WATER_COLOR : Color = Color(0.2, 0.9, 1.0, 0.9)
const ALLY_LINE_COLOR : Color = Color(0.4, 1.0, 0.4, 0.8)
const ENEMY_LINE_COLOR : Color = Color(1.0, 0.45, 0.9, 0.8)
const DASH : float = 6.0

func _ready() -> void:
	z_index = 4000
	visible = false
	set_process(false)

func _unhandled_key_input(event : InputEvent) -> void:
	var key : InputEventKey = event as InputEventKey
	if (!OS.is_debug_build() or !key or !key.pressed or key.echo or key.keycode != TOGGLE_KEY):
		return
	visible = !visible
	set_process(visible)
	queue_redraw()
	get_viewport().set_input_as_handled()

func _process(_delta : float) -> void:
	queue_redraw()

func _draw() -> void:
	var context : BattleContext = BattleContext.of(self)
	if (!context):
		return
	for entity : Entity in context.entities:
		if (!is_instance_valid(entity) or entity.destroyed):
			continue
		draw_set_transform_matrix(Transform2D.IDENTITY)
		_draw_ranges_and_targets(entity)
		_draw_shape(entity.get_node_or_null("HitboxComponent/CollisionShape2D") as CollisionShape2D, HITBOX_COLOR)
		var hitbox : Node = entity.get_node_or_null("HitboxComponent")
		if (hitbox and !entity.has_node("HitboxComponent/CollisionShape2D") and hitbox.get_child_count() > 0):
			_draw_shape(hitbox.get_child(0) as CollisionShape2D, HITBOX_COLOR)
		_draw_shape(entity.get_node_or_null("WaterCollisionComponent") as CollisionShape2D, WATER_COLOR)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_ranges_and_targets(entity : Entity) -> void:
	var line_color : Color = ALLY_LINE_COLOR if entity.team_stats.team_id == 1 else ENEMY_LINE_COLOR
	var ranges : Array[float] = []
	var targets : Array[Node2D] = []
	for gun : Gun in entity.get_guns():
		if (gun.disabled):
			continue
		var reach : float = gun.effective_range()
		if (entity.uses_box_radar()):
			var size : Vector2 = RadarComponent.BOMB_RADAR_SIZE
			draw_rect(Rect2(to_local(entity.global_position) - size * 0.5, size), RANGE_COLOR, false, 1.0)
		elif (!ranges.has(reach)):
			ranges.append(reach)
			draw_arc(to_local(gun.global_position), reach, 0.0, TAU, 64, RANGE_COLOR, 1.0)
		if (is_instance_valid(gun.enemy) and !targets.has(gun.enemy)):
			targets.append(gun.enemy)
	for target : Node2D in targets:
		var point : Vector2 = (target as Base).get_center_pos() if target is Base else (target as Entity).get_center_pos()
		draw_dashed_line(to_local(entity.get_center_pos()), to_local(point), line_color, 1.0, DASH)

func _draw_shape(node : CollisionShape2D, color : Color) -> void:
	if (!node or !node.shape):
		return
	draw_set_transform_matrix(global_transform.affine_inverse() * node.global_transform)
	node.shape.draw(get_canvas_item(), Color(color, 0.18))
	var rect : RectangleShape2D = node.shape as RectangleShape2D
	if (rect):
		draw_rect(Rect2(-rect.size * 0.5, rect.size), color, false, 1.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
