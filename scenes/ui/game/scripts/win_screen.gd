extends Control

var gears_winned_in_round : int = 0
var gears_fixed_gived : int = 0

const VALUE_SHOW_UP = preload("res://scenes/ui/game/win_screen/value_show_up.tscn")

@export 
var values_container: VBoxContainer

func _ready() -> void:
	add_value("Round Win Gears", gears_fixed_gived, 0)
	add_value("Gears Collected", gears_winned_in_round, 1)
	
	get_tree().create_timer(2).timeout.connect(Callable(self, "add_separator"))
	pass
	
func add_value(label : String, value : int, delay : float) -> void:
	var value_row : WinShowValue = VALUE_SHOW_UP.instantiate()
	value_row.label_value = label
	value_row.value = value
	value_row.delay_to_show = delay
	value_row.show_time = 2
	values_container.call_deferred("add_child", value_row)
	pass

func add_separator() -> void:
	var separator : HSeparator = HSeparator.new()
	values_container.call_deferred("add_child", separator)
	add_value("Total Win", gears_fixed_gived + gears_winned_in_round, 0)

func _on_button_button_up() -> void:
	Global.change_to_scene.emit(Global.Menu.SHOP)
	pass # Replace with function body.
