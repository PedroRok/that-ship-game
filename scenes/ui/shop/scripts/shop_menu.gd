class_name ShopMenu
extends MenuControl

@onready
var screw_value : BarValue = $NinePatchRect/VBoxContainer/Bottom/VBoxContainer/Stats/Screw

@onready 
var gear_value: BarValue = $NinePatchRect/VBoxContainer/Bottom/VBoxContainer/Stats/Gear

@onready 
var ships_slots: ShipsSlotUI = $NinePatchRect/VBoxContainer/Bottom/VBoxContainer/ShipsSlots


func _ready() -> void:
	screw_value.change_value(player_stats.start_screw)
	gear_value.change_value(player_stats.gear)
	ships_slots.player_stats = player_stats
	ships_slots.setup()

func _on_button_button_down() -> void:
	emit_signal("change_to_menu", "SELECT")
	pass # Replace with function body.
