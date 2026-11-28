class_name BattleAlert
extends PanelContainer

const NODE_NAME : String = "ThreatWarning"
const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")
const DISPLAY_SHADER : Shader = preload("res://shaders/digital_panel.gdshader")
const TINT_SHADER : Shader = preload("res://shaders/unit_tint.gdshader")
const THREAT : Color = Color("#dfa0a2")
const ALLY : Color = Color("#78dddd")
const OBJECTIVE : Color = Color("#ecc078")
const FACE : Color = Color("#202b31")
const WELL_SIZE : Vector2 = Vector2(128, 64)
const MIN_WIDTH : float = 440.0
const TOP : float = 80.0
const SECONDS : float = 3.0
const FADE : float = 0.5

static func show_on(parent : Node, title : String, body : String = "", stats : EntityStats = null) -> BattleAlert:
	var old : Node = parent.get_node_or_null(NODE_NAME)
	if (old != null):
		parent.remove_child(old)
		old.queue_free()
	var alert : BattleAlert = BattleAlert.new()
	alert.name = NODE_NAME
	alert._build(title, body, stats)
	parent.add_child(alert)
	alert._center()
	alert.resized.connect(alert._center)
	var tween : Tween = alert.create_tween()
	tween.tween_interval(SECONDS)
	tween.tween_property(alert, "modulate:a", 0.0, FADE)
	tween.tween_callback(alert.queue_free)
	return alert

static func box(edge : Color, margin : int) -> StyleBoxFlat:
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FACE
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(margin)
	style.anti_aliasing = false
	return style

static func display(stats : EntityStats, palette : DisplayPalette, size : Vector2) -> PanelContainer:
	var well : PanelContainer = PanelContainer.new()
	var frame : StyleBoxFlat = box(Color("#172127"), 1)
	frame.bg_color = Color("#4d6069")
	well.add_theme_stylebox_override("panel", frame)
	well.custom_minimum_size = size
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var screen : ColorRect = ColorRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material : ShaderMaterial = ShaderMaterial.new()
	material.shader = DISPLAY_SHADER
	palette.apply_screen(material)
	screen.material = material
	screen.resized.connect(func() -> void: material.set_shader_parameter("rect_size", screen.size))
	well.add_child(screen)
	var art : TextureRect = TextureRect.new()
	art.texture = UnitIcon.of(stats)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint : ShaderMaterial = ShaderMaterial.new()
	tint.shader = TINT_SHADER
	tint.set_shader_parameter("tint", palette.rest)
	art.material = tint
	well.add_child(art)
	return well

static func title_label(text : String, size : int, color : Color) -> Label:
	var label : Label = Label.new()
	label.text = text.to_upper()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _build(title : String, body : String, stats : EntityStats) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size.x = MIN_WIDTH
	add_theme_stylebox_override("panel", box(THREAT, 12))
	var row : HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	if (stats != null):
		row.add_child(display(stats, DisplayPalette.of_threat(), WELL_SIZE))
	var texts : VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("separation", 8)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	texts.add_child(title_label(title, 16, THREAT))
	if (body != ""):
		var description : Label = Label.new()
		description.text = body
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		description.add_theme_font_size_override("font_size", 8)
		description.add_theme_color_override("font_color", Color("#eaf3f5"))
		PixelText.describe(description)
		texts.add_child(description)

func _center() -> void:
	position = Vector2((get_viewport_rect().size.x - size.x) * 0.5, TOP).floor()
