@tool
class_name RoundCardStats
extends Resource

@export_group("Button")
@export
var base_color : Color
@export
var active : bool = true
@export
var button_label : String


func apply_card(round_card : RoundCard) -> void:
	round_card.button.text = button_label
	round_card.button.modulate = base_color
	round_card.button.disabled = !active
	round_card.modulate.v = 1
	if (round_card.button.disabled):
		round_card.modulate.v = round_card.modulate.v * 0.85
	apply_color("base_gray", 0.49, round_card.button)
	apply_color("shadow_gray", 0.35, round_card.button)
	apply_color("darker_shadow_gray", 0.49, round_card.button)

func apply_color(parameter : String, brightness : float, button : Button) -> void:
	var cl : Color = button.material.get_shader_parameter(parameter)
	cl.v = brightness
	cl.s = base_color.s
	cl.h = base_color.h
	button.material.set_shader_parameter(parameter, cl)
