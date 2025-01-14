@tool
class_name BarValue
extends GridContainer

@export
var icon_texture : Texture2D
@export
var name_string : String
@export
var start_value : int = 0

@onready
var audio : AudioStreamPlayer = $VBoxContainer/AudioStreamPlayer
@onready
var texture : TextureRect = $Icon
@onready
var value_label : Label = $VBoxContainer/ValueLabel
@onready
var name_label : Label = $VBoxContainer/NameLabel

var total_value : int
var increment_cd : int = 120
var waiting_to_increment : int = 0

var progress_bar : float = 0

signal value_change(new_val : int)

func _ready() -> void:
	total_value = start_value
	texture.texture = icon_texture
	name_label.text = name_string
	value_label.text = str(start_value)
	texture.material.set_shader_parameter("reference_texture", icon_texture)
	print(start_value)
	pass
	
func change_value(plus_amout: int) -> void:
	total_value = total_value + plus_amout
	value_label.text = str(total_value)
	value_label.pivot_offset = value_label.size/2
	value_label.rotation_degrees -= 3
	value_change.emit(total_value)
	
func change_value_animated(plus_amount : int) -> void:
	increment_cd = 120
	waiting_to_increment += 1
	value_label.text = str(total_value) + "+" + str(waiting_to_increment)
	audio.pitch_scale = 1.
	
	pass

var pos_increment_cd : int = 30

func _physics_process(delta: float) -> void:
	if (Engine.is_editor_hint()): return
	texture.material.set_shader_parameter("progress_bar", progress_bar)
	if (waiting_to_increment != 0):
		if (increment_cd <= 0):
			if (pos_increment_cd <= 0):
				pos_increment_cd = 30 / waiting_to_increment
				total_value += 1
				waiting_to_increment -= 1
				value_label.text = str(total_value)
				audio.play()
				audio.pitch_scale += 0.1
				value_label.pivot_offset = value_label.size/2
				value_label.rotation_degrees = clamp(value_label.rotation_degrees - 3, -30, 30)
				value_label.scale = clamp(value_label.scale + Vector2(0.2, 0.2), Vector2(1., 1.), Vector2(2.,2.))
				value_label.material.set_shader_parameter("shadow_size", 0.)
				texture.material.set_shader_parameter("shadow_size", 0.)
				value_label.material.set_shader_parameter("base_gray", Color("#ffffff"))
				texture.material.set_shader_parameter("base_gray", Color("#ffffff"))
			pos_increment_cd -= 1
			value_change.emit(total_value)
			pass
		increment_cd -= 1
	
	if value_label.rotation != 0 || value_label.material.get_shader_parameter("base_gray") != Color("#636363"):
		value_label.rotation = lerp(value_label.rotation, 0., delta * 4)
		value_label.scale = lerp(value_label.scale, Vector2(1., 1.), delta * 4)
		value_label.material.set_shader_parameter("shadow_size", lerp(value_label.material.get_shader_parameter("shadow_size"), 0.0078, delta * 4))
		texture.material.set_shader_parameter("shadow_size", lerp(texture.material.get_shader_parameter("shadow_size"), 0.1, delta * 4))
		var color : Color = lerp(value_label.material.get_shader_parameter("base_gray"), Color("#636363"), delta * 4)
		value_label.material.set_shader_parameter("base_gray", color)
		texture.material.set_shader_parameter("base_gray", color)
		
	pass
