extends Node2D

@onready
var small_boat = preload("res://scenes/entities/small-boat/small_boat.tscn")
@onready
var small_boat_resource = preload("res://core/resources/boats/small_boat.tres")

@onready
var tanker_boat = preload("res://scenes/entities/tanker-boat/tanker_boat.tscn")
@onready
var tanker_boat_resource = preload("res://core/resources/boats/tank_boat.tres")

@onready
var team_resource = preload("res://core/resources/teams/team_left.tres")

@onready
var gun = preload("res://scenes/entities/guns/gun.tscn")

func _ready() -> void:
	EventBus.connect("spawn_ship", Callable(self, "select_ship"))
	pass

func select_ship(ship_name : String):
	if (ship_name == "small"):
		handle_ship_spawn(small_boat.instantiate(), small_boat_resource)
	else:
		handle_ship_spawn(tanker_boat.instantiate(), tanker_boat_resource)
	
	
func handle_ship_spawn(boat_var : Ship, ship_resource : Resource):
	var boat = boat_var
	if boat:
		boat.team_stats = team_resource
		boat.boat_stats = ship_resource
		add_child(boat)
		for slots in boat.boat_stats.gun_slots:
			boat.add_new_gun(gun.instantiate())
			pass
		boat.global_position = position
	pass
