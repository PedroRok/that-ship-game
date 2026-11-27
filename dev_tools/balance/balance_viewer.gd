extends Node2D

const SIZE : Vector2 = Vector2(1280, 720)
const LANE_Y : float = 300.0
const MARGIN : float = 90.0
const HISTORY : int = 600
const PLOT_SCALE : float = 5.0
const OBJECTIVES : Array[int] = [
	RunData.Objective.DESTROY_BASE, RunData.Objective.DEFEND, RunData.Objective.ESCORT,
	RunData.Objective.HUNT_SUBMARINE, RunData.Objective.SHOOT_DOWN_BOMBER, RunData.Objective.DEFEAT_BOSS,
]
const BUDGETS : Array[int] = [0, 150, 400, 900, 2500]
const SPEEDS : Array[float] = [1.0, 2.0, 5.0, 10.0, 25.0, 60.0]
const POLICIES : Array[String] = ["RANDOM", "COUNTER", "CHEAPEST"]
const ALLY : Color = Color("#5fc8ff")
const ENEMY : Color = Color("#ff6b6b")
const WARN : Color = Color("#ffcc55")
const MUTED : Color = Color("#8fa7b3")

var objective_index : int = 0
var floor_index : int = 1
var budget_index : int = 2
var policy_index : int = 1
var speed_index : int = 2
var seed_value : int = 1
var cap : int = 0
var paused : bool = false
var sim : BalanceSim
var snap : Dictionary = {}
var history : Array[int] = []
var history_allies : Array[int] = []
var carry : float = 0.0
var tick_count : int = 0
var font : Font
var mode : int = 0
var live : Array[Dictionary] = []
var grid_count : int = 4
var parallel : bool = true
var focus : int = 0
var poll_clock : float = 0.0
var tally : Dictionary = {"games": 0, "wins": 0}

func _ready() -> void:
	get_window().size = Vector2i(int(SIZE.x), int(SIZE.y))
	font = ThemeDB.fallback_font
	_restart()
	if ("real" in OS.get_cmdline_user_args()):
		mode = 1
		_poll_live()

func _restart() -> void:
	var scn : BalanceScenario = BalanceScenario.new()
	scn.objective = OBJECTIVES[objective_index]
	scn.floor_index = floor_index
	scn.gear_budget = BUDGETS[budget_index]
	scn.coin_budget = scn.gear_budget / 250
	scn.policy = policy_index as BalanceScenario.Policy
	scn.seed_value = seed_value
	scn.spawn_cap = cap
	scn.progress = BalanceProgress.build(Global.CATALOG, scn.gear_budget, scn.coin_budget)
	sim = BalanceSim.new()
	sim.begin(scn)
	snap = sim.snapshot()
	history.clear()
	history_allies.clear()
	carry = 0.0
	tick_count = 0

func _process(delta : float) -> void:
	poll_clock += delta
	if (mode == 1 and poll_clock >= 0.5):
		poll_clock = 0.0
		_poll_live()
	if (mode == 1):
		queue_redraw()
		return
	if (!paused and !sim.is_done()):
		carry += delta * SPEEDS[speed_index] / BalanceSim.DT
		var steps : int = mini(int(carry), 400)
		carry -= float(int(carry))
		for index : int in range(steps):
			var finished : bool = sim.step()
			tick_count += 1
			if (tick_count % 5 == 0):
				_record()
			if (finished):
				_on_done()
				break
		snap = sim.snapshot()
	queue_redraw()

func _record() -> void:
	var enemies : int = 0
	var allies : int = 0
	for unit : Dictionary in sim.snapshot()["units"]:
		if (bool(unit["ally"])):
			allies += 1
		else:
			enemies += 1
	history.append(enemies)
	history_allies.append(allies)
	if (history.size() > HISTORY):
		history.pop_front()
		history_allies.pop_front()

func _on_done() -> void:
	tally["games"] = int(tally["games"]) + 1
	if (bool(sim.result()["won"])):
		tally["wins"] = int(tally["wins"]) + 1

func _unhandled_key_input(event : InputEvent) -> void:
	var key : InputEventKey = event as InputEventKey
	if (key == null or !key.pressed):
		return
	match key.keycode:
		KEY_SPACE:
			paused = !paused
		KEY_M:
			mode = 1 - mode
			_poll_live()
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
		KEY_UP:
			speed_index = mini(speed_index + 1, SPEEDS.size() - 1)
		KEY_DOWN:
			speed_index = maxi(speed_index - 1, 0)
		KEY_O:
			objective_index = (objective_index + 1) % OBJECTIVES.size()
			_new_game()
		KEY_F:
			floor_index = (floor_index + 1) % 4
			_new_game()
		KEY_G:
			budget_index = (budget_index + 1) % BUDGETS.size()
			_new_game()
		KEY_P:
			policy_index = (policy_index + 1) % POLICIES.size()
			_new_game()
		KEY_C:
			cap = 0 if cap >= 12 else (8 if cap == 0 else 12)
			_new_game()
		KEY_R:
			seed_value += 1
			_restart()
		KEY_ESCAPE:
			get_tree().quit()

