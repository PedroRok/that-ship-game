extends Node


enum Entities { SMALL_BOAT, COAST_BOAT, MEDIUM_BOAT, TANK_BOAT, PLANE }

const entities : Dictionary = {
	Entities.SMALL_BOAT : preload("res://core/resources/boats/mini_boat.tres"),
	Entities.COAST_BOAT : preload("res://core/resources/boats/small_boat.tres"),
	Entities.MEDIUM_BOAT : preload("res://core/resources/boats/medium_boat.tres"),
	Entities.TANK_BOAT : preload("res://core/resources/boats/tank_boat.tres")
}

enum Guns { SMALL_GUN, SMALL_MISSILE }

const guns : Dictionary = {
	Guns.SMALL_GUN : preload("res://scenes/entities/guns/simple_gun.tscn"),
	Guns.SMALL_MISSILE : preload("res://scenes/entities/guns/missile_gun.tscn")
}
