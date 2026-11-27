class_name RunEndOverlay
extends CanvasLayer

const SLOW_SECONDS : float = 1.6
const MIN_TIME_SCALE : float = 0.05
const PANEL_SIZE := Vector2(340, 200)

var run : RunState
var _busy : bool = false
var _panel : Control
var _dim : ColorRect
var _back : Button

static func show_for(run_state : RunState, parent : Node) -> void:
	var overlay : RunEndOverlay = new()
	overlay.name = "RunEndOverlay"
	overlay.run = run_state
	parent.add_child(overlay)

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GearEntity.collect_visible(get_tree())
	var tween : Tween = create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(Engine, "time_scale", MIN_TIME_SCALE, SLOW_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dim, "modulate:a", 1.0, SLOW_SECONDS)
	tween.tween_property(_panel, "modulate:a", 1.0, SLOW_SECONDS * 0.6).set_delay(SLOW_SECONDS * 0.4)
	tween.chain().tween_callback(_on_settled)

func _on_settled() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = true
	_back.grab_focus()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if (is_inside_tree()):
		get_tree().paused = false

func _build() -> void:
	var style : PauseMenu = PauseMenu.new()
	var won : bool = run.result == RunData.Result.WON
	if (run.stage != RunData.Stage.ENDED):
		won = bool(run.node_result.get("success", false))
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.modulate.a = 0.0
	root.add_child(_dim)

	var stage := Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.offset_top = PauseMenu.BATTLE_TOP
	stage.offset_bottom = -PauseMenu.HUD_BOTTOM
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", style._box("panel_frame_v01.png", 16))
	panel.modulate.a = 0.0
	center.add_child(panel)
	_panel = panel
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var ended : bool = run.stage == RunData.Stage.ENDED
	var lines : Array[String] = []
	if (ended):
		var summary : Dictionary = run.end_summary
		box.add_child(style._header("run.run_won" if won else "run.run_lost", "icon_pause_v01.png" if won else "icon_alert_v01.png"))
		box.add_child(style._inset(_text(run.end_reason, TEXT_COLOR_OF(won), 40)))
		var mission_gears : int = int(run.node_result.get("gears", 0)) if won else 0
		lines = [Loc.t("run.gears") + ": +%d" % (int(summary.get("gears", 0)) + mission_gears),
				Loc.t("run.boss_coins") + ": +%d" % int(summary.get("boss_coins", 0)),
				Loc.t("run.floors") + ": %02d / %02d" % [int(summary.get("floors", 0)), RunData.COLUMNS]]
	else:
		var result : Dictionary = run.node_result
		var success : bool = bool(result.get("success", false))
		var offered : bool = bool(result.get("relic_offered", false))
		box.add_child(style._header("run.node_complete" if success else "run.objective_failed", "icon_pause_v01.png" if success else "icon_alert_v01.png"))
		var reason : String = "run.objective_complete_rewards_collected" if success \
				else Loc.t("run.the_objective_was_lost_the") % RunData.FAIL_BASE_DAMAGE
		box.add_child(style._inset(_text(reason, TEXT_COLOR_OF(success), 40)))
		lines = [Loc.t("run.screws_earned") + ": +%d" % int(result.get("screws", 0)),
				Loc.t("run.gears") + ": +%d" % int(result.get("gears", 0)),
				Loc.t("run.base_damage") + ": -%d HP" % int(result.get("damage", 0)),
				Loc.t("run.hp_left") % [run.base_hp, run.base_max_hp]]
		if (offered):
			lines.append(Loc.t("run.relic") + ": " + Loc.t("run.offer"))
	box.add_child(style._inset(style._divider(), 0))
	for line : String in lines:
		box.add_child(style._inset(_text(line, PauseMenu.TEXT_COLOR, 12)))
	box.add_child(style._inset(style._divider(), 0))
	var offered_relic : bool = !ended and bool(run.node_result.get("relic_offered", false))
	_back = style._button("run.back_to_menu" if ended else ("run.choose_relic" if offered_relic else "run.continue_to_map"), false)
	_back.pressed.connect(_on_back)
	box.add_child(style._inset(_back))
	style.free()

static func TEXT_COLOR_OF(won : bool) -> Color:
	return PauseMenu.TEXT_COLOR if won else PauseMenu.DANGER_COLOR

func _text(text : String, color : Color, min_height : float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PauseMenu.PIXEL_FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = min_height
	return label

func _on_back() -> void:
	if (_busy):
		return
	_busy = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	if (run.stage == RunData.Stage.ENDED):
		RunFlow.leave_to_menu()
		return
	run.continue_after_node()
	RunFlow.advance()
