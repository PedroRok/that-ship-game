@tool
class_name ShipButton
extends PanelContainer


@export
var entity_stats : EntityStats

@onready
var button : Button = $InnerMargin/Button
@onready
var price_label : Label = $InnerMargin/Price

signal spawn_entity(ship_stats : EntityStats)

var enabled : bool = true

func _ready() -> void:
	if (Engine.is_editor_hint()):
		setup()
	
func setup() -> void:
	var shader_material : ShaderMaterial = button.material as ShaderMaterial
	
	if !entity_stats:
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
	price_label.text = str(entity_stats.price)
	shader_material.set_shader_parameter("reference_texture", entity_stats.sprite)
	button.icon = entity_stats.sprite
	
	
func on_value_change(new_val : int) -> void:
	if (!entity_stats): return
	if (new_val >= entity_stats.price):
		if (button.disabled):
			price_label.custom_minimum_size.y = 32
		button.disabled = false
		
	else:
		button.disabled = true
		price_label.custom_minimum_size.y = 26
		

func _on_button_down() -> void:
	spawn_entity.emit(entity_stats)
	price_label.custom_minimum_size.y = 27
	pass


func _on_button_button_up() -> void:
	price_label.custom_minimum_size.y = 32
	pass # Replace with function body.
