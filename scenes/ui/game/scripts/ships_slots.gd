@tool
class_name ShipsSlotUI
extends MarginContainer

var player_stats : PlayerStats

@onready 
var container: HBoxContainer = $Container

signal spawn_ship(ship_name : BoatStats)

func _ready() -> void:
	if (Engine.is_editor_hint()):
		player_stats = load("res://core/resources/player_stats_full.tres")
	else:
		player_stats = Global.player_stats
	if (!player_stats):
		return
	var idx : int = 0
	for ship : BoatStats in player_stats.owned_ships:
		var ship_button : ShipButton = container.get_child(idx)
		ship_button.boat_stats = ship
		ship_button.setup()
		ship_button.connect("spawn_ship", Callable(self, "emit_spawn_signal"))
		idx += 1

func emit_spawn_signal(boat_stats : BoatStats) -> void:
	spawn_ship.emit(boat_stats)
	
func on_value_change(new_int : int) -> void:
	for button : ShipButton in container.get_children():
		if (button.enabled):
			button.on_value_change(new_int)
	
