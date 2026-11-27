class_name BalanceUnit
extends RefCounted

const TICKS_PER_SECOND : float = 60.0
const FLAK_RANGE_FALLBACK : float = 400.0

var id : String = ""
var stats : BoatStats
var unit_class : int = 0
var is_air : bool = false
var can_submerge : bool = false
var is_boss : bool = false
var health : float = 1.0
var speed : float = 0.0
var radar : float = 0.0
var price : int = 0
var build_time : float = 1.0
var dive_distance : float = 110.0
var guns : Array[Dictionary] = []

static func from_stats(boat : BoatStats, picks : Dictionary = {}) -> BalanceUnit:
	var unit : BalanceUnit = BalanceUnit.new()
	unit.stats = boat
	unit.id = boat.name
	unit.unit_class = int(boat.unit_class)
	unit.is_air = boat is AirPlaneState
	unit.can_submerge = boat.can_submerge
	unit.health = boat.health
	unit.speed = boat.speed
	unit.radar = float(boat.radar_distance)
	unit.price = boat.price
	unit.build_time = float(boat.produce_cd) * boat.build_time_mult
	unit.dive_distance = boat.dive_distance
	var slot_index : int = 0
	for slot : GunSlot in boat.gun_slots:
		var gun_type : int = int(picks.get(slot_index, slot.default_gun_type()))
		slot_index += 1
		if (gun_type < 0):
			continue
		var entry : Dictionary = gun_entry(gun_type)
		if (!entry.is_empty()):
			entry["interval"] = float(entry["interval"]) * boat.fire_interval_mult
			entry["damage"] = float(entry["damage"]) * boat.damage_mult
			if (boat.surface_damage_mult == 0.0):
				entry["surface"] = false
				entry["sub"] = false
			unit.guns.append(entry)
	return unit

static func gun_entry(gun_type : int) -> Dictionary:
	var scene : PackedScene = Enums.gun_scene(gun_type)
	if (scene == null):
		return {}
	var gun : Gun = scene.instantiate() as Gun
	if (gun == null):
		return {}
	var entry : Dictionary = {
		"type": gun_type,
		"damage": 1.0,
		"interval": float(gun.time_to_shoot + 1) / TICKS_PER_SECOND,
		"range": gun.effective_range(),
		"air": gun.hits_air,
		"surface": gun.hits_surface,
		"sub": gun.hits_submerged,
		"scale": gun.damage_scale,
		"los": gun is SimpleGun and (gun as SimpleGun).needs_line_of_sight,
	}
	if (gun.bullet):
		var bullet : Node = gun.bullet.instantiate()
		var bullet_node : Bullet = bullet as Bullet
		if (bullet_node and bullet_node.damage):
			entry["damage"] = bullet_node.damage.damage * gun.damage_scale
		bullet.free()
	gun.free()
	return entry

func dps(target_kind : String, flat_bonus : float = 0.0, rate_mult : float = 1.0) -> float:
	var total : float = 0.0
	for gun : Dictionary in guns:
		if (!bool(gun[target_kind])):
			continue
		total += (float(gun["damage"]) + flat_bonus) / (float(gun["interval"]) * rate_mult)
	return total

func max_range() -> float:
	var best : float = 0.0
	for gun : Dictionary in guns:
		best = maxf(best, float(gun["range"]))
	return best

func hits(kind : String) -> bool:
	for gun : Dictionary in guns:
		if (bool(gun[kind])):
			return true
	return false
