class_name ShipManager
extends Node

@export
var bases : Array[Base]

@export
var bullet_manager : BulletManager

@export
var item_manager : ItemManager

@onready
var ship_entity : PackedScene = preload("res://scenes/entities/ship/ship_entity.tscn")

@onready
var gun : PackedScene = preload("res://scenes/entities/guns/simple_gun.tscn")

func _ready() -> void:
	for base in bases:
		base.spawn_ship_event.connect(Callable(self, "handle_ship_spawn"))

func handle_ship_spawn(pos : Vector2, ship_resource : Resource, team_res : TeamStats) -> void:
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
	if (team_stats.team_id == 1):
		return
	item_manager.handle_random_spawn(pos, true)
	pass
