class_name ShipConstructor
extends Sprite2D


signal ship_build_finish(boat_stats : BoatStats)

var boat_stats : BoatStats

var exit_marker : Node2D
var prefer_submerged_sprite : bool = false
var floor_y : float = NAN
var hold_until_released : bool = false

const HELI_PAD_OFFSET : float = 60.0

var _bar : BuildBar
var _home_x : float = NAN
var _tween : Tween

func _ready() -> void:
	if (Engine.is_editor_hint()):
		return
	texture = null
	_bar = BuildBar.new()
	_bar.constructor = self
	add_child(_bar)

func _foot_offset() -> float:
	if (!texture):
		return 9.5
	var img : Image = texture.get_image()
	var used : Rect2i = img.get_used_rect()
	if (used.size == Vector2i.ZERO):
		return texture.get_height() * 0.5
	return used.end.y - texture.get_height() * 0.5

func is_building() -> bool:
	return boat_stats != null

func spawn_position() -> Vector2:
	return exit_marker.global_position if exit_marker else global_position

func build_ship(boat_stats : BoatStats, time_mult : float = 1.0) -> void:
	if (is_nan(_home_x)):
		_home_x = position.x
	var pad : float = HELI_PAD_OFFSET if boat_stats is HelicopterStats else 0.0
	position.x = _home_x + (-pad if flip_h else pad)
	if (boat_stats.is_boss):
		texture = null
	elif (boat_stats is AirPlaneState):
		var plane : AirPlaneState = boat_stats as AirPlaneState
		texture = plane.body_frames[0] if !plane.body_frames.is_empty() else plane.sprite
	elif (prefer_submerged_sprite and boat_stats.submerged_sprite):
		texture = boat_stats.submerged_sprite
	else:
		texture = boat_stats.sprite
	if (!is_nan(floor_y)):
		position.y = floor_y - _foot_offset()
	if (_bar):
		_bar.setup_for(boat_stats)
	material.set_shader_parameter("build_progress", 0.0)
	_tween = create_tween()
	var tween : Tween = _tween
	tween.tween_property(
			material,
			"shader_parameter/build_progress",
			1.0,
			boat_stats.produce_cd * time_mult
		)
	tween.finished.connect(Callable(self, "_on_build_complete"))
	self.boat_stats = boat_stats
	if (!boat_stats.is_boss):
		BattleAudio.start_build(self)

func cancel_build() -> BoatStats:
	if (boat_stats == null):
		return null
	var cancelled : BoatStats = boat_stats
	if (_tween):
		_tween.kill()
		_tween = null
	boat_stats = null
	texture = null
	material.set_shader_parameter("build_progress", 0.0)
	BattleAudio.stop_build(self)
	return cancelled

func _exit_tree() -> void:
	BattleAudio.stop_build(self)

func _on_build_complete() -> void:
	BattleAudio.stop_build(self)
	var finished : BoatStats = boat_stats
	boat_stats = null
	if (!hold_until_released):
		texture = null
	ship_build_finish.emit(finished)

func release_ship() -> void:
	texture = null
