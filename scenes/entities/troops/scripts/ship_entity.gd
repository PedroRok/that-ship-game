@tool
class_name ShipEntity
extends Entity

const DIVE_DEPTH : float = 75.0
const DIVE_TIME : float = 4.5
const SURFACE_TIME : float = 2.5
const NEAR_SURFACE_OFFSET : float = 12.0
const NEAR_SURFACE_TINT : Color = Color(0.6, 0.78, 0.95, 0.85)
const SURFACE_CHECK : float = 0.4

@onready
var sprite: Sprite2D = $BoatSprite

var dive_depth : float = DIVE_DEPTH
var submerged : bool = false
var dive_offset : float = 0.0
var _spawn_x : float = NAN
var _initial_dive_done : bool = false
var _dive_tween : Tween
var _surface_clock : float = 0.0

func _ready() -> void:
	super._ready()
	if (!entity_stats):
		return
	sprite.texture = entity_stats.sprite
	if (Engine.is_editor_hint()):
		return
	apply_team_outline(sprite)
	if (team_stats.direction > 0):
		sprite.flip_h = false
	else:
		sprite.flip_h = true

func in_range(target : Node2D) -> bool:
	if (guns.is_empty()):
		return true
	for gun : Gun in guns:
		if (gun.can_target(target) and gun.target_distance(target) <= gun.effective_range()):
			return true
	return false

func is_submerged() -> bool:
	return submerged

func get_center_pos() -> Vector2:
	return super.get_center_pos() + Vector2(0, dive_offset)

const WATER_LEVEL : float = 368.0
const SINK_LIMIT : float = 5.0
const REST_DEPTH : float = 2.0
const RISE_SPEED : float = 22.0
const RISE_ACCEL : float = 150.0

var _recovering : bool = false

func _keep_afloat(delta : float) -> void:
	if (!is_nan(entry_x) or (collision_layer & 1) == 0 or !sprite or !sprite.texture):
		_recovering = false
		return
	var depth : float = global_position.y + sprite.texture.get_height() * 0.5 - WATER_LEVEL
	if (depth > SINK_LIMIT):
		_recovering = true
	elif (depth <= REST_DEPTH):
		if (_recovering and linear_velocity.y < 0.0):
			linear_velocity.y = 0.0
		_recovering = false
	if (_recovering):
		linear_velocity.y = move_toward(linear_velocity.y, -RISE_SPEED, RISE_ACCEL * delta)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if (Engine.is_editor_hint()):
		return
	if (!is_instance_valid(self) or is_queued_for_deletion()):
		return
	_keep_afloat(delta)
	var stats : BoatStats = entity_stats as BoatStats
	if (stats and stats.surfaces_for_air and _initial_dive_done and is_nan(entry_x)):
		_update_surfacing(delta, stats)
	if (submerged):
		return
	if (!stats or !stats.can_submerge or !is_nan(entry_x) or _initial_dive_done):
		return
	if (is_nan(_spawn_x)):
		_spawn_x = global_position.x
	if (abs(global_position.x - _spawn_x) >= stats.dive_distance):
		_dive(stats)

func _set_dive_offset(value : float) -> void:
	var delta : float = value - dive_offset
	dive_offset = value
	sprite.position.y = value
	$HitboxComponent.position.y = value
	$ParticlesComponent.position.y += delta
	for gun : Gun in guns:
		gun.position.y += delta

func start_submerged(from_offset : float) -> void:
	var stats : BoatStats = entity_stats as BoatStats
	if (stats):
		_dive(stats, from_offset)

func _dive(stats : BoatStats, from_offset : float = 0.0) -> void:
	submerged = true
	_initial_dive_done = true
	if (from_offset != 0.0):
		_set_dive_offset(from_offset)
	if (stats.submerged_sprite):
		sprite.texture = stats.submerged_sprite
	$HitboxComponent.submerged = true
	_apply_air_gun_state()
	_kill_dive_tween()
	_dive_tween = create_tween().set_parallel(true)
	_dive_tween.tween_method(_set_dive_offset, dive_offset, dive_depth, DIVE_TIME)
	_dive_tween.tween_property(sprite, "modulate", Color(0.3, 0.5, 0.85, 0.55), DIVE_TIME)

func _surface(stats : BoatStats) -> void:
	submerged = false
	if (stats.sprite):
		sprite.texture = stats.sprite
	$HitboxComponent.submerged = false
	_apply_air_gun_state()
	_kill_dive_tween()
	_dive_tween = create_tween().set_parallel(true)
	_dive_tween.tween_method(_set_dive_offset, dive_offset, NEAR_SURFACE_OFFSET, SURFACE_TIME)
	_dive_tween.tween_property(sprite, "modulate", NEAR_SURFACE_TINT, SURFACE_TIME)

func _kill_dive_tween() -> void:
	if (_dive_tween and _dive_tween.is_valid()):
		_dive_tween.kill()

func _apply_air_gun_state() -> void:
	var stats : BoatStats = entity_stats as BoatStats
	if (!stats or !stats.surfaces_for_air):
		return
	for gun : Gun in guns:
		var anti_air : bool = !gun.hits_surface
		gun.disabled = submerged if anti_air else !submerged
		gun.visible = anti_air and !submerged

func _update_surfacing(delta : float, stats : BoatStats) -> void:
	_surface_clock -= delta
	if (_surface_clock > 0.0):
		return
	_surface_clock = SURFACE_CHECK
	var radar : RadarComponent = get_node_or_null("RadarComponent") as RadarComponent
	if (!radar):
		return
	var air_target : bool = false
	var surface_threat : bool = false
	for item : Variant in radar.enemy_hitbox:
		var hitbox : SimpleHitboxComponent = item as SimpleHitboxComponent
		if (!is_instance_valid(hitbox) or !hitbox.enabled):
			continue
		var target : Node2D = hitbox.get_hitbox_parent()
		if (!target):
			continue
		var is_air : bool = target is Entity and (target as Entity).entity_stats is AirPlaneState
		for gun : Gun in guns:
			if (!gun.can_target(target) or gun.target_distance(target) > gun.effective_range()):
				continue
			if (is_air):
				air_target = true
			else:
				surface_threat = true
	var want_surface : bool = air_target and !surface_threat
	if (want_surface and submerged):
		_surface(stats)
	elif (!want_surface and !submerged):
		_dive(stats)
