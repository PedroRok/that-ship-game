class_name BaseTier
extends Resource

@export
var base_health : float = 30
@export
var production_interval_mult : float = 1.0
@export_range(0, 6)
var turret_count : int = 0
@export
var sprite : Texture2D
@export
var turret_offsets : Array[Vector2] = []
