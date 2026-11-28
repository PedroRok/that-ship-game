class_name BattleIntro
extends CanvasLayer

const DURATION : float = 10.0
const MISSION_DELAY : float = 1.0
const PANEL_STEP : float = 0.6
const LIST_DELAY : float = MISSION_DELAY + PANEL_STEP
const WEATHER_DELAY : float = LIST_DELAY + PANEL_STEP
const PANEL_FADE : float = 0.6
const ZOOM : float = 1.35
const SKIP_GUARD : float = 0.25
const SETTLE_FRAMES : int = 4
const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")
const CLOUD_FADE : float = 0.6
const RETURN_SECONDS : float = 1.6
const UI_FADE : float = 0.4
const MARKER_GAP : float = 100.0
const TINT_SHADER : Shader = preload("res://shaders/unit_tint.gdshader")

static var force_show : bool = false

var game_round : GameRound
var units : Array[BoatStats] = []
var boss : BoatStats
var objective : int = 0

var _time : float = 0.0
var _closed : bool = false
var _root : Control
var _mission : PanelContainer
var _panel : PanelContainer
var _weather : PanelContainer
var _markers : Array[Dictionary] = []
var _camera : GameCam
var _return_x : float = 0.0
var _return_zoom : float = 1.0
var _cloud_tween : Tween
var _fade_tween : Tween

static func should_show() -> bool:
	if (force_show):
		return true
	return DisplayServer.get_name() != "headless" and SaveManager.directory == "user://" and BattleLog.enabled()

static func show_for(round_node : GameRound, pool : Array[BoatStats], boss_unit : BoatStats, mission : int) -> BattleIntro:
	var intro : BattleIntro = BattleIntro.new()
	intro.name = "BattleIntro"
	intro.game_round = round_node
	intro.units = pool
	intro.boss = boss_unit
	intro.objective = mission
	round_node.add_child(intro)
	return intro

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.gui_input.connect(_on_input)
	add_child(_root)
	_root.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_root, "modulate:a", 1.0, UI_FADE)
	_build_markers()
	_build_panel()
	var skip : Label = _label("battle.intro_skip", 8, Color("#a3bec8"))
	skip.position = Vector2(440, 500)
	skip.size = Vector2(400, 16)
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(skip)
	_camera = game_round.camera
	if (_camera):
		_return_x = _camera.actual_h_pos
		_return_zoom = _camera.actual_zoom
		_camera.process_mode = Node.PROCESS_MODE_ALWAYS
		_camera.actual_zoom = ZOOM
		_camera.actual_h_pos = game_round.enemy_base.global_position.x
	_set_scenery(Node.PROCESS_MODE_ALWAYS)
	_fade_clouds(0.0, CLOUD_FADE)
	for index : int in range(SETTLE_FRAMES):
		await get_tree().process_frame
	if (!_closed):
		get_tree().paused = true

func _build_markers() -> void:
	var enemy : Base = game_round.enemy_base
	var present : Dictionary = {}
	var all : Array[BoatStats] = units.duplicate()
	if (boss):
		all.append(boss)
	for unit : BoatStats in all:
		present[Base.dock_type_of(unit)] = true
	var names : Dictionary = {BaseDock.Type.NAVAL: "battle.dock_naval", BaseDock.Type.AIR: "battle.dock_air",
		BaseDock.Type.SUB: "battle.dock_sub"}
	for dock_type : int in present:
		if (!enemy.constructors.has(dock_type)):
			continue
		var palette : DisplayPalette = DisplayPalette.of_dock(dock_type as BaseDock.Type)
		var marker : HBoxContainer = HBoxContainer.new()
		marker.add_theme_constant_override("separation", 6)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon : TextureRect = _tinted(DockIndicator.DOCK_ICONS[dock_type], palette.light)
		icon.custom_minimum_size = Vector2(24, 24)
		marker.add_child(icon)
		var title : Label = _label("", 16, palette.light)
		title.text = Loc.t(str(names[dock_type]))
		marker.add_child(title)
		var arrow : Control = Control.new()
		arrow.custom_minimum_size = Vector2(40, 24)
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shaft : ColorRect = ColorRect.new()
		shaft.color = palette.rest
		shaft.position = Vector2(2, 10)
		shaft.size = Vector2(28, 4)
		shaft.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.add_child(shaft)
		var head : Polygon2D = Polygon2D.new()
		head.polygon = PackedVector2Array([Vector2(28, 4), Vector2(40, 12), Vector2(28, 20)])
		head.color = palette.rest
		arrow.add_child(head)
		marker.add_child(arrow)
		_root.add_child(marker)
		_markers.append({"label": marker, "anchor": enemy.constructors[dock_type] as Node2D})

