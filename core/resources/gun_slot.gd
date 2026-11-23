class_name GunSlot
extends Resource

@export
var position : Vector2
@export
var allowed_types : Array[Enums.Guns]
@export
var with_base : bool
@export
var max_size : Enums.GunSize = Enums.GunSize.SMALL

func accepts(gun_type : Enums.Guns) -> bool:
	return allowed_types.has(gun_type) and Enums.gun_sizes.get(gun_type, Enums.GunSize.SMALL) <= max_size

func default_gun_type() -> int:
	for gun_type : Enums.Guns in allowed_types:
		if (accepts(gun_type)):
			return gun_type
	return -1
