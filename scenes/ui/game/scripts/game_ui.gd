class_name GameUI
extends Control

@export
var ship_manager : ShipManager
@export
var item_manager : ItemManager
@export
var game_round : GameRound

@onready
var ships_slots : ShipsSlotUI = $NinePatchRect/MarginContainer/VBoxContainer/ShipsSlots

@export
var screw_label : BarValue
@export
var gear_label : BarValue

func _ready() -> void:
	ships_slots.connect("spawn_ship", Callable(self, "spawn_ship"))
	screw_label.connect("value_change", Callable(ships_slots, "on_value_change"))

func spawn_ship(ship_name : String, price : int) -> void:
	ship_manager.select_ship(ship_name)
	screw_label.change_value(-price)


func _on_temporary_button_button_up() -> void:
	Global.change_to_scene.emit(Global.Menu.SHOP)
	pass # Replace with function body.
