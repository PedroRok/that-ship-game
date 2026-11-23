class_name SkyParallax
extends ColorRect

const PADDING : float = 128.0
const BASE_WIDTH : float = 1281.0

func _ready() -> void:
	process_priority = 100
	size.x = BASE_WIDTH + PADDING * 2.0
	var shader_material : ShaderMaterial = material as ShaderMaterial
	if (shader_material):
		shader_material.set_shader_parameter("rect_size", Vector2(size.x, size.y))

func _process(_delta : float) -> void:
	var cam : Camera2D = get_viewport().get_camera_2d()
	if (cam == null):
		return
	var centre_x : float = cam.get_screen_center_position().x
	position.x = centre_x - size.x * 0.5
	var shader_material : ShaderMaterial = material as ShaderMaterial
	if (shader_material):
		shader_material.set_shader_parameter("world_x", centre_x)
