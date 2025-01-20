class_name GameUI
extends Control

@export
var base : Base
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
	ships_slots.connect("spawn_entity", Callable(self, "spawn_entity"))
	screw_label.connect("value_change", Callable(ships_slots, "on_value_change"))
	screw_label.change_value(Global.player_stats.start_screw)
	gear_label.change_value(Global.player_stats.gear)

func spawn_entity(entity_name : EntityStats) -> void:
	if (base.start_build_ship(entity_name)):
		screw_label.change_value(-entity_name.price)


func _on_temporary_button_button_up() -> void:
	Global.change_to_scene.emit(Global.Menu.SHOP)
	pass # Replace with function body.
	
func collect_gear(value_collected : int) -> void:
	gear_label.change_value_animated(value_collected)
	game_round.gears_collected_in_round += value_collected
	Global.player_stats.gear += value_collected
