class_name WeatherLayer
extends CanvasLayer

const DIR : String = "res://assets/ui/weather/"
const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")
const FRAME_TIME : float = 0.125

var weather : int = RunData.Weather.CLEAR
var rain : TextureRect
var fog : TextureRect
var flash : TextureRect
var rain_frames : Array[Texture2D] = []
var _frame : int = 0
var _frame_clock : float = 0.0
var _flash_clock : float = 4.0

func setup(new_weather : int, behind : CanvasLayer) -> void:
	weather = new_weather
	layer = behind.layer
	follow_viewport_enabled = false
	name = "WeatherLayer"
	if (weather == RunData.Weather.STORM):
		for i : int in range(1, 5):
			rain_frames.append(load("%srain_frame_%02d_v01.png" % [DIR, i]) as Texture2D)
		rain = _overlay(rain_frames[0])
		flash = _overlay(load(DIR + "lightning_flash_v01.png") as Texture2D)
		flash.modulate.a = 0.0
	if (weather == RunData.Weather.FOG or weather == RunData.Weather.STORM):
		fog = _overlay(load(DIR + "fog_edges_v01.png") as Texture2D)
	set_process(rain != null or flash != null)

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
	if (rain):
		_frame_clock += delta
		if (_frame_clock >= FRAME_TIME):
			_frame_clock = 0.0
			_frame = (_frame + 1) % rain_frames.size()
			rain.texture = rain_frames[_frame]
	if (flash):
		_flash_clock -= delta
		if (_flash_clock <= 0.0):
			_flash_clock = randf_range(6.0, 12.0)
			var tween : Tween = create_tween()
			tween.tween_property(flash, "modulate:a", 1.0, 0.05)
			tween.tween_property(flash, "modulate:a", 0.0, 0.35)

func show_banner(parent : CanvasLayer) -> void:
	var data : Dictionary = RunData.WEATHER[weather]
	var plate : PanelContainer = PanelContainer.new()
	var box : StyleBoxTexture = StyleBoxTexture.new()
	box.texture = load(DIR + "weather_banner_v01.png") as Texture2D
	for side : String in ["left", "right", "top", "bottom"]:
		box.set("texture_margin_" + side, 4)
	box.content_margin_left = 12
	box.content_margin_right = 16
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	plate.add_theme_stylebox_override("panel", box)
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon : TextureRect = TextureRect.new()
	icon.texture = RunData.weather_icon(weather)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)
	var label : Label = Label.new()
	label.text = Loc.t("battle.weather") % Loc.t(str(data["name"])).to_upper()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#eaf3f5"))
	row.add_child(label)
	var sub : Label = Label.new()
	sub.text = Loc.t(str(data["text"])).to_upper()
	sub.add_theme_font_override("font", load("res://assets/fonts/dogicapixel.ttf") as Font)
	sub.add_theme_font_size_override("font_size", 8)
	sub.add_theme_color_override("font_color", Color("#a3bec8"))
	row.add_child(sub)
	plate.add_child(row)
	parent.add_child(plate)
	plate.position = Vector2(640.0 - 250.0, 104.0)
	plate.modulate.a = 0.0
	var tween : Tween = plate.create_tween()
	tween.tween_property(plate, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.6)
	tween.tween_property(plate, "modulate:a", 0.0, 0.5)
	tween.tween_callback(plate.queue_free)
