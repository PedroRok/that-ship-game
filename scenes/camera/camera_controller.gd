extends Camera2D

@export
var zoom_speed = 0.1
@export
var move_speed = 10

var actual_zoom : float = 1
var min_zoom : float = 1.0
var max_zoom : float = 2.0

var actual_h_pos : float = 0

func _process(delta: float):
	if (actual_zoom != zoom.x):
		actual_zoom = clamp(actual_zoom, min_zoom, max_zoom)
		zoom = lerp(zoom, Vector2(actual_zoom, actual_zoom), .2)
	if (actual_h_pos != offset.x):
		actual_h_pos = clamp(actual_h_pos, -(320 * (actual_zoom - 1)), 9999999999)
		offset.x = lerp(offset.x, actual_h_pos, .2)


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
