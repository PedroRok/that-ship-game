class_name BaseDock
extends Node2D

enum Type { NAVAL, AIR, SUB }

const DOCK_SCALE : int = 2
const DOOR_LIFT : float = 40.0
const USE_DOOR : bool = false
const SHADER : Shader = preload("res://shaders/construct_sprite_shader.gdshader")

const DEFS : Dictionary = {
	Type.AIR: {
		"center": Vector2(84, 236),
		"inner": Vector2(64, 234),
		"exit": Vector2(64, 234),
		"floor": 248.0,
		"bg": "res://assets/game/base/dock_air-1.png",
		"overlay": "res://assets/game/base/dock_air-overlay-1.png",
		"cutout": "res://assets/game/base/dock_air-cutout-1.png",
		"door": "",
	},
	Type.SUB: {
		"center": Vector2(80, 426),
		"inner": Vector2(85, 426),
		"exit": Vector2(85, 426),
		"bg": "res://assets/game/base/dock_sub-1.png",
		"overlay": "res://assets/game/base/dock_sub-overlay-1.png",
		"cutout": "res://assets/game/base/dock_sub-cutout-1.png",
		"door": "res://assets/game/base/dock_sub-door-1.png",
	},
}

var type : Type = Type.AIR
var mirrored : bool = false
var active : bool = false
var constructor : ShipConstructor
var exit_marker : Marker2D

var _background : Sprite2D
var _overlay : Sprite2D
var _door : Sprite2D
var _door_closed_y : float = 0.0
var _door_tween : Tween
var _cutout : Image
var _visual_sources : Dictionary[Sprite2D, Texture2D] = {}

func setup(dock_type : Type, is_mirrored : bool) -> void:
	type = dock_type
	mirrored = is_mirrored
	var def : Dictionary = DEFS[type]
	var sx : float = -1.0 if mirrored else 1.0
	var center : Vector2 = Vector2((def["center"] as Vector2).x * sx, (def["center"] as Vector2).y)

	_background = _make_sprite(def["bg"], center, -715)
	_overlay = _make_sprite(def["overlay"], center, 970)
	_visual_sources[_background] = _background.texture
	_visual_sources[_overlay] = _overlay.texture
	if (USE_DOOR and def["door"] != ""):
		_door = _make_sprite(def["door"], center, 969)
		_door_closed_y = center.y

	var cutout_tex : Texture2D = load(def["cutout"])
	_cutout = cutout_tex.get_image()

	exit_marker = Marker2D.new()
	exit_marker.position = Vector2((def["exit"] as Vector2).x * sx, (def["exit"] as Vector2).y)
	add_child(exit_marker)

	constructor = ShipConstructor.new()
	constructor.position = Vector2((def["inner"] as Vector2).x * sx, (def["inner"] as Vector2).y)
	constructor.flip_h = mirrored
	if (def.has("floor")):
		constructor.floor_y = def["floor"]
	else:
		constructor.exit_marker = exit_marker
	constructor.prefer_submerged_sprite = (type == Type.SUB)
	var mat : ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("build_progress", 0.0)
	mat.set_shader_parameter("block_size", 3)
	constructor.material = mat
	add_child(constructor)
	constructor.ship_build_finish.connect(_on_build_finish)
	set_active(false)

func set_active(value : bool) -> void:
	active = value
	visible = value

func schedule_door(build_time : float) -> void:
	if (!_door):
		return
	if (_door_tween):
		_door_tween.kill()
	_door.position.y = _door_closed_y
	_door_tween = create_tween()
	_door_tween.tween_interval(build_time * 0.85)
	_door_tween.tween_property(_door, "position:y", _door_closed_y - DOOR_LIFT, 0.3)

func _on_build_finish(_stats : BoatStats) -> void:
	if (!_door):
		return
	if (_door_tween):
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.tween_interval(0.6)
	_door_tween.tween_property(_door, "position:y", _door_closed_y, 0.3)

func cut_into(img : Image, silhouette : Image, base_pos : Vector2, flip : bool) -> void:
	var base_size : Vector2i = silhouette.get_size()
	var base_bounds : Rect2i = Rect2i(Vector2i.ZERO, base_size)
	var dock_size : Vector2i = _cutout.get_size() * DOCK_SCALE
	var origin : Vector2i = Vector2i((_background.position - base_pos
			+ Vector2(base_size - dock_size) * 0.5).floor())
	var mask : Image = _cutout.duplicate()
	mask.resize(dock_size.x, dock_size.y, Image.INTERPOLATE_NEAREST)

	var clipped_layers : Dictionary[Sprite2D, Image] = {}
	for sprite : Sprite2D in _visual_sources:
		var layer : Image = _visual_sources[sprite].get_image()
		layer.convert(Image.FORMAT_RGBA8)
		layer.resize(dock_size.x, dock_size.y, Image.INTERPOLATE_NEAREST)
		clipped_layers[sprite] = layer

	for y : int in dock_size.y:
		for x : int in dock_size.x:
			var dock_x : int = dock_size.x - 1 - x if mirrored else x
			var pixel : Vector2i = origin + Vector2i(dock_x, y)
			if (flip):
				pixel.x = base_size.x - 1 - pixel.x
			if (!base_bounds.has_point(pixel) or silhouette.get_pixelv(pixel).a == 0.0):
				for layer : Image in clipped_layers.values():
					layer.set_pixel(x, y, Color.TRANSPARENT)
			elif (mask.get_pixel(x, y).a > 0.0):
				img.set_pixelv(pixel, Color.TRANSPARENT)

	for sprite : Sprite2D in clipped_layers:
		sprite.texture = ImageTexture.create_from_image(clipped_layers[sprite])
		sprite.scale = Vector2.ONE

func _make_sprite(path : String, pos : Vector2, z : int) -> Sprite2D:
	var sprite : Sprite2D = Sprite2D.new()
	sprite.texture = load(path)
	sprite.position = pos
	sprite.scale = Vector2(DOCK_SCALE, DOCK_SCALE)
	sprite.flip_h = mirrored
	sprite.z_index = z
	add_child(sprite)
	return sprite
