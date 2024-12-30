extends Button


@export
var ship_sprite : Texture2D

func _ready() -> void:
	material.set_shader_parameter("reference_texture", ship_sprite)
	icon = ship_sprite


func _on_button_down() -> void:
	print("spawning")
	EventBus.ship_spawned()
	pass # Replace with function body.
