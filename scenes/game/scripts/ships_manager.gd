class_name ShipManager
extends Node2D

@export
var bullet_manager : BulletManager

@onready
var ship_entity : PackedScene = preload("res://scenes/entities/ship/ship_entity.tscn")

enum ShipsTypes {
	SMALL,
	TANKER
}

var ships : Dictionary = {
	ShipsTypes.SMALL: preload("res://core/resources/boats/small_boat.tres"),
	ShipsTypes.TANKER: preload("res://core/resources/boats/tank_boat.tres")
}

@onready
var team_resource : TeamStats = preload("res://core/resources/teams/team_left.tres")
@onready
var gun : PackedScene = preload("res://scenes/entities/guns/gun.tscn")

func select_ship(ship_name : String) -> void:
	if (ship_name == "small"):
		handle_ship_spawn(position, ships.get(ShipsTypes.SMALL))
	else:
		handle_ship_spawn(position, ships.get(ShipsTypes.TANKER))
	
func handle_ship_spawn_by_type(pos : Vector2, ship_type : ShipsTypes, team_res : TeamStats = team_resource) -> void:
	handle_ship_spawn(pos, ships.get(ship_type), team_res)

func handle_ship_spawn(pos : Vector2, ship_resource : Resource, team_res : TeamStats = team_resource) -> void:
	var boat : ShipEntity = ship_entity.instantiate()
	if boat:
		boat.team_stats = team_res
		boat.boat_stats = ship_resource
		boat.connect("bullet_fired", Callable(bullet_manager, "handle_bullet_spawned"))
		add_child(boat)
		for slots in boat.boat_stats.gun_slots:
			boat.add_new_gun(gun.instantiate())
			pass
		boat.global_position = pos
	pass
