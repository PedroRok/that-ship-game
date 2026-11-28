import ctypes
import glob
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GODOT = r"D:\Program Files\Godot_v4.6-beta2_mono_win64\Godot_v4.6-stable_win64_console.exe"
PREFIX = "bat_2026-11-28_"
OUT = os.path.join(ROOT, "extras", "balance_reports", "battery_2026-11-28")
ARENA = os.path.join(ROOT, "extras", "balance_reports", "arena")
DUEL = os.path.join(ROOT, "extras", "balance_reports", "duel")
WORKERS = 12
FIRST_SLOT = 94
JOB_TIMEOUT = 2400

FLEETS = {
    "mixed": (["torpedo", "destroyer", "frigate", "flak", "medium", "bomber", "plane", "interceptor", "submarine",
               "sub_scout"], ["frigate", "medium"]),
    "subs": (["torpedo", "sub_scout", "submarine", "sub_hunter", "sub_sam", "flak", "interceptor", "destroyer",
              "bomber", "mini"], ["sub_sam", "mini"]),
    "air": (["mini", "small", "torpedo", "plane", "bomber", "twin_bomber", "interceptor", "missile_plane",
             "destroyer", "sub_hunter"], ["twin_bomber", "small"]),
}
NORMAL = [0, 1, 2, 3, 4]


def fleet_args(skill_count):
    return ["x:" + "+".join(u for u in units if u not in dropped[:skill_count]) for units, dropped in FLEETS.values()]


def group(name, phase, objectives, floors, seeds, seed0, skills=(), elite=False, risks=(), params=None, gears=400):
    extra = ["ai=current", "bot=adaptive", "fleet=" + ",".join(fleet_args(len(skills))),
             "obj=" + ",".join(map(str, objectives)), "floors=" + ",".join(map(str, floors)),
             "seeds=%d" % seeds, "seed0=%d" % seed0, "gears=%d" % gears]
    if skills:
        extra.append("skills=" + ",".join(skills))
    if elite:
        extra.append("elite=1")
    if risks:
        extra.append("risks=" + ",".join(risks))
    return {"tag": PREFIX + name, "phase": phase, "extra": extra, "params": params,
            "expected": len(FLEETS) * len(objectives) * len(floors) * seeds}


def skill_set(phase, name, skills, params=None):
    return [group(name + "_n", phase, NORMAL, [2, 3], 4, 1000, skills, params=params),
            group(name + "_b", phase, [5], [4], 8, 1000, skills, params=params)]


def plan():
    groups = []
    for name, skills in [("none", []), ("repair", ["repair"]), ("supply", ["supply"]), ("flak", ["flak"]),
                         ("bomb", ["bomb"])]:
        groups += skill_set(1, "p1_" + name, skills)
    for cooldown in (45, 90):
        groups += skill_set(2, "p2_supply_cd%d" % cooldown, ["supply"], {"supply_cooldown": cooldown})
    groups += [group("p3_cols12", 3, NORMAL, [0, 1], 4, 1000),
               group("p3_cols34_more", 3, NORMAL, [2, 3], 2, 1004),
               group("p3_elite", 3, NORMAL, [1, 2, 3], 4, 1000, elite=True),
               group("p3_boss_more", 3, [5], [4], 24, 1008),
               group("p4_bomber_none", 4, [4], [2], 16, 2000),
               group("p4_bomber_morebosses", 4, [4], [2], 16, 2000, risks=["more_bosses"]),
               group("p4_bomber_armored", 4, [4], [2], 16, 2000, risks=["stronger_enemies"]),
               group("p4_boss_morebosses", 4, [5], [4], 16, 1000, risks=["more_bosses"]),
               group("p4_boss_armored", 4, [5], [4], 16, 1000, risks=["stronger_enemies"])]
    groups += skill_set(5, "p5_supply_bomb", ["supply", "bomb"])
    groups += [group("p5_gears250", 5, NORMAL, [2, 3], 2, 1000, gears=250),
               group("p5_gears700", 5, NORMAL, [2, 3], 2, 1000, gears=700)]
    return groups


