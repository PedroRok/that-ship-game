class_name ScrewManager
extends Node

@onready
var screw_entity : PackedScene = preload("res://scenes/entities/misc/screw.tscn")

func handle_screw_spawn(pos : Vector2, explode : bool) -> void:
	var screw : ScrewEntity = screw_entity.instantiate()
	if screw:
		add_child(screw)
		screw.global_position = pos
		if explode:
			screw.explode()
	pass
