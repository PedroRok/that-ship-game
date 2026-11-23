class_name BaseDock
extends Node2D

enum Type { NAVAL, AIR, SUB }

const DOCK_SCALE : int = 2
const WATER_Z : int = 268
const FILL_TIME : float = 1.4
const DOOR_TIME : float = 0.7
const EXIT_WAIT : float = 0.9
const EXIT_DISTANCE : float = 220.0
const WATER_SHADER : Shader = preload("res://shaders/water_body.gdshader")
const WATER_TEXTURE : Texture2D = preload("res://assets/game/misc/water.png")
const DOOR_SHADER_CODE : String = """
shader_type canvas_item;
uniform float open : hint_range(0.0, 1.0) = 0.0;
uniform float door_top = 0.2;
uniform float door_bottom = 0.75;
void fragment() {
	float shift = open * (door_bottom - door_top);
	if (UV.y > door_bottom) { discard; }
	COLOR = texture(TEXTURE, vec2(UV.x, UV.y - shift));
	if (UV.y - shift < 0.0) { COLOR.a = 0.0; }
}
"""
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
var busy : bool = false
var _hole_rect : Vector4 = Vector4.ZERO
var _hole_param : String = ""
var _sea_material : ShaderMaterial
var _door : Sprite2D
var _water : Sprite2D
var _water_mat : ShaderMaterial
var _door_mat : ShaderMaterial
var _tween : Tween
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

	var cutout_tex : Texture2D = load(def["cutout"])
	_cutout = cutout_tex.get_image()

	if (def["door"] != ""):
		_setup_door_and_water(def, center)

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
	constructor.hold_until_released = (type == Type.SUB)
	var mat : ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("build_progress", 0.0)
	mat.set_shader_parameter("block_size", 3)
	constructor.material = mat
	add_child(constructor)
	set_active(false)

func set_active(value : bool) -> void:
	active = value
	visible = value
	if (_sea_material and _hole_param != ""):
		_sea_material.set_shader_parameter(_hole_param, _hole_rect if value else Vector4.ZERO)

func _exit_tree() -> void:
	if (_sea_material and _hole_param != ""):
		_sea_material.set_shader_parameter(_hole_param, Vector4.ZERO)

func _find_sea_material() -> ShaderMaterial:
	var polygon : Node = get_tree().root.find_child("Water_Polygon", true, false)
	if (polygon is Polygon2D):
		return (polygon as Polygon2D).material as ShaderMaterial
	return null

func has_door() -> bool:
	return _door != null

func _setup_door_and_water(def : Dictionary, center : Vector2) -> void:
	var door : Sprite2D = _make_sprite(def["door"], center, 969)
	var door_tex : Texture2D = door.texture
	var door_used : Rect2i = door_tex.get_image().get_used_rect()
	var w : float = float(_cutout.get_width())
	var h : float = float(_cutout.get_height())

	# Interior da doca limitado à face interna da porta: depois dela é o mar de verdade.
	var inner : Image = _cutout.duplicate()
	inner.convert(Image.FORMAT_RGBA8)
	for x : int in range(door_used.end.x, inner.get_width()):
		for y : int in inner.get_height():
			inner.set_pixel(x, y, Color.TRANSPARENT)
	var inner_tex : ImageTexture = ImageTexture.create_from_image(inner)
	var cut_used : Rect2i = inner.get_used_rect()

	# Preenchimento seco sob o fundo da doca (cobre a abertura até a porta).
	var dry : Sprite2D = _make_sprite_tex(inner_tex, center, -716)
	dry.modulate = Color(0.07, 0.1, 0.12)
	_visual_sources[dry] = inner_tex

	# O mar principal (z 200) cobriria a doca: abre um buraco nele sobre o interior da doca.
	var sx : float = -1.0 if mirrored else 1.0
	var x_a : float = center.x + (cut_used.position.x - w * 0.5) * DOCK_SCALE * sx
	var x_b : float = center.x + (cut_used.end.x - w * 0.5) * DOCK_SCALE * sx
	var y_a : float = center.y + (cut_used.position.y - h * 0.5) * DOCK_SCALE
	var y_b : float = center.y + (cut_used.end.y - h * 0.5) * DOCK_SCALE
	var origin : Vector2 = global_position
	_hole_rect = Vector4(origin.x + minf(x_a, x_b), origin.y + y_a, origin.x + maxf(x_a, x_b), origin.y + y_b)
	_sea_material = _find_sea_material()
	if (_sea_material):
		var used : int = int(_sea_material.get_meta("holes_used", 0))
		_hole_param = "hole%d" % used
		_sea_material.set_meta("holes_used", used + 1)

	_water = _make_sprite_tex(inner_tex, center, WATER_Z)
	_water_mat = _make_water_material()
	_water_mat.set_shader_parameter("level", 0.0)
	var visible_rows : Vector2i = _visible_interior_rows(def["overlay"], cut_used)
	_water_mat.set_shader_parameter("top", visible_rows.x / h)
	_water_mat.set_shader_parameter("bottom", (visible_rows.y + 1) / h)
	_water.material = _water_mat
	_visual_sources[_water] = inner_tex

	_door = door
	_door_mat = _make_shader_material(DOOR_SHADER_CODE)
	_door_mat.set_shader_parameter("door_top", door_used.position.y / h)
	_door_mat.set_shader_parameter("door_bottom", door_used.end.y / h)
	_door.material = _door_mat
	_visual_sources[_door] = door_tex

