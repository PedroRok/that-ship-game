extends Control

@export
var total_gear_earned : WinShowValue

func _ready() -> void:
	var tween : Tween = get_tree().create_tween()
	total_gear_earned.setup("Total de Engrenagens", Global.player_stats.gear)
	total_gear_earned.label.visible_ratio = 0
	total_gear_earned.show_icon(false)
	tween.tween_property(total_gear_earned.label, "visible_ratio", 1, 3)
	tween.finished.connect(Callable(total_gear_earned, "show_icon"))
	pass
	
	

func _on_button_button_up() -> void:
	Global.change_to_scene.emit(Global.Menu.SHOP)
	pass # Replace with function body.