func _new_game() -> void:
	tally = {"games": 0, "wins": 0}
	_restart()

func _x(world_x : float) -> float:
	return MARGIN + (world_x / maxf(float(snap["distance"]), 1.0)) * (SIZE.x - 2.0 * MARGIN)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("#0b1419"))
	if (mode == 1):
		_draw_real()
		return
	if (snap.is_empty()):
		return
	draw_line(Vector2(MARGIN, LANE_Y), Vector2(SIZE.x - MARGIN, LANE_Y), Color("#2a4a5a"), 2.0)
	_draw_base(MARGIN - 40.0, float(snap["ally_hp"]), ALLY)
	_draw_base(SIZE.x - MARGIN + 40.0, float(snap["enemy_hp"]), ENEMY)
	if (float(snap["beacon"]) >= 0.0):
		draw_arc(Vector2(_x(float(snap["beacon"])), LANE_Y), 28.0, 0.0, TAU, 32, WARN, 2.0)
	_draw_shots()
	var allies : int = 0
	var enemies : int = 0
	for unit : Dictionary in snap["units"]:
		_draw_unit(unit)
		if (bool(unit["ally"])):
			allies += 1
		else:
			enemies += 1
	_draw_hud(allies, enemies)
	_draw_history()

func _unit_pos(x : float, ally : bool, air : bool) -> Vector2:
	var pos : Vector2 = Vector2(_x(x), LANE_Y + 26.0 if ally else LANE_Y - 26.0)
	if (air):
		pos.y += 46.0 if ally else -46.0
	return pos

func _draw_shots() -> void:
	var latest : Array[String] = []
	for shot : Dictionary in snap["shots"]:
		var ally : bool = bool(shot["ally"])
		var from : Vector2 = _unit_pos(float(shot["fx"]), ally, false)
		if (shot["shooter"] == "base_turret"):
			from = Vector2(_x(float(shot["fx"])), LANE_Y - 70.0)
		var to : Vector2 = Vector2(_x(float(shot["tx"])), LANE_Y)
		if (shot["target"] != "base"):
			to = _unit_pos(float(shot["tx"]), !ally, bool(shot["air"]))
		var color : Color = Color(0.4, 0.8, 1.0, 0.55) if ally else Color(1.0, 0.45, 0.45, 0.55)
		draw_line(from, to, color, 1.5)
		latest.append("%s -> %s  %.1f" % [shot["shooter"], shot["target"], float(shot["dmg"])])
	var y : float = 150.0
	for index : int in range(maxi(latest.size() - 5, 0), latest.size()):
		_text(Vector2(SIZE.x - 330.0, y), latest[index], MUTED, 13)
		y += 16.0

func _draw_base(x : float, fraction : float, color : Color) -> void:
	draw_rect(Rect2(x - 22.0, LANE_Y - 60.0, 44.0, 60.0), color.darkened(0.5))
	draw_rect(Rect2(x - 22.0, LANE_Y - 76.0, 44.0 * fraction, 8.0), color)
	draw_rect(Rect2(x - 22.0, LANE_Y - 76.0, 44.0, 8.0), Color(1, 1, 1, 0.35), false, 1.0)

func _draw_unit(unit : Dictionary) -> void:
	var ally : bool = bool(unit["ally"])
	var color : Color = ALLY if ally else ENEMY
	var radius : float = 6.0 + (8.0 if bool(unit["boss"]) else 0.0)
	var pos : Vector2 = Vector2(_x(float(unit["x"])), LANE_Y + 26.0 if ally else LANE_Y - 26.0)
	if (bool(unit["air"])):
		pos.y += 46.0 if ally else -46.0
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -radius), pos + Vector2(radius, radius), pos + Vector2(-radius, radius)]), color)
	elif (bool(unit["sub"])):
		var submerged : bool = bool(unit["submerged"])
		pos.y += 12.0 if submerged else 0.0
		var sub_color : Color = color.darkened(0.45) if submerged else color
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -radius), pos + Vector2(radius, 0), pos + Vector2(0, radius), pos + Vector2(-radius, 0)]), sub_color)
	else:
		draw_circle(pos, radius, color)
	if (bool(unit["escort"])):
		draw_arc(pos, radius + 4.0, 0.0, TAU, 20, WARN, 2.0)
	draw_rect(Rect2(pos.x - 8.0, pos.y + radius + 2.0, 16.0 * float(unit["hp"]), 2.0), Color.WHITE)

