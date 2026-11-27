import json
import os
import sys

import night_run as night

OUT = os.path.join(night.ROOT, "extras", "balance_reports", "short_2026-11-27")
night.OUT = OUT

VARIANTS = {
    "base": {},
    "no_skills": {"use_bomb": 0, "use_boost": 0},
    "bomb_only": {"use_boost": 0},
    "boost_only": {"use_bomb": 0},
    "eager_skills": {"bomb_value": 8, "boost_screws": 8},
    "cancel": {"cancel": 1},
    "wave30": {"wave": 30},
    "queue1": {"queue_max": 1},
    "save_big": {"patience": 1.05, "patience_front": 0.85},
    "spread_docks": {"spread": 1},
}


def main():
    os.makedirs(OUT, exist_ok=True)
    night.ctypes.windll.kernel32.SetThreadExecutionState(0x80000000 | 0x00000001)
    every = [0, 1, 2, 3, 4, 5]
    fleets = night.STANDARD + ["x:" + "+".join(c) for c in (night.CURATED[0], night.CURATED[1], night.CURATED[3], night.CURATED[4])]
    night.log("start")
    night.arena("short_balance", fleets, every, [0, 1, 2], ["adaptive"], 600, seed0=100)
    night.arena("short_boss", fleets, [5], [0, 1, 2], ["adaptive"], 600, seeds=3, seed0=200)
    night.duels_only = True
    singles = [a + ":" + b for i, a in enumerate(night.UNITS) for b in night.UNITS[i + 1:]]
    path = os.path.join(OUT, "pairs.txt")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(",".join(singles))
    night.launch("res://dev_tools/balance/unit_duel.tscn", ["tag=s120", "value=120", "pairsfile=" + path.replace("\\", "/")],
                 OUT, "duel", night.left(600))
    night.log("duels done")
    for name, params in VARIANTS.items():
        genome = night.save_genome("micro_" + name, {"params": params, "weights": {}})
        night.arena("short_micro_" + name, ["navy", "deep", fleets[4]], every, [0, 1], ["adaptive"], 600,
                    params=genome, seed0=300)
    night.log("end")


if __name__ == "__main__":
    main()
