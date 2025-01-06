class_name GameUI
extends Control

@export
var ship_manager : ShipManager

@onready
var buttons_container : HBoxContainer  = $MarginContainer/ButtonsContainer

func _ready() -> void:
	for button in buttons_container.get_children():
		button.connect("spawn_ship", Callable(self, "spawn_ship"))


func spawn_ship(ship_name : String) -> void:
	ship_manager.select_ship(ship_name)
