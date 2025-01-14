class_name ShopMenu
extends Control

@onready
var screw_value : BarValue = $NinePatchRect/VBoxContainer/Bottom/VBoxContainer/Stats/Screw

@onready 
var gear_value: BarValue = $NinePatchRect/VBoxContainer/Bottom/VBoxContainer/Stats/Gear

func _ready() -> void:
	screw_value.change_value(Global.player_stats.start_screw)
	gear_value.change_value(Global.player_stats.gear)
	
func _on_button_button_down() -> void:
	Global.change_to_scene.emit(Global.Menu.SELECT)
	pass # Replace with function body.
