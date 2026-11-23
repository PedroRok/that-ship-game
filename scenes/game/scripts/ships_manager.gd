class_name ShipManager
extends Node

signal boss_defeated(entity_stats : EntityStats)

@export
var bases : Array[Base]

@export
var bullet_manager : BulletManager

@export
var item_manager : ItemManager


func _ready() -> void:
	for base in bases:
		base.spawn_ship_event.connect(Callable(self, "handle_ship_spawn"))

func handle_ship_spawn(pos : Vector2, ship_resource : Resource, team_res : TeamStats) -> void:
	var is_air : bool = ship_resource is AirPlaneState
	var boat : Entity = UnitFactory.create(ship_resource, team_res, Callable(bullet_manager, "handle_bullet_spawned"), Callable(self, "handle_ship_destroy"))
	if boat:
		add_child(boat)
		var base : Base = _base_of(team_res)
		var boss : bool = entity_is_boss(boat.entity_stats)
		var boat_stats : BoatStats = boat.entity_stats as BoatStats
		if (base and !boss and !is_air and boat_stats and boat_stats.can_submerge):
			var surface_y : float = base.get_spawn_point().y
			boat.global_position = Vector2(pos.x, surface_y)
			(boat as ShipEntity).start_submerged(pos.y - surface_y)
			boat.begin_entry(base.global_position.x + team_res.direction * 150, false, 0, true)
		elif (base and boss):
			var behind_x : float = base.global_position.x - team_res.direction * 70
			var clear_x : float = base.global_position.x + team_res.direction * 150
			if (is_air):
				boat.global_position = Vector2(behind_x, 130)
				boat.begin_entry(clear_x, false)
			else:
				boat.global_position = Vector2(behind_x, pos.y)
				boat.linear_velocity.x = team_res.direction * boat.entity_stats.speed * 0.5
				boat.begin_entry(clear_x, true)
		elif (base and is_air):
			boat.global_position = pos
			(boat as AirEntity).begin_takeoff(base.global_position.x + team_res.direction * 150)
		else:
			boat.global_position = pos
	pass

func entity_is_boss(stats : EntityStats) -> bool:
	return stats.is_boss

func _base_of(team_res : TeamStats) -> Base:
	for base : Base in bases:
		if (base.team_stats == team_res):
			return base
	return null

func handle_ship_destroy(pos : Vector2, _entity_stats : EntityStats, team_stats : TeamStats) -> void:
	if (team_stats.team_id == 1):
		return
	if (_entity_stats.is_boss):
		boss_defeated.emit(_entity_stats)
	item_manager.handle_random_spawn(pos, true)
	pass
