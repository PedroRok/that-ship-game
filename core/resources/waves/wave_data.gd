class_name WaveData
extends Resource

@export
var ships : Array[BoatStats]
@export
var spawn_interval : float = 6.0
@export
var duration : float = 30.0
@export
var stat_mult : float = 1.0

@export_group("Boss")
@export
var boss : BoatStats
@export
var boss_health_mult : float = 4.0
@export
var boss_coin_reward : int = 1

@export_group("Base")
@export
var base_tier : BaseTier
