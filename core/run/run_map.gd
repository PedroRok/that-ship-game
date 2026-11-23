class_name RunMap
extends RefCounted

var nodes : Array[Dictionary] = []
var edges : Dictionary = {}

static func node_id(col : int, row : int) -> int:
	return col * RunData.ROWS + row

static func generate(seed_value : int) -> RunMap:
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var map : RunMap = RunMap.new()
	map._build_nodes(rng)
	map._build_edges(rng)
	return map

func get_node(id : int) -> Dictionary:
	return nodes[id]

func column_of(id : int) -> int:
	return int(nodes[id]["col"])

func next_ids(id : int) -> Array[int]:
	var result : Array[int] = []
	for target : Variant in edges.get(id, []):
		result.append(int(target))
	return result

func first_ids() -> Array[int]:
	var result : Array[int] = []
	for row : int in RunData.ROWS:
		result.append(node_id(0, row))
	return result

func has_path_to_boss(from_id : int) -> bool:
	if (from_id == RunData.BOSS_ID):
		return true
	for target : int in next_ids(from_id):
		if (has_path_to_boss(target)):
			return true
	return false

func _build_nodes(rng : RandomNumberGenerator) -> void:
	nodes.clear()
	for col : int in RunData.COLUMNS:
		for row : int in RunData.ROWS:
			nodes.append({
				"id": node_id(col, row), "col": col, "row": row,
				"type": _roll_type(rng, col),
				"objective": RunData.Objective.DESTROY_BASE,
				"weather": RunData.Weather.CLEAR,
				"event_id": &"", "done": false, "used": [],
			})
	_apply_guarantees(rng)
	nodes.append({
		"id": RunData.BOSS_ID, "col": RunData.COLUMNS, "row": 1,
		"type": RunData.NodeType.BOSS, "objective": RunData.Objective.DEFEAT_BOSS,
		"weather": _roll_weather(rng), "event_id": &"", "done": false, "used": [],
	})
	for entry : Dictionary in nodes:
		_decorate(entry, rng)

func _roll_type(rng : RandomNumberGenerator, col : int) -> int:
	var roll : float = rng.randf()
	if (col == 0):
		return RunData.NodeType.EVENT if roll < 0.25 else RunData.NodeType.BATTLE
	if (roll < 0.52):
		return RunData.NodeType.BATTLE
	if (roll < 0.66):
		return RunData.NodeType.ELITE
	if (roll < 0.82):
		return RunData.NodeType.SHIPYARD
	return RunData.NodeType.EVENT

func _apply_guarantees(rng : RandomNumberGenerator) -> void:
	var battles : int = 0
	for row : int in RunData.ROWS:
		if (nodes[node_id(0, row)]["type"] == RunData.NodeType.BATTLE):
			battles += 1
	var row : int = 0
	while (battles < 2 and row < RunData.ROWS):
		var entry : Dictionary = nodes[node_id(0, row)]
		if (entry["type"] != RunData.NodeType.BATTLE):
			entry["type"] = RunData.NodeType.BATTLE
			battles += 1
		row += 1
	_ensure_type(rng, RunData.NodeType.SHIPYARD, 2, 3)
	_ensure_type(rng, RunData.NodeType.ELITE, 1, 3)
	_ensure_type(rng, RunData.NodeType.EVENT, 1, 3)
	for col : int in range(1, RunData.COLUMNS):
		var has_battle : bool = false
		for r : int in RunData.ROWS:
			if (nodes[node_id(col, r)]["type"] == RunData.NodeType.BATTLE):
				has_battle = true
		if (!has_battle):
			nodes[node_id(col, rng.randi_range(0, RunData.ROWS - 1))]["type"] = RunData.NodeType.BATTLE

func _ensure_type(rng : RandomNumberGenerator, node_type : int, min_col : int, max_col : int) -> void:
	for col : int in range(min_col, max_col + 1):
		for row : int in RunData.ROWS:
			if (nodes[node_id(col, row)]["type"] == node_type):
				return
	var col : int = rng.randi_range(min_col, max_col)
	nodes[node_id(col, rng.randi_range(0, RunData.ROWS - 1))]["type"] = node_type

