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

enum Guns { SMALL_GUN, SMALL_MISSILE, MEDIUM_GUN, LARGE_GUN, MEDIUM_MISSILE, LARGE_MISSILE, SMALL_AA, MEDIUM_AA, SMALL_TORPEDO, MEDIUM_TORPEDO, BOMB, DEPTH_BOMB, ROTARY_SMALL, ROTARY_TWIN, HELI_DEPTH, HOMING_MISSILE, TWIN_CANNON, AIR_MISSILE, AIR_BOMB, SAM_VERTICAL, SAM_HEAVY, HELI_ASM, HEAVY_ASM, DEPTH_LAUNCHER }

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
	Guns.DEPTH_BOMB : GunSize.SMALL,
	Guns.ROTARY_SMALL : GunSize.SMALL,
	Guns.ROTARY_TWIN : GunSize.MEDIUM,
	Guns.HELI_DEPTH : GunSize.MEDIUM,
	Guns.HOMING_MISSILE : GunSize.MEDIUM,
	Guns.TWIN_CANNON : GunSize.SMALL,
	Guns.AIR_MISSILE : GunSize.SMALL,
	Guns.AIR_BOMB : GunSize.SMALL,
	Guns.SAM_VERTICAL : GunSize.SMALL,
	Guns.SAM_HEAVY : GunSize.SMALL,
	Guns.HELI_ASM : GunSize.SMALL,
	Guns.HEAVY_ASM : GunSize.MEDIUM,
	Guns.DEPTH_LAUNCHER : GunSize.SMALL
}

const gun_screw_cost : Dictionary = {
	Guns.HOMING_MISSILE : 4,
	Guns.SAM_HEAVY : 3,
}

func gun_extra_cost(gun_type : int) -> int:
	return int(gun_screw_cost.get(gun_type, 0))

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
	Guns.DEPTH_BOMB : "res://scenes/entities/guns/depth_bomb_gun.tscn",
	Guns.ROTARY_SMALL : "res://scenes/entities/guns/rotary_small.tscn",
	Guns.ROTARY_TWIN : "res://scenes/entities/guns/rotary_twin.tscn",
	Guns.HELI_DEPTH : "res://scenes/entities/guns/heli_depth.tscn",
	Guns.HOMING_MISSILE : "res://scenes/entities/guns/homing_missile.tscn",
	Guns.TWIN_CANNON : "res://scenes/entities/guns/twin_cannon.tscn",
	Guns.AIR_MISSILE : "res://scenes/entities/guns/air_missile.tscn",
	Guns.AIR_BOMB : "res://scenes/entities/guns/air_bomb.tscn",
	Guns.SAM_VERTICAL : "res://scenes/entities/guns/sam_vertical.tscn",
	Guns.SAM_HEAVY : "res://scenes/entities/guns/sam_heavy.tscn",
	Guns.HELI_ASM : "res://scenes/entities/guns/heli_asm.tscn",
	Guns.HEAVY_ASM : "res://scenes/entities/guns/heavy_asm.tscn",
	Guns.DEPTH_LAUNCHER : "res://scenes/entities/guns/depth_launcher.tscn"
}

const gun_info : Dictionary = {
	Guns.BOMB : ["weapon.surface_bomb", "weapon.explodes_on_the_water_surface"],
	Guns.DEPTH_BOMB : ["weapon.depth_bomb", "weapon.sinks_into_the_water_and"],
	Guns.HELI_DEPTH : ["weapon.heli_depth", "weapon.sinks_into_the_water_and"],
	Guns.AIR_BOMB : ["weapon.surface_bomb", "weapon.explodes_on_the_water_surface"]
}

func gun_name(gun_type : int) -> String:
	var info : Array = gun_info.get(gun_type, [])
	return Loc.t(str(info[0])) if !info.is_empty() else Loc.named("weapon", str(Guns.keys()[gun_type]).to_lower())

func gun_description(gun_type : int) -> String:
	var info : Array = gun_info.get(gun_type, [])
	return Loc.t(str(info[1])) if info.size() > 1 else ""


func gun_scene(gun_type : int) -> PackedScene:
	return load(guns[gun_type]) as PackedScene
