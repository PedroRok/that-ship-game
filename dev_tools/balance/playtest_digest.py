import collections
import gzip
import json
import statistics
import sys


def load(path):
    raw = open(path, "rb").read()
    if path.endswith(".gz"):
        raw = gzip.decompress(raw)
    return [json.loads(line) for line in raw.decode("utf-8").splitlines() if line.strip()]


def main(paths):
    battles = []
    for path in paths:
        for battle in load(path):
            battle["src"] = path
            if battle["res"][0] == 1 and battle["res"][2] <= 0:
                battle["res"][0] = 2
            battles.append(battle)
    print("battles", len(battles), "files", len(paths))
    groups = collections.defaultdict(list)
    for battle in battles:
        groups[battle["obj"]].append(battle)
    for objective, group in sorted(groups.items()):
        won = sum(b["res"][0] == 1 for b in group)
        left = sum(b["res"][0] == 0 for b in group)
        bought = collections.Counter()
        first = collections.Counter()
        saved = []
        skills = collections.Counter()
        for battle in group:
            names = battle["names"]
            buys = [e for e in battle["ev"] if e[1] == "u"]
            bought.update(names[e[2][0]] for e in buys)
            if buys:
                first[names[buys[0][2][0]]] += 1
            saved += [e[3][0] for e in buys]
            skills.update(e[2][0] if e[1] == "x" else e[1] for e in battle["ev"] if e[1] in ("b", "k", "c", "x"))
        print("obj", objective, "n", len(group), "won", won, "left", left,
              "med_s", statistics.median(b["res"][1] for b in group),
              "screws_left_after_buy", statistics.median(saved) if saved else 0)
        print("  first", first.most_common(4), "buys", bought.most_common(8), "skills/cancel",
              dict(skills))


if __name__ == "__main__":
    main(sys.argv[1:])
