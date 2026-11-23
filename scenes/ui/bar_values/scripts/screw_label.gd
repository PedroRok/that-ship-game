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

var rest_color : Color = Color("#636363")
var icon_rest_color : Color = Color("#636363")
var icon_shadow_rest : float = 0.1
var text_shadow_rest : float = 0.0078

func apply_charge_style(unloaded : Color, loaded : Color) -> void:
	icon_rest_color = unloaded
	var shader : ShaderMaterial = texture.material as ShaderMaterial
	shader.set_shader_parameter("base_gray", unloaded)
	shader.set_shader_parameter("shadow_gray", unloaded)
	shader.set_shader_parameter("darker_shadow_gray", unloaded)
	shader.set_shader_parameter("light_color", unloaded)
	shader.set_shader_parameter("progress_bar_color", Color(loaded.r, loaded.g, loaded.b, 1.0))
	shader.set_shader_parameter("progress_matched_only", true)

func apply_palette(rest : Color, shadow : Color, light : Color, icon_shadow : float = 0.1, text_shadow : float = 0.0078) -> void:
	rest_color = rest
	icon_rest_color = rest
	icon_shadow_rest = icon_shadow
	text_shadow_rest = text_shadow
	texture.material.set_shader_parameter("shadow_size", icon_shadow)
	value_label.material.set_shader_parameter("shadow_size", text_shadow)
	for item : CanvasItem in [texture, value_label, name_label]:
		var shader : ShaderMaterial = item.material as ShaderMaterial
		shader.set_shader_parameter("base_gray", rest)
		shader.set_shader_parameter("shadow_gray", shadow)
		shader.set_shader_parameter("darker_shadow_gray", rest)
		shader.set_shader_parameter("light_color", light)

signal value_change(new_val : int)

func _ready() -> void:
	total_value = start_value
	texture.texture = icon_texture
	name_label.text = name_string
	value_label.text = str(start_value)
	texture.material.set_shader_parameter("reference_texture", icon_texture)
	pass
	
func change_value(plus_amout: int) -> void:
	total_value = total_value + plus_amout
	value_label.text = str(total_value)
	value_label.pivot_offset = value_label.size/2
	value_label.rotation_degrees -= 3
	value_change.emit(total_value)
	
func change_value_animated(plus_amount : int) -> void:
	increment_cd = 120
	waiting_to_increment += plus_amount
	value_label.text = str(total_value) + "+" + str(waiting_to_increment)
	audio.pitch_scale = 1.
	texture.pivot_offset = texture.size / 2
	texture.scale = Vector2(1.35, 1.35)
	texture.material.set_shader_parameter("base_gray", Color("#ffffff"))
	texture.material.set_shader_parameter("shadow_size", 0.)
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
	
	if value_label.rotation != 0 || value_label.material.get_shader_parameter("base_gray") != rest_color:
		value_label.rotation = lerp(value_label.rotation, 0., delta * 4)
		value_label.scale = lerp(value_label.scale, Vector2(1., 1.), delta * 4)
		value_label.material.set_shader_parameter("shadow_size", lerp(value_label.material.get_shader_parameter("shadow_size"), text_shadow_rest, delta * 4))
		texture.material.set_shader_parameter("shadow_size", lerp(texture.material.get_shader_parameter("shadow_size"), icon_shadow_rest, delta * 4))
		texture.scale = lerp(texture.scale, Vector2(1., 1.), delta * 6)
		var color : Color = lerp(value_label.material.get_shader_parameter("base_gray"), rest_color, delta * 4)
		value_label.material.set_shader_parameter("base_gray", color)
		texture.material.set_shader_parameter("base_gray", lerp(texture.material.get_shader_parameter("base_gray"), icon_rest_color, delta * 4))
		
	pass
