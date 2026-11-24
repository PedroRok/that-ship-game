@tool
class_name ShipEntity
extends Entity

const DIVE_DEPTH : float = 75.0
const DIVE_TIME : float = 4.5

@onready
var sprite: Sprite2D = $BoatSprite

var dive_depth : float = DIVE_DEPTH
var submerged : bool = false
var dive_offset : float = 0.0
var _spawn_x : float = NAN

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
	if (submerged):
		return
	var stats : BoatStats = entity_stats as BoatStats
	if (!stats or !stats.can_submerge or !is_nan(entry_x)):
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
	if (from_offset != 0.0):
		_set_dive_offset(from_offset)
	if (stats.submerged_sprite):
		sprite.texture = stats.submerged_sprite
	$HitboxComponent.submerged = true
	var tween : Tween = create_tween().set_parallel(true)
	tween.tween_method(_set_dive_offset, from_offset, dive_depth, DIVE_TIME)
	tween.tween_property(sprite, "modulate", Color(0.3, 0.5, 0.85, 0.55), DIVE_TIME)
