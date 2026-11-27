class_name DockIndicator
extends Control

const DISPLAY_SHADER : Shader = preload("res://shaders/digital_panel.gdshader")
const TINT_SHADER : Shader = preload("res://shaders/unit_tint.gdshader")
const DOCK_ICONS : Dictionary = {
	BaseDock.Type.NAVAL: preload("res://assets/ui/icons/naval_12x12_v01.png"),
	BaseDock.Type.SUB: preload("res://assets/ui/icons/submarine_fleet_12x12_v05.png"),
	BaseDock.Type.AIR: preload("res://assets/ui/icons/airship_12x12_v03.png"),
}
const BOX : Vector2 = Vector2(96, 40)
const ART : Vector2 = Vector2(70, 32)
const EDGE_MARGIN : float = 8.0
const TOP_LIMIT : float = 160.0
const BOTTOM_LIMIT : float = 468.0
const SPACING : float = 46.0

var enemy_base : Base
var _cards : Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta : float) -> void:
	if (enemy_base == null or !is_instance_valid(enemy_base)):
		return
	visible = !get_tree().root.find_child("BattleIntro", true, false)
	if (!visible):
		return
	var canvas : Transform2D = get_viewport().get_canvas_transform()
	var width : float = get_viewport_rect().size.x
	var slot_y : float = -INF
	for dock_type : int in [BaseDock.Type.AIR, BaseDock.Type.NAVAL, BaseDock.Type.SUB]:
		var constructor : ShipConstructor = enemy_base.constructors.get(dock_type) as ShipConstructor
		var building : BoatStats = constructor.boat_stats if constructor else null
		var screen_pos : Vector2 = canvas * constructor.global_position if constructor else Vector2.ZERO
		var hidden_dock : bool = screen_pos.x > width
		if (building == null or !hidden_dock):
			if (_cards.has(dock_type)):
				(_cards[dock_type]["root"] as Control).visible = false
			continue
		var card : Dictionary = _card_for(dock_type)
		var root : Control = card["root"]
		root.visible = true
		var y : float = maxf(clampf(screen_pos.y - BOX.y * 0.5, TOP_LIMIT, BOTTOM_LIMIT), slot_y)
		slot_y = y + SPACING
		root.position = Vector2(width - BOX.x - EDGE_MARGIN, y)
		_update(card, dock_type, building, constructor)

func _card_for(dock_type : int) -> Dictionary:
	if (_cards.has(dock_type)):
		return _cards[dock_type]
	var palette : DisplayPalette = DisplayPalette.of_dock(dock_type as BaseDock.Type)
	var root : Control = Control.new()
	root.size = BOX
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var screen : ColorRect = ColorRect.new()
	screen.size = Vector2(BOX.x - 10, BOX.y)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material : ShaderMaterial = ShaderMaterial.new()
	material.shader = DISPLAY_SHADER
	palette.apply_screen(material)
	material.set_shader_parameter("rect_size", screen.size)
	screen.material = material
	root.add_child(screen)
	var dock_icon : TextureRect = _icon(DOCK_ICONS[dock_type], palette.light)
	dock_icon.position = Vector2(3, 3)
	dock_icon.size = Vector2(12, 12)
	root.add_child(dock_icon)
	var empty : TextureRect = _icon(null, palette.unloaded)
	empty.position = Vector2(15, 4)
	empty.size = ART
	root.add_child(empty)
	var clip : Control = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clip)
	var filled : TextureRect = _icon(null, palette.rest)
	filled.size = ART
	clip.add_child(filled)
	var arrow : Polygon2D = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(0, 0), Vector2(8, 7), Vector2(0, 14)])
	arrow.color = palette.rest
	arrow.position = Vector2(BOX.x - 8, BOX.y * 0.5 - 7)
	root.add_child(arrow)
	_cards[dock_type] = {"root": root, "empty": empty, "clip": clip, "filled": filled, "unit": ""}
	return _cards[dock_type]

func _icon(texture : Texture2D, tint : Color) -> TextureRect:
	var rect : TextureRect = TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.clip_contents = true
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material : ShaderMaterial = ShaderMaterial.new()
	material.shader = TINT_SHADER
	material.set_shader_parameter("tint", tint)
	rect.material = material
	return rect

func _update(card : Dictionary, _dock_type : int, building : BoatStats, constructor : ShipConstructor) -> void:
	var empty : TextureRect = card["empty"]
	var filled : TextureRect = card["filled"]
	var clip : Control = card["clip"]
	if (str(card["unit"]) != building.name):
		card["unit"] = building.name
		var texture : Texture2D = UnitIcon.of(building)
		empty.texture = texture
		filled.texture = texture
	var shader : ShaderMaterial = constructor.material as ShaderMaterial
	var raw : Variant = shader.get_shader_parameter("build_progress") if shader else 0.0
	var progress : float = clampf(float(raw) if raw != null else 0.0, 0.0, 1.0)
	var art_height : float = minf(float(empty.texture.get_height()), ART.y) if empty.texture else ART.y
	var art_bottom : float = floorf((ART.y + art_height) * 0.5)
	var height : float = roundf(art_height * progress)
	var top : float = art_bottom - height
	clip.position = empty.position + Vector2(0, top)
	clip.size = Vector2(ART.x, height)
	filled.position = Vector2(0, -top)
