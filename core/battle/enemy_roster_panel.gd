class_name EnemyRosterPanel
extends PanelContainer

const DISPLAY_SHADER : Shader = preload("res://shaders/digital_panel.gdshader")
const TINT_SHADER : Shader = preload("res://shaders/unit_tint.gdshader")
const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")
const COLUMNS : int = 5
const CARD : Vector2 = Vector2(110, 60)

var units : Array[BoatStats] = []
var boss : BoatStats

static func create(pool : Array[BoatStats], boss_unit : BoatStats) -> EnemyRosterPanel:
	var panel : EnemyRosterPanel = EnemyRosterPanel.new()
	panel.units = pool
	panel.boss = boss_unit
	return panel

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var style : StyleBoxTexture = MenuBackground.make_box()
	style.set_content_margin_all(MenuBackground.MARGIN)
	add_theme_stylebox_override("panel", style)
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(_label("battle.intro_title", 16, Color("#eaf3f5")))
	var grid : GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	if (boss):
		grid.add_child(_card(boss, true))
	for unit : BoatStats in units:
		grid.add_child(_card(unit, false))

func _card(unit : BoatStats, is_boss : bool) -> Control:
	var palette : DisplayPalette = DisplayPalette.of_unit(unit)
	var card : PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#172127")
	style.border_color = Color("#dfa0a2") if is_boss else palette.unloaded
	style.set_border_width_all(2 if is_boss else 1)
	style.set_content_margin_all(2)
	card.add_theme_stylebox_override("panel", style)
	var well : Control = Control.new()
	well.custom_minimum_size = CARD
	well.clip_contents = true
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(well)
	var screen : ColorRect = ColorRect.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var screen_material : ShaderMaterial = ShaderMaterial.new()
	screen_material.shader = DISPLAY_SHADER
	palette.apply_screen(screen_material)
	screen.resized.connect(func() -> void: screen_material.set_shader_parameter("rect_size", screen.size))
	screen.material = screen_material
	well.add_child(screen)
	var art : TextureRect = TextureRect.new()
	art.texture = UnitIcon.of(unit)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(4, 2)
	art.size = Vector2(102, 36)
	var art_material : ShaderMaterial = ShaderMaterial.new()
	art_material.shader = TINT_SHADER
	art_material.set_shader_parameter("tint", palette.rest)
	art.material = art_material
	well.add_child(art)
	var title : Label = _label("", 8, palette.text)
	title.text = Loc.t("battle.intro_boss") if is_boss else Loc.named("unit", unit.name).to_upper()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_constant_override("line_spacing", 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(2, 36)
	title.custom_minimum_size = Vector2(106, 24)
	well.add_child(title)
	title.size = Vector2(106, 24)
	return card

func _label(text : String, font_size : int, color : Color) -> Label:
	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#090f15"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
