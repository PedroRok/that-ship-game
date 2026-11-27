extends ShipState

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

var on_radar_enemy : Node2D

func enter() -> void:
	var enemy : Node = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	set_guns_enemy(enemy)
	pass
	
func exit() -> void:
	set_guns_enemy(null)
	pass

func set_guns_enemy(enemy : Node2D) -> void:
	on_radar_enemy = enemy
	for gun in parent.get_guns():
		gun.enemy = enemy
	
func process_input(_event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	var speed_before : float = parent.linear_velocity.x
	super(delta)
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, 'death')
		return
		
	var enemy_in_radar : Node2D = radar_component.check_radar(parent.team_stats.team_id, parent.team_stats.direction)
	if (!enemy_in_radar):
		Transitioned.emit(self, 'move')
		return
	
	var boat : BoatStats = parent.entity_stats as BoatStats
	if (boat and boat.box_radar):
		for gun : Gun in parent.get_guns():
			gun.enemy = radar_component.target_for(gun)
	elif (on_radar_enemy != enemy_in_radar):
		set_guns_enemy(enemy_in_radar)
	
	for gun in parent.get_guns():
		if (boat and boat.box_radar and !gun.enemy):
			continue
		gun.shoot_gun(Vector2(parent.facing(), 0))
	
	if (boat and boat.can_submerge and !boat.is_boss):
		_glide(speed_before, delta)
	return

func _glide(speed_before : float, delta : float) -> void:
	var ship : ShipEntity = parent as ShipEntity
	var cruise : float = ship.cruise_speed(delta)
	var goal : float = parent.team_stats.direction * cruise if _single_light_ahead() else 0.0
	var speed : float = move_toward(speed_before, goal, cruise / RunData.SUB_STOP_SECONDS * delta)
	parent.linear_velocity.x = speed / ship.damp_factor(delta)

func _single_light_ahead() -> bool:
	var found : Entity = null
	for item : Variant in radar_component.enemy_hitbox:
		var hitbox : SimpleHitboxComponent = item as SimpleHitboxComponent
		if (!is_instance_valid(hitbox) or !hitbox.enabled or !radar_component.reaches(hitbox)):
			continue
		var target : Node2D = hitbox.get_hitbox_parent()
		if (!target or !_in_weapon_range(target)):
			continue
		var unit : Entity = target as Entity
		if (!unit or unit.entity_stats.unit_class != Enums.UnitClass.COASTAL or (found and found != unit)):
			return false
		found = unit
	return found != null and absf(found.global_position.x - parent.global_position.x) > RunData.SUB_PUSH_MIN_DISTANCE

func _in_weapon_range(target : Node2D) -> bool:
	for gun : Gun in parent.get_guns():
		if (gun.can_target(target) and gun.target_distance(target) <= gun.effective_range()):
			return true
	return false
