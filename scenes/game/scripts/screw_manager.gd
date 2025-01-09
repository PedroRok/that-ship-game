class_name ItemManager
extends Node

@export
var game_ui : GameUI

@onready
var gear_entity : PackedScene = preload("res://scenes/entities/misc/gear_entity.tscn")

func _ready() -> void:
	auto_gear()

func auto_gear() -> void:
	var tween : Tween = get_tree().create_tween()
	game_ui.screw_label.progress_bar = 0.0
	tween.tween_property(game_ui.screw_label, "progress_bar", 1.0, 1)
	tween.finished.connect(Callable(self, "auto_gear"))
	game_ui.screw_label.change_value(1)

func handle_gear_spawn(pos : Vector2, explode : bool) -> void:
	var gear : GearEntity = gear_entity.instantiate()
	if gear:
		add_child(gear)
		gear.global_position = pos
		gear.connect("pickup_gear", Callable(game_ui.gear_label, "change_value_animated"))
		if explode:
			gear.explode()
	pass
