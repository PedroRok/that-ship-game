class_name BattleInfoPanel
extends Control

const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")
const ORIGIN : Vector2 = Vector2(12, 50)
const HOLD_KEY : Key = KEY_TAB
const SEGMENTS : int = 10
const FADE_SECONDS : float = 0.5
const WEATHER_SECONDS : float = 5.0
const MISSION_WIDTH : float = 200.0
const BLOCKER_GROUP : StringName = &"hud_blocker"

var objective_hud : ObjectiveHud
var roster : EnemyRosterPanel
var weather : int = RunData.Weather.CLEAR

var _compact : HBoxContainer
var _details : VBoxContainer
var _name : Label
var _percent : Label
var _segments : Array[TextureRect] = []
var _rival_segments : Array[TextureRect] = []
var _mouse_held : bool = false
var _after_intro : bool = false
var _notice : PanelContainer
var _notice_shown : bool = false

static func create(hud : ObjectiveHud, enemy_roster : EnemyRosterPanel) -> BattleInfoPanel:
	var panel : BattleInfoPanel = BattleInfoPanel.new()
	panel.objective_hud = hud
	panel.roster = enemy_roster
	return panel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = ORIGIN
	z_index = 50
	_build_compact()
	_details = VBoxContainer.new()
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_theme_constant_override("separation", 8)
	_details.add_child(objective_hud)
	_details.add_child(roster)
	_details.add_child(WeatherLayer.create_panel(weather, 320.0))
	_details.visible = false
	add_child(_details)
	_notice = WeatherLayer.create_panel(weather, 220.0)
	_notice.modulate.a = 0.0
	add_child(_notice)

func _build_compact() -> void:
	_compact = HBoxContainer.new()
	_compact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compact.add_theme_constant_override("separation", 4)
	add_child(_compact)
	var key_box : PanelContainer = _frame()
	key_box.mouse_filter = Control.MOUSE_FILTER_STOP
	key_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	key_box.add_to_group(BLOCKER_GROUP)
	key_box.gui_input.connect(_on_key_box_input)
	var key : Label = _label(8, Color("#eaf3f5"))
	key.text = Loc.t("battle.tab_key")
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_box.add_child(key)
	_compact.add_child(key_box)
	var mission : PanelContainer = _frame()
	_compact.add_child(mission)
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(MISSION_WIDTH, 0)
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	mission.add_child(row)
	var icon : TextureRect = TextureRect.new()
	icon.texture = RunData.objective_hud_icon(objective_hud.objective_id)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.add_child(box)
	var head : HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	_name = _label(8, Color("#eaf3f5"))
	_name.text = PixelText.fit(str(RunData.OBJECTIVES[objective_hud.objective_id]["name"]), 8)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.clip_text = true
	head.add_child(_name)
	_percent = _label(8, Color("#ecc078"))
	head.add_child(_percent)
	var bars : VBoxContainer = VBoxContainer.new()
	bars.add_theme_constant_override("separation", ObjectiveHud.PAIR_GAP)
	box.add_child(bars)
	var bar : HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	bars.add_child(bar)
	for index : int in range(SEGMENTS):
		var segment : TextureRect = TextureRect.new()
		segment.texture = objective_hud.empty
		segment.stretch_mode = TextureRect.STRETCH_SCALE
		segment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		segment.custom_minimum_size = Vector2(0, ObjectiveHud.PAIR_HEIGHT if objective_hud.has_rival() else float(objective_hud.empty.get_height()))
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(segment)
		_segments.append(segment)
	if (!objective_hud.has_rival()):
		return
	var rival : HBoxContainer = HBoxContainer.new()
	rival.add_theme_constant_override("separation", 0)
	bars.add_child(rival)
	for index : int in range(SEGMENTS):
		var segment : TextureRect = TextureRect.new()
		segment.texture = objective_hud.empty
		segment.stretch_mode = TextureRect.STRETCH_SCALE
		segment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		segment.custom_minimum_size = Vector2(0, ObjectiveHud.PAIR_HEIGHT)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rival.add_child(segment)
		_rival_segments.append(segment)

func _show_notice() -> void:
	var tween : Tween = _notice.create_tween()
	tween.tween_property(_notice, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_interval(WEATHER_SECONDS)
	tween.tween_property(_notice, "modulate:a", 0.0, FADE_SECONDS)

func _on_key_box_input(event : InputEvent) -> void:
	var click : InputEventMouseButton = event as InputEventMouseButton
	if (click and click.button_index == MOUSE_BUTTON_LEFT and click.pressed):
		_mouse_held = true

func _frame() -> PanelContainer:
	var panel : PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style : StyleBoxTexture = MenuBackground.make_box()
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(font_size : int, color : Color) -> Label:
	var label : Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _process(_delta : float) -> void:
	visible = !get_tree().root.find_child("BattleIntro", true, false)
	if (!visible):
		_after_intro = true
		modulate.a = 0.0
	elif (_after_intro):
		_after_intro = false
		create_tween().tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	_mouse_held = _mouse_held and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var held : bool = _mouse_held or Input.is_physical_key_pressed(HOLD_KEY)
	_details.visible = held
	_compact.visible = !held
	_notice.visible = !held
	_notice.position = Vector2(0, _compact.size.y + 8.0)
	if (visible and !_notice_shown):
		_notice_shown = true
		_show_notice()
	_percent.text = objective_hud.counter if objective_hud.counter != "" else "%d%%" % roundi(objective_hud.progress * 100.0)
	_name.add_theme_color_override("font_color", Color("#ecc078") if objective_hud.warning else Color("#eaf3f5"))
	var filled : int = roundi(objective_hud.progress * SEGMENTS)
	for index : int in range(SEGMENTS):
		_segments[index].texture = objective_hud.full if index < filled else objective_hud.empty
	var rival_filled : int = roundi(objective_hud.rival * SEGMENTS)
	for index : int in range(_rival_segments.size()):
		_rival_segments[index].texture = objective_hud.rival_full if index < rival_filled else objective_hud.empty
