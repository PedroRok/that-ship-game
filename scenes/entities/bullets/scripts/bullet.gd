class_name Bullet
extends Area2D

@export
var bullet_stats : BulletStats

@export
var damage : Damage

var direction : Vector2 = Vector2.ZERO

var team : int = -1

var attacker_class : Enums.UnitClass = Enums.UnitClass.STRUCTURE

var hits_air : bool = true
var hits_submerged : bool = false
var base_damage_mult : float = 1.0
var surface_damage_mult : float = -1.0

var already_hit : Array[Area2D]

var target : Node2D

var _splashed : bool = false

func _physics_process(_delta: float) -> void:
	if direction != Vector2.ZERO:
		var velocity : Vector2 = direction * bullet_stats.speed
		var was_above : bool = global_position.y < ShipEntity.WATER_LEVEL
		global_position += velocity
		if (!_splashed and was_above and velocity.y > 0.0 and global_position.y >= ShipEntity.WATER_LEVEL):
			_splashed = true
			BattleAudio.play_at(self, &"water_impact", Vector2(global_position.x, ShipEntity.WATER_LEVEL))

	if (bullet_stats.killTime <= 0):
		queue_free()
	bullet_stats.killTime -= 1
	pass
	
func set_direction(new_direction: Vector2) -> void:
	self.direction = new_direction
	new_direction = self.direction.rotated(rotation)

func _on_area_shape_entered(_area_rid: RID, area: Area2D, _area_shape_index: int, _local_shape_index: int) -> void:
	if (already_hit.has(area) || bullet_stats.piercing <= already_hit.size()):
		return 
	if (area is HitboxComponent):
		var ship : Entity = area.entity
		if (ship.is_submerged() and !hits_submerged):
			return
		if (ship.entity_stats is AirPlaneState and !hits_air):
			return
		if (surface_damage_mult == 0.0 and !(ship.entity_stats is AirPlaneState)):
			return
		if (ship.team_stats.team_id != team):
			if (area.enabled):
				already_hit.append(area)
				var scaled : Damage = damage.duplicate()
				scaled.damage *= damage_mult_against(ship)
				area.handle_hit(scaled, direction.x)
				play_impact_sfx(ship.is_submerged())
				if (bullet_stats.piercing <= already_hit.size()):
					remove_bullet()
	if (area is BaseHitboxComponent):
		var base : Base = area.base
		if (base.team_stats.team_id != team and surface_damage_mult != 0.0):
			already_hit.append(area)
			area.handle_hit(damage_to_base(), direction.x)
			if (bullet_stats.piercing <= already_hit.size()):
				remove_bullet()
	pass

func damage_mult_against(victim : Entity) -> float:
	if (surface_damage_mult >= 0.0 and !(victim.entity_stats is AirPlaneState)):
		return surface_damage_mult
	var mult : float = Global.counter_multiplier(attacker_class, victim.entity_stats.unit_class)
	if (attacker_class == Enums.UnitClass.AIR and victim.entity_stats.name == "escort"):
		mult *= RunData.ESCORT_AIR_DAMAGE
	return mult

func damage_to_base() -> Damage:
	var scaled : Damage = damage.duplicate()
	scaled.damage *= base_damage_mult
	return scaled

func play_impact_sfx(underwater : bool = false) -> void:
	BattleAudio.play_at(self, &"hull_impact", global_position, null, underwater)

func remove_bullet() -> void:
	queue_free()