func _text(pos : Vector2, text : String, color : Color = Color.WHITE, size : int = 16) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _draw_hud(allies : int, enemies : int) -> void:
	var entry : Dictionary = RunData.OBJECTIVES[OBJECTIVES[objective_index]]
	_text(Vector2(20, 28), "%s  floor %d  gears %d  policy %s  seed %d  cap %s" % [
		entry["icon"], floor_index, BUDGETS[budget_index], POLICIES[policy_index], seed_value, str(cap) if cap > 0 else "off"], Color.WHITE, 18)
	var limit : String = "" if float(snap["time_limit"]) <= 0.0 else " / %.0f" % float(snap["time_limit"])
	_text(Vector2(20, 54), "t %.0fs%s   wave %d   screws %d   threat %.0f" % [float(snap["t"]), limit, int(snap["wave"]) + 1, int(snap["screws"]), float(snap["threat"])])
	_text(Vector2(20, 76), "allies %d (built %d)   ENEMIES %d (built %d)   %s" % [allies, int(snap["ally_spawned"]), enemies, int(snap["enemy_spawned"]), snap["objective_text"]], WARN if enemies >= 15 else Color.WHITE)
	_text(Vector2(20, 98), "loadout: %s" % ", ".join(PackedStringArray(snap["loadout"])), MUTED, 14)
	_text(Vector2(20, 120), "base hp: ally %d%%   enemy %d%%" % [int(float(snap["ally_hp"]) * 100.0), int(float(snap["enemy_hp"]) * 100.0)], MUTED, 14)
	if (bool(snap["done"])):
		var won : bool = bool(snap["won"])
		_text(Vector2(SIZE.x * 0.5 - 150.0, 180.0), "%s (%s)" % ["VICTORY" if won else "DEFEAT", snap["reason"]], Color("#78dddd") if won else Color("#dfa0a2"), 30)
		_text(Vector2(SIZE.x * 0.5 - 120.0, 210.0), "press R for next seed", MUTED)
	_text(Vector2(20, SIZE.y - 14), "SPACE pause  UP/DOWN speed x%.0f  O objective  F floor  G gears  P policy  C enemy cap  R new seed  ESC quit   |   session: %d/%d wins" % [SPEEDS[speed_index], int(tally["wins"]), int(tally["games"])], MUTED, 13)
	_text(Vector2(MARGIN, LANE_Y + 90.0), "blue = ally, red = enemy.  circle = ship, triangle = plane, diamond = submarine (dark = submerged), big = boss, yellow ring = escort", Color("#5a7886"), 13)

func _draw_history() -> void:
	var origin : Vector2 = Vector2(MARGIN, SIZE.y - 60.0)
	var width : float = SIZE.x - 2.0 * MARGIN
	var height : float = 220.0
	draw_rect(Rect2(origin.x, origin.y - height, width, height), Color(1, 1, 1, 0.04))
	_text(Vector2(origin.x, origin.y - height - 6.0), "units alive over time (red enemies, blue allies; yellow line = 15)", MUTED, 13)
	draw_line(Vector2(origin.x, origin.y - 15.0 * PLOT_SCALE), Vector2(origin.x + width, origin.y - 15.0 * PLOT_SCALE), Color(1, 0.8, 0.3, 0.25), 1.0)
	_plot(history, origin, width, ENEMY)
	_plot(history_allies, origin, width, ALLY)

func _plot(series : Array[int], origin : Vector2, width : float, color : Color) -> void:
	if (series.size() < 2):
		return
	var points : PackedVector2Array = PackedVector2Array()
	for index : int in range(series.size()):
		points.append(Vector2(origin.x + width * float(index) / float(HISTORY - 1), origin.y - minf(float(series[index]) * PLOT_SCALE, 220.0)))
	draw_polyline(points, color, 2.0)

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
	_text(Vector2(20, 26), "REAL BATTLES (separate game processes)   workers found: %d   showing: %s   M = back to simulator" % [
		live.size(), ("%d in parallel" % mini(grid_count, live.size())) if parallel else "1 (worker %d)" % [focus % maxi(live.size(), 1)]], Color.WHITE, 16)
	_text(Vector2(20, SIZE.y - 14), "TAB parallel on/off   - / = panels shown   LEFT/RIGHT worker (when parallel is off)   M simulator   ESC quit", MUTED, 13)
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