func _decorate(entry : Dictionary, rng : RandomNumberGenerator) -> void:
	var node_type : int = entry["type"]
	entry["weather"] = _roll_weather(rng)
	if (node_type == RunData.NodeType.BATTLE or node_type == RunData.NodeType.ELITE):
		var objectives : Array[int] = RunData.BATTLE_OBJECTIVES
		entry["objective"] = objectives[rng.randi_range(0, objectives.size() - 1)]
	elif (node_type == RunData.NodeType.EVENT):
		var event : Dictionary = RunData.EVENTS[rng.randi_range(0, RunData.EVENTS.size() - 1)]
		entry["event_id"] = event["id"]

func _roll_weather(rng : RandomNumberGenerator) -> int:
	var total : float = 0.0
	for weather : int in RunData.WEATHER_WEIGHTS:
		total += float(RunData.WEATHER_WEIGHTS[weather])
	var pick : float = rng.randf() * total
	for weather : int in RunData.WEATHER_WEIGHTS:
		pick -= float(RunData.WEATHER_WEIGHTS[weather])
		if (pick <= 0.0):
			return weather
	return RunData.Weather.CLEAR

func _build_edges(rng : RandomNumberGenerator) -> void:
	edges.clear()
	for col : int in range(RunData.COLUMNS - 1):
		for row : int in RunData.ROWS:
			var targets : Array[int] = [node_id(col + 1, row)]
			for diag : int in [row - 1, row + 1]:
				if (diag >= 0 and diag < RunData.ROWS and rng.randf() < 0.5):
					targets.append(node_id(col + 1, diag))
			edges[node_id(col, row)] = targets
		for next_row : int in RunData.ROWS:
			var target : int = node_id(col + 1, next_row)
			var reached : bool = false
			for row : int in RunData.ROWS:
				if (edges[node_id(col, row)].has(target)):
					reached = true
			if (!reached):
				var source_row : int = clampi(next_row + (1 if rng.randf() < 0.5 else -1), 0, RunData.ROWS - 1)
				edges[node_id(col, source_row)].append(target)
	for row : int in RunData.ROWS:
		edges[node_id(RunData.COLUMNS - 1, row)] = [RunData.BOSS_ID]

func to_dict() -> Dictionary:
	var out_nodes : Array = []
	for entry : Dictionary in nodes:
		var copy : Dictionary = entry.duplicate()
		copy["event_id"] = str(entry["event_id"])
		out_nodes.append(copy)
	var out_edges : Dictionary = {}
	for id : Variant in edges:
		out_edges[str(id)] = edges[id]
	return {"nodes": out_nodes, "edges": out_edges}

static func from_dict(data : Dictionary) -> RunMap:
	var map : RunMap = RunMap.new()
	for raw : Variant in data.get("nodes", []):
		var entry : Dictionary = raw
		var node : Dictionary = {
			"id": int(entry["id"]), "col": int(entry["col"]), "row": int(entry["row"]),
			"type": int(entry["type"]), "objective": int(entry["objective"]),
			"weather": int(entry["weather"]), "event_id": StringName(str(entry.get("event_id", ""))),
			"done": bool(entry.get("done", false)), "used": [],
		}
		for used : Variant in entry.get("used", []):
			node["used"].append(str(used))
		map.nodes.append(node)
	var raw_edges : Dictionary = data.get("edges", {})
	for key : Variant in raw_edges:
		var targets : Array[int] = []
		for target : Variant in raw_edges[key]:
			targets.append(int(target))
		map.edges[int(str(key))] = targets
	return map

func is_valid() -> bool:
	if (nodes.size() != RunData.BOSS_ID + 1):
		return false
	for id : int in first_ids():
		if (!has_path_to_boss(id)):
			return false
	return true
