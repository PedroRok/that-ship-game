class_name MapNodeButton
extends Button

signal activated(id : int)

const FONT : Font = preload("res://assets/fonts/dogicabold.ttf")

var run : RunState
var node_id : int = -1
var support : TextureRect
var glyph : TextureRect
var overlay : TextureRect
var checkmark : TextureRect
var corners : TextureRect
var marker : TextureRect
var caption : Label

func setup(new_run : RunState, id : int) -> void:
	run = new_run
	node_id = id
	custom_minimum_size = Vector2(MapChart.NODE_SIZE, MapChart.NODE_SIZE)
	size = custom_minimum_size
	flat = true
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var empty : StyleBoxEmpty = StyleBoxEmpty.new()
	for style : String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)
	support = _rect(Vector2.ZERO, Vector2(48, 48))
	glyph = _rect(Vector2(8, 8), Vector2(32, 32))
	overlay = _rect(Vector2(36, 36), Vector2(16, 16))
	checkmark = _rect(Vector2(32, 32), Vector2(16, 16))
	corners = _rect(Vector2(-12, -12), Vector2(72, 72))
	marker = _rect(Vector2(16, -14), Vector2(16, 8))
	marker.texture = load("res://assets/ui/run_map/current_marker_v01.png") as Texture2D
	checkmark.texture = load("res://assets/ui/run_map/checkmark_v01.png") as Texture2D
	caption = Label.new()
	caption.add_theme_font_override("font", FONT)
	caption.add_theme_font_size_override("font_size", 8)
	caption.position = Vector2(-26, 52)
	caption.size = Vector2(100, 14)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	for signal_name : Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited]:
		signal_name.connect(refresh)
	pressed.connect(func() -> void: activated.emit(node_id))

func _rect(pos : Vector2, rect_size : Vector2) -> TextureRect:
	var rect : TextureRect = TextureRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(rect)
	return rect

func refresh() -> void:
	var entry : Dictionary = run.map.get_node(node_id)
	var node_type : int = int(entry["type"])
	var state : String = run.node_state(node_id)
	var is_focus : bool = node_id == run.focus_node
	var hover_look : bool = state == "normal" and (is_focus or is_hovered() or has_focus())
	support.texture = load("res://assets/ui/run_map/node_base_%s_v01.png" % ("hover" if hover_look else state)) as Texture2D
	glyph.texture = RunData.node_glyph(node_type, "hover" if hover_look else state)
	var shows_overlay : bool = node_type == RunData.NodeType.BATTLE or node_type == RunData.NodeType.ELITE
	overlay.visible = shows_overlay
	if (shows_overlay):
		overlay.texture = RunData.objective_overlay(int(entry["objective"]))
	checkmark.visible = state == "done"
	marker.visible = state == "current"
	corners.visible = state == "current" or (is_focus and state == "normal")
	if (state == "current"):
		corners.texture = load("res://assets/ui/run_map/corners_current_v01.png") as Texture2D
	else:
		corners.texture = load("res://assets/ui/run_map/corners_target_v01.png") as Texture2D
	if (state == "current"):
		caption.text = "run.position"
		caption.add_theme_color_override("font_color", Color("#78dddd"))
	elif (is_focus and state == "normal"):
		caption.text = "run.selected"
		caption.add_theme_color_override("font_color", Color("#ecc078"))
	else:
		caption.text = ""
	disabled = false
	tooltip_text = "%s (%s)" % [Loc.t(RunData.NODE_NAMES[node_type]), state]
