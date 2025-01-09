class_name GameUI
extends Control

@export
var ship_manager : ShipManager
@export
var item_manager : ItemManager

@onready
var buttons_container : HBoxContainer  = $NinePatchRect/MarginContainer/VBoxContainer/MarginContainer/ButtonsContainer

@export
var screw_label : BarValue
@export
var gear_label : BarValue

func _ready() -> void:
	for button in buttons_container.get_children():
		if button.enabled:
			button.connect("spawn_ship", Callable(self, "spawn_ship"))
			screw_label.connect("value_change", Callable(button, "on_value_change"))

func spawn_ship(ship_name : String, price : int) -> void:
	ship_manager.select_ship(ship_name)
	screw_label.change_value(-price)
