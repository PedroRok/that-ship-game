class_name SimpleGun
extends Gun

const AIR_LEAD : float = 0.85
const LEAD_STEPS : int = 3

@export
var barrel_texture : Sprite2D

@export
var fixed_angle : bool = false
@export
var speed_spread : bool = false
@export
var needs_line_of_sight : bool = true

@onready 
var gun_line_of_sight: RayCast2D = $GunLineOfSight

var _speed_cache : float = 0.0

func shoot_gun(direction: Vector2) -> void:
	if (!is_instance_valid(enemy)):
		enemy = null
	var deep : bool = enemy is Entity and (enemy as Entity).is_submerged()
	if (!needs_line_of_sight or enemy is Base or deep or gun_line_of_sight.is_colliding()):
		super.shoot_gun(direction)

func _fire(direction : Vector2) -> void:
	var target : Entity = enemy as Entity
	if (target and (speed_spread or (_on_ship_deck() and target.entity_stats is AirPlaneState))):
		var limit : float = spread_degrees(target.entity_stats.speed, target_distance(target) / effective_range())
		limit *= RunData.FLAK_SPREAD_BOMBER_MULT if RunData.FLAK_SPREAD_BOMBERS.has(target.entity_stats.name) else RunData.FLAK_SPREAD_MULT
		direction = direction.rotated(deg_to_rad(randf_range(-limit, limit)))
	super._fire(direction)

func can_target(target : Node2D) -> bool:
	if (!super.can_target(target)):
		return false
	var entity : Entity = target as Entity
	if (!entity or !(entity.entity_stats is AirPlaneState) or !_on_ship_deck()):
		return true
	return entity.get_center_pos().y >= ShipEntity.WATER_LEVEL - RunData.NAVAL_GUN_CEILING

func _on_ship_deck() -> bool:
	return RunData.NAVAL_GUNS.has(int(gun_type)) and get_parent() is ShipEntity

static func spread_degrees(speed : float, reach : float) -> float:
	var speeds : Array[float] = RunData.FLAK_SPREAD_SPEEDS
	var index : int = 0
	while (index < speeds.size() - 2 and speed > speeds[index + 1]):
		index += 1
	var blend : float = clampf(inverse_lerp(speeds[index], speeds[index + 1], speed), 0.0, 1.0)
	var near : float = lerpf(RunData.FLAK_SPREAD_NEAR[index], RunData.FLAK_SPREAD_NEAR[index + 1], blend)
	var far : float = lerpf(RunData.FLAK_SPREAD_FAR[index], RunData.FLAK_SPREAD_FAR[index + 1], blend)
	return lerpf(near, far, clampf(reach, 0.0, 1.0))

func _physics_process(_delta: float) -> void:
	if (enemy && !fixed_angle):
		barrel_texture.look_at(_aim_point())
		projectile_rotation_spawn = barrel_texture.rotation
		gun_line_of_sight.look_at(enemy.get_center_pos())

func _aim_point() -> Vector2:
	var point : Vector2 = enemy.get_center_pos()
	var target : Entity = enemy as Entity
	if (!target or !(target.entity_stats is AirPlaneState) or !(get_parent() is ShipEntity)):
		return point
	var speed : float = _projectile_speed()
	if (speed <= 0.0):
		return point
	var step : Vector2 = target.linear_velocity / float(Engine.physics_ticks_per_second)
	var predicted : Vector2 = point
	for i : int in LEAD_STEPS:
		predicted = point + step * (end_barrel.global_position.distance_to(predicted) / speed)
	return point.lerp(predicted, AIR_LEAD)

func _projectile_speed() -> float:
	if (_speed_cache > 0.0 or !bullet):
		return _speed_cache
	var inst : Node = bullet.instantiate()
	if (inst is Bullet and !(inst is BulletMissile)):
		_speed_cache = maxf(1.0, roundf((inst as Bullet).bullet_stats.speed * bullet_speed_scale))
	inst.free()
	return _speed_cache
