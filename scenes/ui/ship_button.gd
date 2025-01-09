@tool
class_name ShipButton
extends PanelContainer


@export
var ship_sprite : Texture2D

@export
var ship_name : String

@export
var price_value : int = 0

@onready
var button : Button = $InnerMargin/Button
@onready
var price_label : Label = $InnerMargin/Price

signal spawn_ship(ship_name : String, price : int)

var enabled : bool = true

func _ready() -> void:
	var shader_material : ShaderMaterial = button.material as ShaderMaterial
	
	if !ship_name && !ship_sprite:
		button.disabled = true
		shader_material.set_shader_parameter("enabled", false)
		enabled = false
		price_label.hide()
		return
	else:
		button.disabled = false
		shader_material.set_shader_parameter("enabled", true)
		enabled = true
		price_label.show()
	price_label.text = str(price_value)
	shader_material.set_shader_parameter("reference_texture", ship_sprite)
	button.icon = ship_sprite

func on_value_change(new_val : int) -> void:
	if (!enabled): return
	if (new_val >= price_value):
		if (button.disabled):
			price_label.custom_minimum_size.y = 32
		button.disabled = false
		
	else:
		button.disabled = true
		price_label.custom_minimum_size.y = 26
		

func _on_button_down() -> void:
	spawn_ship.emit(ship_name, price_value)
	price_label.custom_minimum_size.y = 27
	pass


func _on_button_button_up() -> void:
	price_label.custom_minimum_size.y = 32
	pass # Replace with function body.
