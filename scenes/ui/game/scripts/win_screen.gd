extends Control

var rows : Array = []
var total : int = 0
var title : String = ""
var rewards : bool = true

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
		add_value(Loc.t(row["label"]), row["value"], delay, values_container)
		delay += 1
	if (rewards):
		add_value("result.total_gears", total, delay, final_value_container)
		return
	(values_container.get_node("Label") as Label).text = "result.summary"
	final_value_container.hide()

func add_value(label : String, value : int, delay : int, container : VBoxContainer) -> void:
	var value_row : WinShowValue = VALUE_SHOW_UP.instantiate()
	value_row.label_value = label
	value_row.value = value
	value_row.delay_to_show = delay
	value_row.with_icon = rewards
	container.call_deferred("add_child", value_row)

func _on_button_button_up() -> void:
	Global.change_scene(Global.Menu.SHOP)
