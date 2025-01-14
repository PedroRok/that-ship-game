class_name ShopMenu
extends MenuControl

func _on_button_button_down() -> void:
	emit_signal("change_to_menu", "SELECT")
	pass # Replace with function body.