def log(text):
    line = "%s %s" % (time.strftime("%m-%d %H:%M:%S"), text)
    print(line, flush=True)
    with open(os.path.join(OUT, "progress.log"), "a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def rows_of(tag):
    result = []
    for path in glob.glob(os.path.join(ARENA, tag, "rows_*.json")):
        try:
            with open(path, encoding="utf-8") as handle:
                result += json.load(handle)
        except (OSError, ValueError):
            pass
    return result


def code_state():
    diff = subprocess.run(["git", "diff", "HEAD", "--", ".", ":!dev_tools"], cwd=ROOT, capture_output=True).stdout
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    return head + " " + hashlib.sha1(diff).hexdigest()


def run_pool(jobs):
    running = {}
    free = list(range(WORKERS))
    while jobs or running:
        while jobs and free:
            job = jobs.pop(0)
            slot = free.pop(0)
            handle = open(job["log"], "a", encoding="utf-8", errors="ignore")
            args = [GODOT, "--headless", "--fixed-fps", "60", "--path", ROOT, job["scene"], "--"] + job["args"]
            if job["slot_arg"]:
                args.append("slot=%d" % (FIRST_SLOT + slot))
            running[slot] = (subprocess.Popen(args, stdout=handle, stderr=subprocess.STDOUT), handle, time.time(), job)
        time.sleep(2)
        for slot, (proc, handle, started, job) in list(running.items()):
            if proc.poll() is None and time.time() - started < JOB_TIMEOUT:
                continue
            if proc.poll() is None:
                proc.kill()
                log("timeout " + job["name"])
            handle.close()
            del running[slot]
            free.append(slot)


def arena_jobs(item):
    folder = os.path.join(ARENA, item["tag"])
    os.makedirs(folder, exist_ok=True)
    shards = max(1, min(WORKERS, item["expected"] // 12))
    extra = ["tag=" + item["tag"]] + item["extra"]
    if item["params"]:
        path = os.path.join(OUT, item["tag"] + "_params.json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump({"params": item["params"], "weights": {}}, handle)
        extra.append("params=" + path.replace("\\", "/"))
    return [{"name": "%s %d" % (item["tag"], shard), "scene": "res://dev_tools/balance/ai_arena.tscn",
             "slot_arg": True, "log": os.path.join(folder, "worker_%d.log" % shard),
             "args": extra + ["shard=%d/%d" % (shard, shards)]} for shard in range(shards)]


def arena_phase(groups):
    for _attempt in range(3):
        jobs = []
        for item in groups:
            if len(rows_of(item["tag"])) < item["expected"]:
                jobs += arena_jobs(item)
        if not jobs:
            break
        run_pool(jobs)
    for item in groups:
        log("%s: %d/%d" % (item["tag"], len(rows_of(item["tag"])), item["expected"]))
        shutil.copytree(os.path.join(ARENA, item["tag"]), os.path.join(OUT, "backup", item["tag"]), dirs_exist_ok=True)


def duels():
    air = ["plane", "interceptor", "missile_plane", "bomber", "twin_bomber", "heli_scout", "heli_heavy"]
    pairs = [a + ":" + b for i, a in enumerate(air) for b in air[i + 1:]]
    pairs += [a + ":" + b for a in ["flak", "sub_sam", "destroyer"] for b in air]
    path = os.path.join(OUT, "pairs_flares.txt")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(",".join(pairs))
    for repeat in range(4):
        tag = "%sflares_r%d" % (PREFIX, repeat)
        done = os.path.join(OUT, tag + ".done")
        if os.path.exists(done):
            continue
        run_pool([{"name": "%s %d" % (tag, shard), "scene": "res://dev_tools/balance/unit_duel.tscn",
                   "slot_arg": False, "log": os.path.join(OUT, "%s_%d.log" % (tag, shard)),
                   "args": ["tag=" + tag, "value=120", "pairsfile=" + path.replace("\\", "/"),
                            "shard=%d/%d" % (shard, WORKERS)]} for shard in range(WORKERS)])
        open(done, "w").close()
        log(tag + " done")


def main():
    os.makedirs(OUT, exist_ok=True)
    ctypes.windll.kernel32.SetThreadExecutionState(0x80000000 | 0x00000001)
    state_path = os.path.join(OUT, "code_state.txt")
    if not os.path.exists(state_path):
        with open(state_path, "w", encoding="utf-8") as handle:
            handle.write(code_state())
    with open(state_path, encoding="utf-8") as handle:
        original = handle.read()
    groups = plan()
    log("start, %d battles planned" % sum(g["expected"] for g in groups))
    for phase in (1, 2, 3, 4, "duels", 5):
        if code_state() != original:
            log("GAME CODE CHANGED since the battery started, stopping before phase %s" % phase)
            sys.exit(2)
        log("phase %s" % phase)
        if phase == "duels":
            duels()
        else:
            arena_phase([g for g in groups if g["phase"] == phase])
    log("end, code unchanged: %s" % (code_state() == original))


if __name__ == "__main__":
    main()
