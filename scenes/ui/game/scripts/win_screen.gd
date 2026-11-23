extends Control

var rows : Array = []
var total : int = 0
var title : String = ""

const VALUE_SHOW_UP = preload("res://scenes/ui/game/win_screen/value_show_up.tscn")

@export 
var values_container: VBoxContainer

@export
var final_value_container : VBoxContainer

func _ready() -> void:
	var title_label : Label = get_node_or_null("NinePatchRect/VBoxContainer/Middle/Shop/Title") as Label
	if (title_label and title != ""):
		title_label.text = title
	var delay : int = 0
	for row : Dictionary in rows:
		add_value(row["label"], row["value"], delay, values_container)
		delay += 1
	add_value("Total Gears", total, delay, final_value_container)

func add_value(label : String, value : int, delay : int, container : VBoxContainer) -> void:
	var value_row : WinShowValue = VALUE_SHOW_UP.instantiate()
	value_row.label_value = label
	value_row.value = value
	value_row.delay_to_show = delay
	container.call_deferred("add_child", value_row)

func _on_button_button_up() -> void:
	Global.change_scene(Global.Menu.SHOP)
