extends MenuControl


@onready
var rounds : HBoxContainer = $NinePatchRect/MarginContainer2/Cards

func _ready() -> void:
	for node : RoundCard in rounds.get_children():
		node.connect("round_button_pressed", Callable(self, "change_to_game"))
		pass
		
func change_to_game() -> void:
	change_to_menu.emit("GAME")
