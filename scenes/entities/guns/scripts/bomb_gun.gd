class_name BombGun
extends Gun

const ZONE_BACK : float = 8.0
const ZONE_FRONT : float = 48.0

var fixed_angle : bool = true

@export
var depth_bullet : PackedScene

func target_distance(target : Node2D) -> float:
	if (target is Base):
		return super.target_distance(target)
	var point : Vector2 = (target as Entity).get_center_pos() if target is Entity else target.global_position
	return absf(point.x - global_position.x)

func _init() -> void:
	hits_air = false
	hits_surface = true
	hits_submerged = false

func can_target(target : Node2D) -> bool:
	var entity : Entity = target as Entity
	if (!entity):
		return true
	if (entity.entity_stats is AirPlaneState):
		return false
	return depth_bullet != null or !entity.is_submerged()

func shoot_gun(_direction : Vector2) -> void:
	var carrier : AirEntity = get_parent() as AirEntity
	if (carrier and carrier.rotates_with_body()):
		return
	if (current_time_to_shoot > 0):
		current_time_to_shoot -= 1
		return
	if (!enemy or !can_target(enemy)):
		return
	var plane : Entity = get_parent() as Entity
	var vx : float = plane.linear_velocity.x if plane else 0.0
	var target_x : float = enemy.get_center_pos().x if enemy.has_method("get_center_pos") else enemy.global_position.x
	if (depth_bullet):
		target_x += BulletDepthBomb.lead_x(enemy)
	var ahead : float = (target_x - global_position.x) * signf(vx if vx != 0.0 else 1.0)
	if (ahead < -ZONE_BACK or ahead > ZONE_FRONT):
		return
	current_time_to_shoot = time_to_shoot
	drop(enemy)

func drop(target : Node2D) -> void:
	var plane : Entity = get_parent() as Entity
	var vx : float = plane.linear_velocity.x if plane else 0.0
	var unit : Entity = target as Entity
	var sinking : bool = depth_bullet != null and unit != null and unit.is_submerged()
	var bomb : Bullet = (depth_bullet if sinking else bullet).instantiate()
	bomb.hits_submerged = sinking
	bomb.target = target
	bomb.base_damage_mult = base_damage_mult
	bomb.damage = bomb.damage.duplicate()
	bomb.damage.damage *= damage_scale
	fired_bullet.emit(bomb, end_barrel.global_position, Vector2(vx * 0.8, 30.0), 0.0)
	play_effects()
