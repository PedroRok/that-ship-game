class_name ScrewLabel
extends Label

@onready
var audio : AudioStreamPlayer = $"../AudioStreamPlayer"

@onready
var texture : TextureRect = $"../../TextureRect"

var total_screws : int = 0
var increment_cd : int = 120
var waiting_to_increment : int = 0

func change_screw(plus_amount : int) -> void:
	increment_cd = 120
	waiting_to_increment += 1
	text = str(total_screws) + "+" + str(waiting_to_increment)
	audio.pitch_scale = 1.
	pass

var pos_increment_cd : int = 30

func _physics_process(delta: float) -> void:
	if (waiting_to_increment != 0):
		if (increment_cd <= 0):
			if (pos_increment_cd <= 0):
				pos_increment_cd = 30 / waiting_to_increment
				total_screws += 1
				waiting_to_increment -= 1
				text = str(total_screws)
				audio.play()
				audio.pitch_scale += 0.1
				pivot_offset = size/2
				rotation_degrees = clamp( rotation_degrees - 3, -30, 30)
				scale = clamp(scale + Vector2(0.2, 0.2), Vector2(1., 1.), Vector2(2.,2.))
				material.set_shader_parameter("shadow_size", 0.)
				texture.material.set_shader_parameter("shadow_size", 0.)
				material.set_shader_parameter("base_gray", Color("#ffffff"))
				texture.material.set_shader_parameter("base_gray", Color("#ffffff"))
			pos_increment_cd -= 1
			pass
		increment_cd -= 1
	
	if rotation != 0 || material.get_shader_parameter("base_gray") != Color("#636363"):
		rotation = lerp(rotation, 0., delta * 4)
		scale = lerp(scale, Vector2(1., 1.), delta * 4)
		material.set_shader_parameter("shadow_size", lerp(material.get_shader_parameter("shadow_size"), 0.008, delta * 4))
		texture.material.set_shader_parameter("shadow_size", lerp(texture.material.get_shader_parameter("shadow_size"), 0.124, delta * 4))
		var color : Color = lerp(material.get_shader_parameter("base_gray"), Color("#636363"), delta * 4)
		material.set_shader_parameter("base_gray", color)
		texture.material.set_shader_parameter("base_gray", color)
		
	pass
