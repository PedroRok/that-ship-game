extends Node2D

const SIZE : Vector2 = Vector2(1280, 720)
const OBJECTIVES : Array[int] = [
	RunData.Objective.DESTROY_BASE, RunData.Objective.DEFEND, RunData.Objective.ESCORT,
	RunData.Objective.HUNT_SUBMARINE, RunData.Objective.SHOOT_DOWN_BOMBER, RunData.Objective.DEFEAT_BOSS,
]
const ALLY : Color = Color("#5fc8ff")
const ENEMY : Color = Color("#ff6b6b")
const WARN : Color = Color("#ffcc55")
const MUTED : Color = Color("#8fa7b3")

var font : Font
var live : Array[Dictionary] = []
var grid_count : int = 4
var parallel : bool = true
var focus : int = 0
var poll_clock : float = 0.0

func _ready() -> void:
	get_window().size = Vector2i(int(SIZE.x), int(SIZE.y))
	font = ThemeDB.fallback_font
	_poll_live()

func _process(delta : float) -> void:
	poll_clock += delta
	if (poll_clock >= 0.5):
		poll_clock = 0.0
		_poll_live()
	queue_redraw()

func _unhandled_key_input(event : InputEvent) -> void:
	var key : InputEventKey = event as InputEventKey
	if (key == null or !key.pressed):
		return
	match key.keycode:
		KEY_TAB:
			parallel = !parallel
		KEY_MINUS:
			grid_count = maxi(grid_count - 1, 1)
		KEY_EQUAL:
			grid_count = mini(grid_count + 1, 16)
		KEY_RIGHT:
			focus += 1
		KEY_LEFT:
			focus = maxi(focus - 1, 0)
		KEY_ESCAPE:
			get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("#0b1419"))
	_draw_real()

func _text(pos : Vector2, text : String, color : Color = Color.WHITE, size : int = 16) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _poll_live() -> void:
	live.clear()
	for index : int in range(16):
		var path : String = "res://extras/balance_reports/real_probe_live_%d.json" % index
		if (!FileAccess.file_exists(path)):
			continue
		var parsed : Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if (parsed is Dictionary):
			live.append(parsed as Dictionary)

func _draw_real() -> void:
	_text(Vector2(20, 26), "REAL BATTLES (separate game processes)   workers found: %d   showing: %s" % [
		live.size(), ("%d in parallel" % mini(grid_count, live.size())) if parallel else "1 (worker %d)" % [focus % maxi(live.size(), 1)]], Color.WHITE, 16)
	_text(Vector2(20, SIZE.y - 14), "TAB parallel on/off   - / = panels shown   LEFT/RIGHT worker (when parallel is off)   ESC quit", MUTED, 13)
	if (live.is_empty()):
		_text(Vector2(20, 80), "No real probe is running. Start extras\real_probe_parallel.bat, then come back here.", WARN, 18)
		return
	var shown : Array[Dictionary] = []
	if (parallel):
		for index : int in range(mini(grid_count, live.size())):
			shown.append(live[index])
	else:
		shown.append(live[focus % live.size()])
	var columns : int = int(ceil(sqrt(float(shown.size()))))
	var rows_n : int = int(ceil(float(shown.size()) / float(columns)))
	var area : Rect2 = Rect2(10, 40, SIZE.x - 20, SIZE.y - 70)
	var cell : Vector2 = Vector2(area.size.x / columns, area.size.y / rows_n)
	for index : int in range(shown.size()):
		var origin : Vector2 = area.position + Vector2(float(index % columns) * cell.x, float(index / columns) * cell.y)
		_draw_panel(shown[index], Rect2(origin + Vector2(4, 4), cell - Vector2(8, 8)))

func _draw_panel(data : Dictionary, box : Rect2) -> void:
	draw_rect(box, Color(1, 1, 1, 0.04))
	draw_rect(box, Color("#2a4a5a"), false, 1.0)
	var small : bool = box.size.y < 230.0
	var size_text : int = 12 if small else 15
	var line : float = 16.0 if small else 20.0
	var running : bool = str(data["state"]) == "running"
	var mix : Dictionary = data["mix"]
	_text(box.position + Vector2(8, line), "W%d  %s  %s" % [int(data["worker"]), data["label"], "[" + str(data["progress"]) + "]"], Color.WHITE if running else Color("#78dddd"), size_text)
	if (running):
		_text(box.position + Vector2(8, line * 2.0), "t %.0fs  enemies %d (peak %d)  air %d sub %d surf %d  base %d/%d" % [
			float(data["t"]), int(data["enemies"]), int(data["peak"]), int(mix.get("air", 0)), int(mix.get("sub", 0)), int(mix.get("surface", 0)),
			int(data["base_hp"]), int(data["base_max"])], WARN if int(data["enemies"]) >= 15 else MUTED, size_text)
	var lane_y : float = box.position.y + box.size.y * 0.5
	var left : float = box.position.x + 20.0
	var width : float = box.size.x - 40.0
	draw_line(Vector2(left, lane_y), Vector2(left + width, lane_y), Color("#2a4a5a"), 1.5)
	draw_rect(Rect2(left - 14.0, lane_y - 22.0, 12.0, 22.0), ALLY.darkened(0.5))
	draw_rect(Rect2(left + width + 2.0, lane_y - 22.0, 12.0, 22.0), ENEMY.darkened(0.5))
	for unit : Array in data["units"]:
		var ally : bool = int(unit[1]) == 1
		var kind : int = int(unit[2])
		var pos : Vector2 = Vector2(left + float(unit[0]) * width, lane_y + (12.0 if ally else -12.0))
		var color : Color = ALLY if ally else ENEMY
		if (kind == 1):
			pos.y += 14.0 if ally else -14.0
			draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -4), pos + Vector2(4, 4), pos + Vector2(-4, 4)]), color)
		elif (kind == 2):
			var dark : Color = color.darkened(0.45) if int(unit[3]) == 1 else color
			pos.y += 6.0 if int(unit[3]) == 1 else 0.0
			draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -4), pos + Vector2(4, 0), pos + Vector2(0, 4), pos + Vector2(-4, 0)]), dark)
		else:
			draw_circle(pos, 3.5, color)
	var y : float = lane_y + 44.0
	for text : String in data["finished"]:
		if (y > box.position.y + box.size.y - 6.0):
			break
		_text(Vector2(box.position.x + 8.0, y), text, Color("#8fa7b3") if text.contains("WON") else Color("#c98a8a"), 11 if small else 12)
		y += 14.0
