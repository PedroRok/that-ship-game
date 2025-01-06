class_name ScrewManager
extends Node

@export
var base : Base

@onready
var screw_entity : PackedScene = preload("res://scenes/entities/misc/screw.tscn")

func handle_ship_destroy(pos : Vector2, team_id : int) -> void:
	if (base.team_stats.team_id == team_id):
		return
	handle_screw_spawn(pos, true)

func handle_screw_spawn(pos : Vector2, explode : bool) -> void:
	var screw : ScrewEntity = screw_entity.instantiate()
	if screw:
		add_child(screw)
		screw.global_position = pos
		if explode:
			screw.explode()
	pass