func _tinted(texture : Texture2D, tint : Color) -> TextureRect:
	var rect : TextureRect = TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material : ShaderMaterial = ShaderMaterial.new()
	material.shader = TINT_SHADER
	material.set_shader_parameter("tint", tint)
	rect.material = material
	return rect

func _build_panel() -> void:
	var column : VBoxContainer = VBoxContainer.new()
	column.position = BattleInfoPanel.ORIGIN
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	_root.add_child(column)
	_mission = _mission_panel()
	_mission.visible = false
	column.add_child(_mission)
	_panel = EnemyRosterPanel.create(units, boss)
	_panel.visible = false
	column.add_child(_panel)
	var kind : int = Global.run.battle_weather() if Global.run else RunData.Weather.CLEAR
	_weather = WeatherLayer.create_panel(kind, 320.0)
	_weather.visible = false
	column.add_child(_weather)

func _mission_panel() -> PanelContainer:
	var data : Dictionary = RunData.OBJECTIVES[objective]
	var panel : PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style : StyleBoxTexture = MenuBackground.make_box()
	style.set_content_margin_all(MenuBackground.MARGIN)
	panel.add_theme_stylebox_override("panel", style)
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading : Label = _label("", 8, Color("#ecc078"))
	heading.text = PixelText.fit("battle.your_mission", 8)
	box.add_child(heading)
	var head : HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var icon : TextureRect = TextureRect.new()
	icon.texture = RunData.objective_hud_icon(objective)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	head.add_child(_label(str(data["name"]), 16, Color("#eaf3f5")))
	var detail : Label = _label("", 8, Color("#a3bec8"))
	detail.text = PixelText.fit(str(data["text"]), 8)
	PixelText.describe(detail)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(360, 0)
	box.add_child(detail)
	return panel

func _label(text : String, size : int, color : Color) -> Label:
	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#090f15"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _process(delta : float) -> void:
	if (_closed):
		return
	_time += delta
	_reveal(_mission, MISSION_DELAY)
	_reveal(_panel, LIST_DELAY)
	_reveal(_weather, WEATHER_DELAY)
	var transform : Transform2D = get_viewport().get_canvas_transform()
	for marker : Dictionary in _markers:
		var label : Control = marker["label"]
		var anchor : Node2D = marker["anchor"]
		label.position = transform * anchor.global_position - Vector2(label.size.x + MARKER_GAP, label.size.y * 0.5)
	if (_time >= DURATION):
		close()

func _reveal(panel : Control, delay : float) -> void:
	panel.visible = _time >= delay
	panel.modulate.a = clampf((_time - delay) / PANEL_FADE, 0.0, 1.0)

func _on_input(event : InputEvent) -> void:
	var click : InputEventMouseButton = event as InputEventMouseButton
	if (click and click.pressed and _time >= SKIP_GUARD):
		close()

func _unhandled_key_input(event : InputEvent) -> void:
	if (event.is_pressed() and _time >= SKIP_GUARD):
		get_viewport().set_input_as_handled()
		close()

func _set_scenery(mode : Node.ProcessMode) -> void:
	var scenery : Node = game_round.get_node_or_null("Environment")
	if (scenery):
		scenery.process_mode = mode

func _clouds() -> ShaderMaterial:
	var layer : CanvasItem = game_round.get_node_or_null("Environment/CloudsFront") as CanvasItem
	return layer.material as ShaderMaterial if layer else null

func _set_cloud_fade(value : float, clouds : ShaderMaterial) -> void:
	clouds.set_shader_parameter("fade", value)

func _fade_clouds(alpha : float, seconds : float) -> void:
	var clouds : ShaderMaterial = _clouds()
	if (clouds):
		_cloud_tween = create_tween()
		_cloud_tween.tween_method(_set_cloud_fade.bind(clouds), 1.0, alpha, seconds)

func close() -> void:
	if (_closed):
		return
	_closed = true
	if (_fade_tween):
		_fade_tween.kill()
	var tween : Tween = create_tween().set_parallel(true)
	tween.tween_property(_root, "modulate:a", 0.0, UI_FADE)
	if (_cloud_tween):
		_cloud_tween.kill()
	var clouds : ShaderMaterial = _clouds()
	if (clouds):
		var current : Variant = clouds.get_shader_parameter("fade")
		tween.tween_method(_set_cloud_fade.bind(clouds), float(current) if current != null else 1.0, 1.0, RETURN_SECONDS)
	if (_camera):
		tween.tween_property(_camera, "actual_h_pos", _return_x, RETURN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_camera, "actual_zoom", _return_zoom, RETURN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		tween.tween_interval(RETURN_SECONDS)
	tween.chain().tween_callback(_finish)

func _finish() -> void:
	if (_camera):
		_camera.process_mode = Node.PROCESS_MODE_INHERIT
	_set_scenery(Node.PROCESS_MODE_INHERIT)
	get_tree().paused = false
	queue_free()
