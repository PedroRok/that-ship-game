class_name Health
extends RichTextLabel

@export
var default_health : int = 10

var actual_health : int

func _ready() -> void:
	actual_health = default_health
	
func handle_hit():
	actual_health -= 1
	text = str(actual_health)
