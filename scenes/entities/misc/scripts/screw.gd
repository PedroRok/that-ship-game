class_name ScrewEntity
extends RigidBody2D

@onready
var sprite : Sprite2D = $Sprite2D
@export_range(1,20)
var catch_threshold : float = 10

func _ready() -> void:
	linear_velocity.y = randf_range(-200, -400)
	linear_velocity.x = randf_range(-200, 200)
	angular_velocity = randf_range(100, -100)
	

var time_to_change : int = 30
var is_glowing : bool = false

func _physics_process(delta: float) -> void:
	time_to_change -= 1
	if (time_to_change <= 0):
		time_to_change = 30
		glow(!is_glowing)
		is_glowing = !is_glowing
	
	print(get_global_mouse_position().distance_to(global_position))
	if (get_global_mouse_position().distance_to(global_position) < catch_threshold):
		print("aaaaa")
		queue_free()
		pass
	
	pass
	
func glow(active : bool) -> void:
	var shader : ShaderMaterial = sprite.material
	shader.set_shader_parameter("enable", active)
