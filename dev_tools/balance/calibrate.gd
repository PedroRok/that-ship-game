extends Node

const REAL_FILE : String = "res://extras/balance_reports/real_probe_latest.md"
const HIT_RATES : Array[float] = [0.2, 0.3, 0.4, 0.5, 0.65, 0.8]
const RUNS : int = 30

func _ready() -> void:
	var real : Array[Dictionary] = _parse()
	print("rows: %d" % real.size())
	for hit : float in HIT_RATES:
		var avg_error : float = 0.0
		var time_error : float = 0.0
		var agree : int = 0
		for row : Dictionary in real:
			var wins : int = 0
			var avg : float = 0.0
			var time_sum : float = 0.0
			for index : int in range(RUNS):
				var scn : BalanceScenario = BalanceScenario.new()
				scn.objective = int(row["objective"])
				scn.floor_index = int(row["floor"])
				scn.seed_value = 1000 + index
				scn.hit_rate = hit
				scn.progress = BalanceProgress.build(Global.CATALOG, int(row["gears"]), int(row["gears"]) / 250)
				var result : Dictionary = BalanceSim.new().run(scn)
				if (bool(result["won"])):
					wins += 1
				avg += float(result["avg_enemies"])
				time_sum += float(result["time"])
			avg /= RUNS
			time_sum /= RUNS
			avg_error += absf(avg - float(row["avg"]))
			time_error += absf(time_sum - float(row["time"]))
			var sim_win : bool = float(wins) / RUNS >= 0.5
			if (sim_win == bool(row["won"])):
				agree += 1
		print("hit_rate %.2f: avg enemy error %.1f, time error %.0f s, win agreement %d/%d" % [
			hit, avg_error / real.size(), time_error / real.size(), agree, real.size()])
	get_tree().quit()

func _parse() -> Array[Dictionary]:
	var rows : Array[Dictionary] = []
	var text : String = FileAccess.get_file_as_string(REAL_FILE)
	for line : String in text.split("
"):
		if (!line.begins_with("| ") or line.begins_with("| objective")):
			continue
		var cells : PackedStringArray = line.split("|", false)
		if (cells.size() < 11):
			continue
		var head : String = cells[0].strip_edges().split(" ")[0]
		if (!head.is_valid_int()):
			continue
		rows.append({"objective": int(head), "floor": int(cells[1]), "gears": int(cells[2]),
			"won": cells[3].strip_edges() == "yes", "time": float(cells[4]), "avg": float(cells[6])})
	return rows
