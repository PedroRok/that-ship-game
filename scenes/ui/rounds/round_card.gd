@tool
class_name RoundCard
extends PanelContainer

@export_group("Button")
@export
var base_color : Color
@export
var active : bool = true
@export
var button_label : String
@onready
var button : Button = $Margin/VBox/Button

@export_group("Card")
@export
var title : String = "TITLE"
@export
var desc : String =  "A simple description"
@onready
var title_label : Label = $Margin/VBox/Title
@onready
var card_desc : RichTextLabel = $Margin/VBox/Desc

signal round_button_pressed

func _ready() -> void:
	button.modulate = base_color
	button.disabled = !active
	button.text = button_label
	title_label.text = title
	card_desc.text = desc
	
	modulate.v = 1
	var brightness : float = 1
	if (button.disabled):
		brightness = 0.8
		modulate.v = modulate.v * 0.85
	apply_color("base_gray", 0.49)
	apply_color("shadow_gray", 0.35)
	apply_color("darker_shadow_gray", 0.49)

func apply_color(parameter : String, brightness : float) -> void:
	var cl : Color = button.material.get_shader_parameter(parameter)
	cl.v = brightness
	cl.s = base_color.s
	cl.h = base_color.h
	button.material.set_shader_parameter(parameter, cl)


func _on_button_button_up() -> void:
	round_button_pressed.emit()
	pass # Replace with function body.
