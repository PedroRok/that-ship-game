@tool
class_name RoundCard
extends PanelContainer

@export_group("Button")
@export
var card_stats : RoundCardStats
@onready
var button : Button = $Margin/VBox/Button

@export_group("Card")
@export
var title : String = "TITLE"
@export
var desc : String =  "A simple description"
@onready
var title_label : Label = $Margin/VBox/Title
@onready
var card_desc : RichTextLabel = $Margin/VBox/Desc

signal round_button_pressed

func _ready() -> void:
	set_stats(card_stats)

func set_stats(new_stats : RoundCardStats) -> void:
	if (!card_stats):
		push_error("Trying to start a card without a stats")
		return
	title_label.text = title
	card_desc.text = desc
	card_stats.apply_card(self)

func _on_button_button_up() -> void:
	round_button_pressed.emit()
	pass # Replace with function body.
