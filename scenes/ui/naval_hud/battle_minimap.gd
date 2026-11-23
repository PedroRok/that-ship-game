class_name BattleMinimap
extends Control

const BASE_ALLY := Color("#a4d7d4")
const BASE_ENEMY := Color("#eb6862")
const TRACK := Color("#151f25")
const EDGE := Color("#596a73")
const WINDOW := Color("#e6b35d")
const PADDING : float = 8.0

var round_scene : GameRound

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta : float) -> void:
	queue_redraw()

func _to_strip(world_x : float) -> float:
	var left : float = round_scene.ally_base.global_position.x
	var width : float = maxf(round_scene.enemy_base.global_position.x - left, 1.0)
	return PADDING + clampf((world_x - left) / width, 0.0, 1.0) * (size.x - PADDING * 2.0)

func _draw() -> void:
	if (round_scene == null):
		return
	draw_rect(Rect2(Vector2.ZERO, size), TRACK)
	draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, 1.0)
	var mid : float = size.y * 0.5
	draw_line(Vector2(PADDING, mid), Vector2(size.x - PADDING, mid), EDGE, 1.0)
	var context : BattleContext = BattleContext.of(round_scene)
	if (context):
		for unit : Entity in context.entities:
			if (!is_instance_valid(unit)):
				continue
			var ally : bool = unit.team_stats.team_id == 1
			var dot : float = 3.0 if unit.entity_stats.is_boss else 2.0
			var x : float = _to_strip(unit.global_position.x)
			draw_rect(Rect2(x - dot * 0.5, mid - dot * 0.5, dot, dot), BASE_ALLY if ally else BASE_ENEMY)
	draw_rect(Rect2(_to_strip(round_scene.ally_base.global_position.x) - 3.0, 2.0, 6.0, size.y - 4.0), BASE_ALLY)
	draw_rect(Rect2(_to_strip(round_scene.enemy_base.global_position.x) - 3.0, 2.0, 6.0, size.y - 4.0), BASE_ENEMY)
	var cam : Camera2D = get_viewport().get_camera_2d()
	if (cam):
		var half : float = get_viewport_rect().size.x * 0.5 / cam.zoom.x
		var left : float = _to_strip(cam.global_position.x - half)
		var right : float = _to_strip(cam.global_position.x + half)
		draw_rect(Rect2(left, 1.0, maxf(right - left, 2.0), size.y - 2.0), WINDOW, false, 1.0)