# Linhas do interior que não ficam cobertas pela moldura do overlay (o nível da água usa só elas).
func _visible_interior_rows(overlay_path : String, cut_used : Rect2i) -> Vector2i:
	var overlay : Image = (load(overlay_path) as Texture2D).get_image()
	var column : int = cut_used.position.x + cut_used.size.x / 2
	var first : int = -1
	var last : int = -1
	for y : int in range(cut_used.position.y, cut_used.end.y):
		if (overlay.get_pixel(column, y).a < 0.1):
			if (first < 0):
				first = y
			last = y
	if (first < 0):
		return Vector2i(cut_used.position.y, cut_used.end.y - 1)
	return Vector2i(first, last)

# Mesmo shader e parâmetros do Water_Body principal (water_body.tscn).
func _make_water_material() -> ShaderMaterial:
	var noise : NoiseTexture2D = NoiseTexture2D.new()
	noise.noise = FastNoiseLite.new()
	var mat : ShaderMaterial = ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("refraction_map", noise)
	mat.set_shader_parameter("ocean_texture", WATER_TEXTURE)
	mat.set_shader_parameter("refraction_stretch", Vector2(1, 1))
	mat.set_shader_parameter("refraction_strength", 0.018)
	mat.set_shader_parameter("speed", 0.1)
	mat.set_shader_parameter("texture_strength", 0.583)
	mat.set_shader_parameter("water_tint", Color(0, 0.433333, 1, 0.796078))
	if (_sea_material):
		mat.set_shader_parameter("water_tint", _sea_material.get_shader_parameter("water_tint"))
		mat.set_shader_parameter("deep_amount", _sea_material.get_shader_parameter("deep_amount"))
	return mat

func _make_shader_material(code : String) -> ShaderMaterial:
	var shader : Shader = Shader.new()
	shader.code = code
	var mat : ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	return mat

func _restart_tween() -> Tween:
	if (_tween):
		_tween.kill()
	_tween = create_tween()
	return _tween

func begin_build() -> void:
	if (!_door):
		return
	busy = false
	_water_mat.set_shader_parameter("level", 0.0)
	_door_mat.set_shader_parameter("open", 0.0)

func open_for_exit() -> void:
	if (!_door):
		return
	busy = true
	var tween : Tween = _restart_tween()
	tween.tween_property(_water_mat, "shader_parameter/level", 1.0, FILL_TIME)
	tween.tween_property(_door_mat, "shader_parameter/open", 1.0, DOOR_TIME)
	await tween.finished

func close_after_exit(exit_time : float = EXIT_WAIT) -> void:
	if (!_door):
		return
	var tween : Tween = _restart_tween()
	tween.tween_interval(exit_time)
	tween.tween_property(_door_mat, "shader_parameter/open", 0.0, DOOR_TIME)
	tween.tween_callback(func() -> void: busy = false)
	tween.tween_property(_water_mat, "shader_parameter/level", 0.0, FILL_TIME)

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

func _make_sprite_tex(tex : Texture2D, pos : Vector2, z : int) -> Sprite2D:
	var sprite : Sprite2D = _make_sprite("", pos, z)
	sprite.texture = tex
	return sprite

func _make_sprite(path : String, pos : Vector2, z : int) -> Sprite2D:
	var sprite : Sprite2D = Sprite2D.new()
	if (path != ""):
		sprite.texture = load(path)
	sprite.position = pos
	sprite.scale = Vector2(DOCK_SCALE, DOCK_SCALE)
	sprite.flip_h = mirrored
	sprite.z_index = z
	add_child(sprite)
	return sprite

