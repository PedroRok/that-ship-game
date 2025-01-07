@tool
class_name ShipButton
extends PanelContainer


@export
var ship_sprite : Texture2D

@export
var ship_name : String

@onready
var button : Button = $Button

signal spawn_ship(ship_name : String)

var enabled : bool = true

func _ready() -> void:
	var shader_material : ShaderMaterial = button.material as ShaderMaterial
	
	if !ship_name && !ship_sprite:
		button.disabled = true
		shader_material.set_shader_parameter("enabled", false)
		enabled = false
		return
	else:
		button.disabled = false
		shader_material.set_shader_parameter("enabled", true)
		enabled = true
	shader_material.set_shader_parameter("reference_texture", ship_sprite)
	button.icon = ship_sprite


func _on_button_down() -> void:
	spawn_ship.emit(ship_name)
	pass
