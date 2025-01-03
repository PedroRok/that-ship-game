@tool
extends PanelContainer


@export
var ship_sprite : Texture2D

@export
var ship_name : String

@onready
var button : Button = $Button

func _ready() -> void:
	var shader_material = button.material as ShaderMaterial
	shader_material.set_shader_parameter("reference_texture", ship_sprite)
	button.icon = ship_sprite


func _on_button_down() -> void:
	print("spawning")
	EventBus.ship_spawned(ship_name)
	pass # Replace with function body.
