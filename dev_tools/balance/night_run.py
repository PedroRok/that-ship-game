import ctypes
import glob
import json
import os
import random
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GODOT = r"D:\Program Files\Godot_v4.6-beta2_mono_win64\Godot_v4.6-stable_win64_console.exe"
OUT = os.path.join(ROOT, "extras", "balance_reports", "night_2026-11-27")
ARENA = os.path.join(ROOT, "extras", "balance_reports", "arena")
DUEL = os.path.join(ROOT, "extras", "balance_reports", "duel")
WORKERS = 10
START = time.time()

UNITS = ["mini", "small", "torpedo", "medium", "destroyer", "frigate", "tank", "cruiser", "flak", "plane", "interceptor",
         "missile_plane", "bomber", "twin_bomber", "heli_scout", "heli_heavy", "sub_scout", "submarine", "sub_hunter",
         "sub_sam"]
STANDARD = ["early", "navy", "air", "deep"]
CURATED = [
    ["torpedo", "plane", "bomber", "flak", "destroyer", "interceptor"],
    ["interceptor", "bomber", "twin_bomber", "flak", "torpedo", "plane"],
    ["plane", "heli_scout", "heli_heavy", "interceptor", "flak", "mini"],
    ["interceptor", "missile_plane", "bomber", "heli_scout", "flak", "torpedo"],
    ["sub_scout", "submarine", "sub_hunter", "sub_sam", "plane", "torpedo"],
    ["destroyer", "frigate", "tank", "cruiser", "flak", "mini"],
    ["mini", "small", "torpedo", "medium", "destroyer", "flak"],
    ["torpedo", "mini", "plane", "flak", "sub_scout", "destroyer"],
    ["flak", "destroyer", "bomber", "submarine", "interceptor", "torpedo"],
    ["sub_sam", "destroyer", "torpedo", "bomber", "plane", "mini"],
    ["bomber", "plane", "mini", "small", "torpedo", "flak"],
    ["heli_scout", "plane", "destroyer", "flak", "torpedo", "frigate"],
]


