class_name UnitFactory
extends RefCounted

const SHIP: PackedScene = preload("res://scenes/entities/troops/ship_entity.tscn")
const AIR: PackedScene = preload("res://scenes/entities/troops/air_entity.tscn")
const HELICOPTER: PackedScene = preload("res://scenes/entities/troops/helicopter_entity.tscn")

static func create(stats: Resource, team: TeamStats, on_bullet: Callable, on_destroy: Callable) -> Entity:
	var is_air: bool = stats is AirPlaneState
	var is_heli: bool = stats is HelicopterStats
	var unit: Entity = (HELICOPTER if is_heli else (AIR if is_air else SHIP)).instantiate() as Entity
	unit.team_stats = team
	unit.entity_stats = Global.upgraded_entity(stats) if team.team_id == 1 else stats as EntityStats
	unit.bullet_fired.connect(on_bullet)
	unit.entity_destroy.connect(on_destroy)
	if is_air and !is_heli and team.direction < 0:
		unit.rotation = PI
	return unit
