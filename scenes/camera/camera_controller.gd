class_name GameCam
extends Camera2D

@export
var zoom_speed = 0.1
@export
var move_speed = 10

var actual_zoom : float = 1
@export
var min_zoom : float = 1.0
@export
var max_zoom : float = 2.0

var actual_h_pos : float = 0

func _ready() -> void:
	actual_zoom = zoom.x

func _process(_delta: float):
	if (actual_zoom != zoom.x):
		actual_zoom = clamp(actual_zoom, min_zoom, max_zoom)
		zoom = lerp(zoom, Vector2(actual_zoom, actual_zoom), .2)
		Global.camera_zoom = actual_zoom


	if (actual_h_pos != global_position.x):
		var viewport = get_viewport()
		actual_h_pos = clamp(actual_h_pos, (viewport.size.x / 2) / actual_zoom, limit_right - (viewport.size.x / 2) / actual_zoom)
		global_position.x = lerp(global_position.x, actual_h_pos, .2)
		Global.center_camera_pos = global_position


func _input(event: InputEvent) -> void:
	if (event.is_action_released("game_mouse_zoom_in")):
		actual_zoom += zoom_speed
		if (actual_zoom < max_zoom || actual_zoom > min_zoom):
			move_camera_to_with_zoom()
			#actual_h_pos += clamp(event.mouse_get_position().x, -50, 50)
		pass
	if (event.is_action_released("game_mouse_zoom_out")):
		actual_zoom -= zoom_speed
		pass
	if (event.is_action("ui_left")):
		actual_h_pos -= move_speed
	if (event.is_action("ui_right")):
		actual_h_pos += move_speed
	

func move_camera_to_with_zoom():
	var viewport = get_viewport()
	var viewport_center = viewport.size / 2.0
	var direction = viewport.get_mouse_position() - viewport_center
	actual_h_pos += round((direction.x / viewport_center.x)) * move_speed * actual_zoom
	#prints(viewport.get_mouse_position() - viewport_center)
