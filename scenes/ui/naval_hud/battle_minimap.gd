class_name BattleMinimap
extends Control

enum Shape { SHIP, PLANE, SUB }

const SIZE : Vector2 = Vector2(360, 22)
const TOP : float = 50.0
const HUD_TOP : float = 44.0
const HUD_BOTTOM : float = 200.0
const WORLD_HEIGHT : float = 720.0
const WATER_Y : float = 368.0
const SIDE_PADDING : float = 14.0
const EDGE_PADDING : float = 2.0
const FACE : Color = Color("#151f25")
const EDGE : Color = Color("#596a73")
const INK : Color = Color("#090f15")
const ALLY : Color = Color("#78dddd")
const ENEMY : Color = Color("#eb6862")
const BOSS : Color = Color("#ecc078")
const ESCORT : Color = Color("#ffffff")
const CAMERA : Color = Color("#eaf3f5")

var round_scene : GameRound
var _dragging : bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta : float) -> void:
	queue_redraw()

func _gui_input(event : InputEvent) -> void:
	if (round_scene == null or round_scene.game_ended):
		_dragging = false
		return
	var button : InputEventMouseButton = event as InputEventMouseButton
	if (button != null):
		if (button.button_index == MOUSE_BUTTON_LEFT):
			_dragging = button.pressed
			if (button.pressed):
				move_camera_to(button.position)
		elif (button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP):
			_zoom(1.0)
		elif (button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_zoom(-1.0)
		accept_event()
	var motion : InputEventMouseMotion = event as InputEventMouseMotion
	if (motion != null and _dragging):
		move_camera_to(motion.position)
		accept_event()

func move_camera_to(point : Vector2) -> void:
	var camera : GameCam = round_scene.camera as GameCam
	if (camera == null):
		return
	var area : Rect2 = _map()
	var ratio : Vector2 = ((point - area.position) / area.size).clamp(Vector2.ZERO, Vector2.ONE)
	var left : float = _left()
	var world : Vector2 = Vector2(left + ratio.x * _width(), ratio.y * WORLD_HEIGHT)
	var half : float = get_viewport_rect().size.x * 0.5 / camera.actual_zoom
	var low : float = camera.limit_left + half
	camera.actual_h_pos = clampf(world.x, low, maxf(low, camera.limit_right - half))
	camera.actual_v_pos = world.y

func _zoom(direction : float) -> void:
	var camera : GameCam = round_scene.camera as GameCam
	if (camera != null):
		camera.actual_zoom = clampf(camera.actual_zoom + direction * camera.zoom_speed, camera.min_zoom, camera.max_zoom)

func _left() -> float:
	return round_scene.ally_base.global_position.x

func _width() -> float:
	return maxf(round_scene.enemy_base.global_position.x - _left(), 1.0)

func _map() -> Rect2:
	var padding : Vector2 = Vector2(SIDE_PADDING, EDGE_PADDING)
	return Rect2(padding, size - padding * 2.0)

func _point(world : Vector2) -> Vector2:
	var area : Rect2 = _map()
	var ratio : Vector2 = Vector2((world.x - _left()) / _width(), world.y / WORLD_HEIGHT).clamp(Vector2.ZERO, Vector2.ONE)
	return (area.position + ratio * area.size).floor()

func _water_row() -> float:
	return _point(Vector2(_left(), WATER_Y)).y + 2.0

func _parts(parts : Array[Rect2], at : Vector2, color : Color) -> void:
	for part : Rect2 in parts:
		draw_rect(Rect2(at + part.position - Vector2.ONE, part.size + Vector2.ONE * 2.0), INK)
	for part : Rect2 in parts:
		draw_rect(Rect2(at + part.position, part.size), color)

func _unit(unit : Entity) -> void:
	var stats : EntityStats = unit.entity_stats
	var ally : bool = unit.team_stats.team_id == 1
	var at : Vector2 = _point(unit.global_position)
	if (ally and stats.name == "escort"):
		_parts([Rect2(-3, -3, 7, 1), Rect2(-3, 3, 7, 1), Rect2(-3, -2, 1, 5), Rect2(3, -2, 1, 5),
				Rect2(-1, -1, 3, 3)] as Array[Rect2], at, ESCORT)
		return
	var color : Color = BOSS if stats.is_boss else (ALLY if ally else ENEMY)
	var boat : BoatStats = stats as BoatStats
	var shape : Shape = Shape.SHIP
	if (stats.unit_class == Enums.UnitClass.AIR):
		shape = Shape.PLANE
	elif (boat != null and boat.can_submerge):
		shape = Shape.SUB
	match shape:
		Shape.PLANE:
			_parts([Rect2(-2, 0, 5, 1), Rect2(0, -1, 1, 3)] as Array[Rect2], at, color)
		Shape.SUB:
			_parts([Rect2(-2, 0, 5, 2)] as Array[Rect2], at, color)
		_:
			_parts([Rect2(-2, -1, 5, 2), Rect2(0, -2, 1, 1)] as Array[Rect2], at, color)

func _base(left : bool) -> void:
	var at : Vector2 = Vector2(7.0 if left else size.x - 8.0, _water_row())
	var side : float = 1.0 if left else -1.0
	_parts([Rect2(-4, -3, 9, 5), Rect2(-4 if left else 0, -7, 5, 4), Rect2(-3 * side, -9, 1, 2),
			Rect2(1 if left else -5, -5, 4, 1)] as Array[Rect2], at, ALLY if left else ENEMY)

func view_rect() -> Rect2:
	var camera : Camera2D = get_viewport().get_camera_2d()
	if (camera == null):
		return Rect2()
	var screen : Vector2 = get_viewport_rect().size
	var centre : Vector2 = camera.get_screen_center_position()
	var from : Vector2 = _point(centre + (Vector2(0.0, HUD_TOP) - screen * 0.5) / camera.zoom)
	var to : Vector2 = _point(centre + (Vector2(screen.x, screen.y - HUD_BOTTOM) - screen * 0.5) / camera.zoom)
	return Rect2(from, (to - from).max(Vector2(2.0, 2.0)))

func _draw() -> void:
	if (round_scene == null):
		return
	draw_rect(Rect2(Vector2.ZERO, size), FACE)
	draw_rect(Rect2(_map().position.x, _water_row(), _map().size.x, 1.0), EDGE)
	draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, 1.0)
	_base(true)
	_base(false)
	var view : Rect2 = view_rect()
	if (view.has_area()):
		draw_rect(view, Color(CAMERA, 0.10))
		draw_rect(view, Color(CAMERA, 0.9), false, 1.0)
	var context : BattleContext = BattleContext.of(round_scene)
	if (context == null):
		return
	var special : Array[Entity] = []
	for unit : Entity in context.entities:
		if (!is_instance_valid(unit) or unit.entity_stats == null or unit.team_stats == null):
			continue
		if (unit.entity_stats.is_boss or unit.entity_stats.name == "escort"):
			special.append(unit)
		else:
			_unit(unit)
	for unit : Entity in special:
		_unit(unit)
