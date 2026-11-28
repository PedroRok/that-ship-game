class_name RainEmitter
extends Node2D

const DROPS_PER_WIDTH : float = 1.5
const NEAR_SHARE : float = 0.45
const SPLASH_SHARE : float = 0.18
const BASE_SPLASH_SHARE : float = 0.8
const BASE_HIT_HEIGHT : float = 8.0
const BASE_SPLASH_ALPHA : float = 0.85
const SIDE_MARGIN : float = 20.0
const TOP_MARGIN : float = 10.0
const MARCH_STEP : float = 4.0
const COLUMN : float = 2.0
const TONE_LIGHTEN : float = 0.45
const FAR_DARKEN : float = 0.15
const NEAR_ALPHA : float = 0.55
const FAR_ALPHA : float = 0.3
const SPLASH_ALPHA : float = 0.6
const NEAR_LENGTH : float = 8.0
const FAR_LENGTH : float = 5.0

var _drops : float = 0.0
var _clock : float = 0.0
var _splashes : Array[Vector3] = []
var _roofs : Dictionary = {}
var _roof_span : Vector2 = Vector2(INF, -INF)
var _mapped : bool = false
var _water : WaterBody

func _process(delta : float) -> void:
	var view : Rect2 = _view()
	if (!view.has_area()):
		return
	if (!_mapped):
		_map_surfaces()
	_clock += delta
	_release_splashes()
	_drops += delta * view.size.x * GameSettings.effects_scale() * DROPS_PER_WIDTH
	var fall : Vector2 = GrainParticles.RAIN_FALL
	var drift : float = -fall.x / fall.y * maxf(ShipEntity.WATER_LEVEL - view.position.y, 0.0)
	var width : float = 1.0 / get_viewport().get_camera_2d().zoom.x
	var tone : Color = AirPuff.tint.lightened(TONE_LIGHTEN)
	while (_drops >= 1.0):
		_drops -= 1.0
		var from : Vector2 = Vector2(randf_range(view.position.x - SIDE_MARGIN, view.end.x + drift + SIDE_MARGIN),
				view.position.y - randf_range(0.0, TOP_MARGIN))
		var near : bool = randf() < NEAR_SHARE
		var length : float = NEAR_LENGTH if near else FAR_LENGTH
		var hit : Vector2 = landing(from)
		var seconds : float = (hit.y - length * 0.5 - from.y) / fall.y
		if (seconds <= 0.0):
			continue
		GrainParticles.raindrop(self, from, Vector2(width, length), tone if near else tone.darkened(FAR_DARKEN),
				NEAR_ALPHA if near else FAR_ALPHA, seconds)
		if (randf() < (BASE_SPLASH_SHARE if _on_base(hit.y) else SPLASH_SHARE)):
			_splashes.append(Vector3(hit.x, hit.y, _clock + seconds))

func landing(from : Vector2) -> Vector2:
	var slope : float = GrainParticles.RAIN_FALL.x / GrainParticles.RAIN_FALL.y
	var water_x : float = from.x + slope * (ShipEntity.WATER_LEVEL - from.y)
	if (maxf(from.x, water_x) >= _roof_span.x and minf(from.x, water_x) <= _roof_span.y):
		var y : float = from.y
		while (y < ShipEntity.WATER_LEVEL):
			var x : float = from.x + slope * (y - from.y)
			var roof : float = _roofs.get(floori(x / COLUMN), INF)
			if (y >= roof):
				return Vector2(x, y)
			y += MARCH_STEP
	var wave : float = _water.surface_offset(water_x) if _water else 0.0
	return Vector2(water_x, ShipEntity.WATER_LEVEL + wave)

func _release_splashes() -> void:
	var tone : Color = AirPuff.tint.lightened(TONE_LIGHTEN)
	var waiting : Array[Vector3] = []
	for splash : Vector3 in _splashes:
		if (splash.z > _clock):
			waiting.append(splash)
		else:
			GrainParticles.rain_splash(self, Vector2(splash.x, splash.y), tone, BASE_SPLASH_ALPHA if _on_base(splash.y) else SPLASH_ALPHA)
	_splashes = waiting

func _on_base(height : float) -> bool:
	return height < ShipEntity.WATER_LEVEL - BASE_HIT_HEIGHT

func _map_surfaces() -> void:
	_mapped = true
	_water = get_parent().get_node_or_null("Environment/Water_Body") as WaterBody
	var context : BattleContext = BattleContext.of(self)
	if (context == null):
		return
	for base : Base in context.bases:
		for sprite : Sprite2D in base.solid_sprites():
			_map_sprite(sprite)

func _map_sprite(sprite : Sprite2D) -> void:
	if (!sprite.texture or !sprite.is_visible_in_tree()):
		return
	var image : Image = sprite.texture.get_image()
	if (image.is_compressed()):
		image.decompress()
	var origin : Vector2 = sprite.offset - (Vector2(image.get_size()) * 0.5 if sprite.centered else Vector2.ZERO)
	var step : int = maxi(floori(COLUMN / absf(sprite.global_scale.x)), 1)
	for x : int in range(0, image.get_width(), step):
		for y : int in range(0, image.get_height(), step):
			if (image.get_pixel(image.get_width() - 1 - x if sprite.flip_h else x, y).a < 0.5):
				continue
			var world : Vector2 = sprite.to_global(origin + Vector2(x, y))
			var column : int = floori(world.x / COLUMN)
			_roofs[column] = minf(_roofs.get(column, INF), world.y)
			_roof_span = Vector2(minf(_roof_span.x, world.x), maxf(_roof_span.y, world.x))
			break

func _view() -> Rect2:
	var camera : Camera2D = get_viewport().get_camera_2d()
	if (camera == null):
		return Rect2()
	var size : Vector2 = get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)