def log(text):
    line = "[%6.1f min] %s" % ((time.time() - START) / 60.0, text)
    print(line, flush=True)
    with open(os.path.join(OUT, "progress.log"), "a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def left(deadline_minutes):
    return START + deadline_minutes * 60.0 - time.time()


def launch(scene, extra, log_dir, name, timeout):
    procs = []
    for shard in range(WORKERS):
        handle = open(os.path.join(log_dir, "%s_%d.log" % (name, shard)), "a", encoding="utf-8", errors="ignore")
        args = [GODOT, "--headless", "--fixed-fps", "60", "--path", ROOT, scene, "--",
                "shard=%d/%d" % (shard, WORKERS)] + extra
        procs.append((subprocess.Popen(args, stdout=handle, stderr=subprocess.STDOUT), handle))
    end = time.time() + max(timeout, 30.0)
    cut = False
    for proc, handle in procs:
        try:
            proc.wait(timeout=max(end - time.time(), 1.0))
        except subprocess.TimeoutExpired:
            cut = True
            proc.kill()
        handle.close()
    return cut


def rows_of(tag):
    result = []
    for path in glob.glob(os.path.join(ARENA, tag, "rows_*.json")):
        try:
            with open(path, encoding="utf-8") as handle:
                result += json.load(handle)
        except (OSError, ValueError):
            pass
    return result


def arena(tag, fleets, objectives, floors, bots, deadline, params=None, seeds=1, seed0=0):
    if left(deadline) < 45.0:
        log("skip %s (no time)" % tag)
        return []
    folder = os.path.join(ARENA, tag)
    os.makedirs(folder, exist_ok=True)
    extra = ["tag=" + tag, "ai=current", "bot=" + ",".join(bots), "fleet=" + ",".join(fleets),
             "obj=" + ",".join(map(str, objectives)), "floors=" + ",".join(map(str, floors)),
             "seeds=%d" % seeds, "seed0=%d" % seed0]
    if params:
        extra.append("params=" + params.replace("\\", "/"))
    cut = launch("res://dev_tools/balance/ai_arena.tscn", extra, folder, "worker", left(deadline))
    rows = rows_of(tag)
    log("%s: %d battles%s" % (tag, len(rows), " (cut by time)" if cut else ""))
    return rows


def duels(deadline):
    singles = []
    for index, first in enumerate(UNITS):
        for second in UNITS[index + 1:]:
            singles.append("%s:%s" % (first, second))
    teams = ["interceptor+bomber", "plane+bomber", "flak+destroyer", "flak+torpedo", "interceptor+missile_plane",
             "heli_scout+plane", "heli_heavy+interceptor", "sub_sam+sub_hunter", "destroyer+torpedo",
             "plane+torpedo", "bomber+torpedo", "frigate+flak", "cruiser+flak", "mini+torpedo", "submarine+torpedo"]
    combos = []
    for index, first in enumerate(teams):
        for second in teams[index + 1:]:
            combos.append("%s:%s" % (first, second))
    for tag, pairs, value in [("n60", singles, 60), ("n120", singles, 120), ("nteam", combos, 120)]:
        if left(deadline) < 60.0:
            log("skip duels " + tag)
            continue
        path = os.path.join(OUT, "pairs_%s.txt" % tag)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(",".join(pairs))
        cut = launch("res://dev_tools/balance/unit_duel.tscn",
                     ["tag=" + tag, "value=%d" % value, "pairsfile=" + path.replace("\\", "/")], OUT, "duel_" + tag,
                     left(deadline))
        log("duels %s done%s" % (tag, " (cut by time)" if cut else ""))


def fitness(rows):
    if not rows:
        return 0.0
    return sum(float(r["won"]) + 0.25 * (1.0 - r["enemy_hp"]) + 0.15 * r["ally_hp"] for r in rows) / len(rows)


BOUNDS = {"decide": (0.25, 1.5), "review": (6.0, 60.0), "switch": (-0.05, 0.3), "buys": (1, 5), "patience": (1.0, 4.0),
          "patience_front": (0.2, 0.9), "urgent_share": (0.05, 0.8), "noise": (0.0, 0.8), "price_exp": (0.1, 1.2),
          "health_exp": (0.1, 1.2), "siege": (0.0, 1.5), "counter_bias": (0.0, 0.3), "bomb_value": (6.0, 40.0),
          "boost_screws": (4.0, 40.0), "anti_air": (0.5, 3.0), "anti_sub": (0.5, 3.0), "escort_air": (0.3, 2.5)}
DEFAULTS = {"decide": 0.5, "review": 18.0, "switch": 0.04, "buys": 2.0, "patience": 1.5, "patience_front": 0.55,
            "urgent_share": 0.3, "noise": 0.6, "price_exp": 0.5, "health_exp": 0.5, "siege": 0.15,
            "counter_bias": 0.05, "bomb_value": 15.0, "boost_screws": 16.0, "anti_air": 1.0, "anti_sub": 1.0,
            "escort_air": 1.0}


def mutate(genome, rng):
    child = {"params": dict(genome["params"]), "weights": dict(genome["weights"])}
    for key in rng.sample(list(BOUNDS), 4):
        low, high = BOUNDS[key]
        value = child["params"][key] + rng.gauss(0.0, (high - low) * 0.18)
        child["params"][key] = round(min(max(value, low), high), 3)
    for unit in rng.sample(UNITS, 5):
        value = child["weights"].get(unit, 1.0) * (2.0 ** rng.uniform(-0.8, 0.8))
        child["weights"][unit] = round(min(max(value, 0.2), 4.0), 3)
    return child


def save_genome(name, genome):
    path = os.path.join(OUT, name + ".json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(genome, handle, indent=1)
    return path


def train(deadline, fleets):
    rng = random.Random(2026)
    best = {"params": dict(DEFAULTS), "weights": {}}
    history = []
    generation = 0
    while left(deadline) > 420.0:
        candidates = [best] + [mutate(best, rng) for _ in range(4)]
        if generation > 1:
            candidates.append(mutate(mutate(best, rng), rng))
        scores = []
        for index, genome in enumerate(candidates):
            tag = "night_train_g%02d_c%d" % (generation, index)
            path = save_genome("genome_g%02d_c%d" % (generation, index), genome)
            rows = arena(tag, fleets, [0, 1, 2, 3, 4, 5], [0, 1], ["adaptive"], deadline, params=path,
                         seed0=20 + generation)
            complete = len(rows) >= len(fleets) * 12 * 0.9
            scores.append((fitness(rows) if complete else -1.0, index, sum(r["won"] for r in rows), len(rows)))
        top = max(scores)
        history.append({"generation": generation, "scores": scores, "chosen": top[1]})
        if top[0] >= 0.0 and scores[0][0] >= 0.0 and (top[1] == 0 or top[0] > scores[0][0] + 0.03):
            best = candidates[top[1]]
        log("generation %d: incumbent %.3f best %.3f (c%d)" % (generation, scores[0][0], top[0], top[1]))
        save_genome("best_genome", best)
        with open(os.path.join(OUT, "training.json"), "w", encoding="utf-8") as handle:
            json.dump(history, handle)
        generation += 1
    return save_genome("best_genome", best)


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(DUEL, exist_ok=True)
    ctypes.windll.kernel32.SetThreadExecutionState(0x80000000 | 0x00000001)
    log("start")
    every = [0, 1, 2, 3, 4, 5]
    check = arena("night_check", ["early", "x:torpedo+plane+flak+bomber"], [0], [0], ["adaptive"], 15,
                  params=save_genome("genome_default", {"params": DEFAULTS, "weights": {}}))
    if len(check) < 2:
        log("check failed, stopping")
        sys.exit(1)
    duels(35)
    arena("night_styles", STANDARD, every, [0, 1, 2], ["adaptive", "counter", "swarm", "heavy", "air", "naval", "subs"], 85)
    rng = random.Random(7)
    comps = [rng.sample(UNITS, 6) for _ in range(60)]
    names = ["x:" + "+".join(c) for c in CURATED + comps]
    arena("night_comps", names, every, [1], ["adaptive"], 130)
    best = train(185, STANDARD + names[:4])
    for tag, params in [("night_final_default", os.path.join(OUT, "genome_default.json")), ("night_final_trained", best)]:
        deadline = 200 if tag.endswith("default") else 215
        arena(tag, STANDARD + names[:4], every, [0, 1, 2], ["adaptive"], deadline, params=params, seeds=2, seed0=100)
    log("end")


if __name__ == "__main__":
    main()
