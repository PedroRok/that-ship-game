class_name WeatherLayer
extends CanvasLayer

const DIR : String = "res://assets/ui/weather/"
const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")

var weather : int = RunData.Weather.CLEAR
var rain : RainEmitter
var fog : TextureRect
var flash : TextureRect
var _flash_clock : float = 4.0

func setup(new_weather : int, behind : CanvasLayer) -> void:
	weather = new_weather
	layer = behind.layer
	follow_viewport_enabled = false
	name = "WeatherLayer"
	if (weather == RunData.Weather.STORM):
		rain = RainEmitter.new()
		flash = _overlay(load(DIR + "lightning_flash_v01.png") as Texture2D)
		flash.modulate.a = 0.0
	if (weather == RunData.Weather.FOG or weather == RunData.Weather.STORM):
		fog = _overlay(load(DIR + "fog_edges_v01.png") as Texture2D)
	set_process(flash != null)

func _ready() -> void:
	if (rain):
		get_parent().add_child.call_deferred(rain)

func _notification(what : int) -> void:
	if (what == NOTIFICATION_PREDELETE and is_instance_valid(rain) and !rain.is_inside_tree()):
		rain.free()

func _overlay(texture : Texture2D) -> TextureRect:
	var rect : TextureRect = TextureRect.new()
	rect.texture = texture
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect

func _process(delta : float) -> void:
	if (flash):
		_flash_clock -= delta
		if (_flash_clock <= 0.0):
			_flash_clock = randf_range(6.0, 12.0)
			var tween : Tween = create_tween()
			tween.tween_property(flash, "modulate:a", 1.0, 0.05)
			tween.tween_property(flash, "modulate:a", 0.0, 0.35)

static func create_panel(kind : int, text_width : float) -> PanelContainer:
	var data : Dictionary = RunData.WEATHER[kind]
	var panel : PanelContainer = PanelContainer.new()
	panel.name = "WeatherPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var style : StyleBoxTexture = MenuBackground.make_box()
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var icon : TextureRect = TextureRect.new()
	icon.texture = RunData.weather_icon(kind)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)
	var title : Label = _panel_label(Loc.t("battle.weather") % Loc.t(str(data["name"])), Color("#eaf3f5"), text_width)
	box.add_child(title)
	var effect : Label = _panel_label(Loc.t(str(data["text"])), Color("#a3bec8"), text_width)
	PixelText.describe(effect)
	box.add_child(effect)
	return panel

static func _panel_label(text : String, color : Color, width : float) -> Label:
	var label : Label = Label.new()
	label.text = text.to_upper()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	return label
