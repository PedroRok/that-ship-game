class_name GearEntity
extends RigidBody2D

@onready
var sprite : Sprite2D = $Sprite2D
@export_range(1,20)
var catch_threshold : float = 10

signal pickup_gear(plus : int)

var target_control : Control
var _flying : bool = false

func _start_flight() -> void:
	_flying = true
	desapier = true
	gravity_scale = 0
	linear_velocity = Vector2.ZERO
	sleeping = true
	sprite.hide()
	var from_screen : Vector2 = get_viewport().get_canvas_transform() * global_position
	var zoom : float = get_viewport().get_canvas_transform().get_scale().x
	GearFlyer.launch(self, sprite.texture, from_screen, target_control, zoom * scale.x, _arrived)

func _arrived() -> void:
	pickup_gear.emit(1)
	queue_free()

func explode() -> void:
	linear_velocity.y = randf_range(-200, -400)
	linear_velocity.x = randf_range(-200, 200)
	angular_velocity = randf_range(100, -100)
	

var time_to_change : int = 30
var is_glowing : bool = false

var time_to_desapier : int = 60
var desapier : bool = false

func _physics_process(_delta: float) -> void:
	time_to_change -= 1
	if (time_to_change <= 0):
		time_to_change = 30
		glow(!is_glowing)
		is_glowing = !is_glowing
	
	if (get_global_mouse_position().distance_to(global_position) < catch_threshold && !desapier):
		if (is_instance_valid(target_control)):
			_start_flight()
			return
		desapier = true
		pickup_gear.emit(1)
		if randi_range(0,1) == 0:
			angular_velocity = -80
		else:
			angular_velocity = 80
		
		gravity_scale = 0
		linear_velocity = Vector2.ZERO
		
		pass
	
	if (desapier):
		if (time_to_desapier < 0):
			queue_free()
		scale = scale * 1.5
		var shader : ShaderMaterial = sprite.material
		shader.set_shader_parameter("opacity", (100 / 60) * time_to_desapier)
		time_to_desapier -= 1
		
		pass
	
	pass
	
func glow(active : bool) -> void:
	var shader : ShaderMaterial = sprite.material
	shader.set_shader_parameter("enable", active)
