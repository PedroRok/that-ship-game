class_name ScrewManager
extends Node

@export
var game_ui : GameUI

@onready
var screw_entity : PackedScene = preload("res://scenes/entities/misc/screw.tscn")

func handle_screw_spawn(pos : Vector2, explode : bool) -> void:
	var screw : ScrewEntity = screw_entity.instantiate()
	if screw:
		add_child(screw)
		screw.global_position = pos
		screw.connect("pickup_screw", Callable(game_ui, "change_screw"))
		if explode:
			screw.explode()
	pass
