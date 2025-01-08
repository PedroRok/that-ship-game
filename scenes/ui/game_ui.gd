class_name GameUI
extends Control

@export
var ship_manager : ShipManager

@onready
var buttons_container : HBoxContainer  = $NinePatchRect/MarginContainer/VBoxContainer/MarginContainer/ButtonsContainer

func _ready() -> void:
	for button in buttons_container.get_children():
		if button.enabled:
			button.connect("spawn_ship", Callable(self, "spawn_ship"))


func spawn_ship(ship_name : String) -> void:
	ship_manager.select_ship(ship_name)

@onready
var screw_label : Label  = $NinePatchRect/MarginContainer/VBoxContainer/Stats/Panel/VBoxContainer/ValueLabel

var total_screws : int = 0

func change_screw(plus_amount : int) -> void:
	total_screws += plus_amount 
	screw_label.text = str(total_screws)
	pass
