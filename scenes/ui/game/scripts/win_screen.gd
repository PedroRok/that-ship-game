extends Control

var gears_winned_in_round : int = 0
var gears_fixed_gived : int = 0

const VALUE_SHOW_UP = preload("res://scenes/ui/game/win_screen/value_show_up.tscn")

@export 
var values_container: VBoxContainer

@export
var final_value_container : VBoxContainer

func _ready() -> void:
	add_value("Round Win Gears", gears_fixed_gived, 0, values_container)
	add_value("Gears Collected", gears_winned_in_round, 1, values_container)
	add_value("Total Gears", gears_fixed_gived + gears_winned_in_round, 2, final_value_container)
	pass
	
func add_value(label : String, value : int, delay : float, container : VBoxContainer) -> void:
	var value_row : WinShowValue = VALUE_SHOW_UP.instantiate()
	value_row.label_value = label
	value_row.value = value
	value_row.delay_to_show = delay
	container.call_deferred("add_child", value_row)
	pass

func _on_button_button_up() -> void:
	var player_round : int = Global.player_stats.round_num + 1
	if (player_round >= 3):
		player_round = 0
		Global.player_stats.round_group_num += 1
	Global.player_stats.round_num = player_round
	Global.change_to_scene.emit(Global.Menu.SHOP)
	pass # Replace with function body.
