class_name ShipManager
extends Node

@export
var base : Base


@export
var bullet_manager : BulletManager

@export
var item_manager : ItemManager

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
var gun : PackedScene = preload("res://scenes/entities/guns/missile_gun.tscn")

func _ready() -> void:
	base.spawn_ship_event.connect(Callable(self, "select_ship"))

func select_ship(ship_name : BoatStats) -> void:
	handle_ship_spawn(base.ship_constructor.position, ship_name)
	
func handle_ship_spawn_by_type(pos : Vector2, ship_type : ShipsTypes, team_res : TeamStats = team_resource) -> void:
	handle_ship_spawn(pos, ships.get(ship_type), team_res)

func handle_ship_spawn(pos : Vector2, ship_resource : Resource, team_res : TeamStats = team_resource) -> void:
	var boat : ShipEntity = ship_entity.instantiate()
	if boat:
		boat.team_stats = team_res
		boat.boat_stats = ship_resource
		boat.connect("bullet_fired", Callable(bullet_manager, "handle_bullet_spawned"))
		boat.connect("ship_destroy", Callable(self, "handle_ship_destroy"))
		add_child(boat)
		for slots in boat.boat_stats.gun_slots:
			boat.add_new_gun(gun.instantiate())
			pass
		boat.global_position = pos
	pass

func handle_ship_destroy(pos : Vector2, _ship_stats : BoatStats, team_stats : TeamStats) -> void:
	if (team_stats.team_id == base.team_stats.team_id):
		return
	item_manager.handle_random_spawn(pos, true)
	pass
