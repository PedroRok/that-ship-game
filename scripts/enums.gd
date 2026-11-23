extends Node


enum Entities { SMALL_BOAT, COAST_BOAT, MEDIUM_BOAT, TANK_BOAT, PLANE }

const entities : Dictionary = {
	Entities.SMALL_BOAT : preload("res://core/resources/boats/mini_boat.tres"),
	Entities.COAST_BOAT : preload("res://core/resources/boats/small_boat.tres"),
	Entities.MEDIUM_BOAT : preload("res://core/resources/boats/medium_boat.tres"),
	Entities.TANK_BOAT : preload("res://core/resources/boats/tank_boat.tres")
}

enum UnitClass { COASTAL, HEAVY, AIR, ANTI_AIR, SUBMARINE, STRUCTURE }

enum UpgradeTarget { BASE, ENTITY, GUN, SKILL, WEAPON_UNLOCK }

enum UpgradeOp { ADD, MULTIPLY }

enum GunSize { SMALL, MEDIUM, LARGE }

enum Guns { SMALL_GUN, SMALL_MISSILE, MEDIUM_GUN, LARGE_GUN, MEDIUM_MISSILE, LARGE_MISSILE, SMALL_AA, MEDIUM_AA, SMALL_TORPEDO, MEDIUM_TORPEDO, BOMB, DEPTH_BOMB }

const gun_sizes : Dictionary = {
	Guns.SMALL_GUN : GunSize.SMALL,
	Guns.SMALL_MISSILE : GunSize.SMALL,
	Guns.MEDIUM_GUN : GunSize.MEDIUM,
	Guns.LARGE_GUN : GunSize.LARGE,
	Guns.MEDIUM_MISSILE : GunSize.MEDIUM,
	Guns.LARGE_MISSILE : GunSize.LARGE,
	Guns.SMALL_AA : GunSize.SMALL,
	Guns.MEDIUM_AA : GunSize.MEDIUM,
	Guns.SMALL_TORPEDO : GunSize.SMALL,
	Guns.MEDIUM_TORPEDO : GunSize.MEDIUM,
	Guns.BOMB : GunSize.SMALL,
	Guns.DEPTH_BOMB : GunSize.SMALL
}

const guns : Dictionary = {
	Guns.SMALL_GUN : "res://scenes/entities/guns/simple_gun.tscn",
	Guns.SMALL_MISSILE : "res://scenes/entities/guns/missile_gun.tscn",
	Guns.MEDIUM_GUN : "res://scenes/entities/guns/cannon_medium.tscn",
	Guns.LARGE_GUN : "res://scenes/entities/guns/cannon_large.tscn",
	Guns.MEDIUM_MISSILE : "res://scenes/entities/guns/missile_medium.tscn",
	Guns.LARGE_MISSILE : "res://scenes/entities/guns/missile_large.tscn",
	Guns.SMALL_AA : "res://scenes/entities/guns/aa_gun_small.tscn",
	Guns.MEDIUM_AA : "res://scenes/entities/guns/aa_gun_medium.tscn",
	Guns.SMALL_TORPEDO : "res://scenes/entities/guns/torpedo_small.tscn",
	Guns.MEDIUM_TORPEDO : "res://scenes/entities/guns/torpedo_medium.tscn",
	Guns.BOMB : "res://scenes/entities/guns/bomb_gun.tscn",
	Guns.DEPTH_BOMB : "res://scenes/entities/guns/depth_bomb_gun.tscn"
}

const gun_info : Dictionary = {
	Guns.BOMB : ["SURFACE BOMB", "Explodes on the water surface. Surface targets only."],
	Guns.DEPTH_BOMB : ["DEPTH BOMB", "Sinks into the water and explodes on hit. Ships and submarines."]
}

func gun_name(gun_type : int) -> String:
	var info : Array = gun_info.get(gun_type, [])
	return info[0] if !info.is_empty() else str(Guns.keys()[gun_type]).replace("_", " ")

func gun_description(gun_type : int) -> String:
	var info : Array = gun_info.get(gun_type, [])
	return info[1] if info.size() > 1 else ""


func gun_scene(gun_type : int) -> PackedScene:
	return load(guns[gun_type]) as PackedScene
