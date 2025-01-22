@tool
class_name ShipsSlotUI
extends MarginContainer

var player_stats : PlayerStats

@onready 
var container: HBoxContainer = $Container

signal spawn_entity(entity_name : EntityStats)

func _ready() -> void:
	if (Engine.is_editor_hint()):
		player_stats = load("res://core/resources/player/player_stats_full.tres")
	else:
		player_stats = Global.player_stats
	if (!player_stats):
		return
	var idx : int = 0
	for entity : EntityStats in player_stats.unlocked_entities:
		var ship_button : ShipButton = container.get_child(idx)
		ship_button.entity_stats = entity
		ship_button.setup()
		ship_button.connect("spawn_entity", Callable(self, "emit_spawn_signal"))
		idx += 1

func emit_spawn_signal(entity_stats : EntityStats) -> void:
	spawn_entity.emit(entity_stats)
	
func on_value_change(new_int : int) -> void:
	for button : ShipButton in container.get_children():
		if (button.enabled):
			button.on_value_change(new_int)
	
