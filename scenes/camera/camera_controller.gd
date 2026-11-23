class_name GameCam
extends Camera2D

@export
var zoom_speed : float = 0.1
@export
var move_speed : float= 10
@export
var pan_speed : float = 600.0
@export
var edge_margin : float = 24.0

var actual_zoom : float = 1
@export
var min_zoom : float = 1.0
@export
var max_zoom : float = 2.0

var actual_h_pos : float = 0

func _ready() -> void:
	actual_zoom = zoom.x
	actual_h_pos = global_position.x

func _pan_input() -> float:
	var dir : float = Input.get_axis("ui_left", "ui_right")
	if (dir != 0.0):
		return dir
	if (!DisplayServer.window_is_focused()):
		return 0.0
	var viewport : Viewport = get_viewport()
	var mouse : Vector2 = viewport.get_mouse_position()
	var size : Vector2 = viewport.get_visible_rect().size
	if (mouse.y < 0.0 or mouse.y > size.y or mouse.x < 0.0 or mouse.x > size.x):
		return 0.0
	if (mouse.x <= edge_margin):
		return -1.0
	if (mouse.x >= size.x - edge_margin):
		return 1.0
	return 0.0

func _process(delta: float) -> void:
	var pan : float = _pan_input()
	if (pan != 0.0):
		actual_h_pos += pan * pan_speed * delta / actual_zoom
	if (actual_zoom != zoom.x):
		actual_zoom = clamp(actual_zoom, min_zoom, max_zoom)
		zoom = lerp(zoom, Vector2(actual_zoom, actual_zoom), .2)
		Global.camera_zoom = actual_zoom


	if (actual_h_pos != global_position.x):
		var viewport : Viewport = get_viewport()
		var half : float = (viewport.get_visible_rect().size.x / 2.0) / actual_zoom
		var min_x : float = limit_left + half
		var max_x : float = maxf(min_x, limit_right - half)
		actual_h_pos = clamp(actual_h_pos, min_x, max_x)
		global_position.x = lerp(global_position.x, actual_h_pos, .2)
		Global.center_camera_pos = global_position


func _input(event: InputEvent) -> void:
	if (event.is_action_released("game_mouse_zoom_in")):
		actual_zoom += zoom_speed
		if (actual_zoom < max_zoom || actual_zoom > min_zoom):
			move_camera_to_with_zoom()
		pass
	if (event.is_action_released("game_mouse_zoom_out")):
		actual_zoom -= zoom_speed
		pass
	

func move_camera_to_with_zoom() -> void:
	var viewport : Viewport = get_viewport()
	var viewport_center : Vector2 = viewport.size / 2.0
	var direction : Vector2 = viewport.get_mouse_position() - viewport_center
	actual_h_pos += round((direction.x / viewport_center.x)) * move_speed * actual_zoom
