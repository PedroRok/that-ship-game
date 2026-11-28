import collections
import glob
import json
import math
import os
import statistics

import battery as b

OBJECTIVES = ["destroy", "defend", "escort", "hunt", "bomber", "boss"]
DROPPED = {"frigate": "mixed", "sub_sam": "subs", "twin_bomber": "air"}


def fleet_label(fleet):
    units = set(fleet[2:].split("+"))
    matches = [name for name, (full, _) in b.FLEETS.items() if units <= set(full)]
    assert len(matches) == 1, (fleet, matches)
    return matches[0]


def load(*names):
    rows = []
    for name in names:
        for row in b.rows_of(b.PREFIX + name):
            row["label"] = fleet_label(row["fleet"])
            rows.append(row)
    return rows


def key(row):
    return (row["objective"], row["floor"], row["label"], row["seed"])


def margin(p, n):
    return 196.0 * math.sqrt(max(p * (1.0 - p), 0.0001) / n)


def stats(rows):
    if not rows:
        return "| 0 | - | - | - | - | - |"
    n = len(rows)
    p = sum(r["won"] for r in rows) / n
    times = [r["time"] for r in rows]
    wins = [r["ally_hp"] for r in rows if r["won"]]
    return "| %d | %.0f%% ±%.0f | %.0f s | %.0f%% | %.0f%% | %s |" % (
        n, p * 100, margin(p, n), statistics.median(times), 100 * sum(t < 90 for t in times) / n,
        100 * sum(t > 240 for t in times) / n, "%.0f%%" % (100 * statistics.median(wins)) if wins else "-")


def table(title, groups):
    print("\n### %s\n" % title)
    print("| grupo | n | vitória | mediana | <90 s | >240 s | base nas vitórias |")
    print("|---|---|---|---|---|---|---|")
    for name, rows in groups:
        print("| %s %s" % (name, stats(rows)))


def split(rows, field, names=None):
    values = sorted({r[field] for r in rows})
    return [(names[v] if names else str(v), [r for r in rows if r[field] == v]) for v in values]


def paired(title, base, others):
    print("\n### %s\n" % title)
    print("| grupo | pares | diferença de vitória | margem 95% | derrota→vitória | vitória→derrota |")
    print("|---|---|---|---|---|---|")
    index = {key(r): r for r in base}
    for name, rows in others:
        pairs = [(index[key(r)], r) for r in rows if key(r) in index]
        if not pairs:
            continue
        n = len(pairs)
        p = sum(a["won"] for a, _ in pairs) / n
        q = sum(c["won"] for _, c in pairs) / n
        gained = sum(not a["won"] and c["won"] for a, c in pairs)
        lost = sum(a["won"] and not c["won"] for a, c in pairs)
        error = 196.0 * math.sqrt((p * (1 - p) + q * (1 - q)) / n)
        print("| %s | %d | %+.0f | ±%.0f | %d | %d |" % (name, n, 100 * (q - p), error, gained, lost))


def skill_use(groups):
    print("\n### Uso das skills\n")
    print("| grupo | skill | usos por batalha | batalhas sem uso | 1º uso (mediana) | parafusos do suprimento | renda |")
    print("|---|---|---|---|---|---|---|")
    for name, rows in groups:
        for skill in ["repair", "supply", "flak", "bomb"]:
            uses = [r["skills"].get(skill, 0) for r in rows]
            if not rows or sum(uses) == 0:
                continue
            first = [min(e[0] for e in r["skill_log"] if e[1] == skill) for r in rows if r["skills"].get(skill, 0)]
            screws = statistics.mean(r["supply_screws"] for r in rows)
            income = statistics.mean(r["eco"]["income"] for r in rows)
            print("| %s | %s | %.1f | %.0f%% | %.0f s | %.0f | %.0f |" % (
                name, skill, statistics.mean(uses), 100 * sum(u == 0 for u in uses) / len(uses),
                statistics.median(first), screws, income))


def duels():
    scores = collections.defaultdict(list)
    for path in glob.glob(os.path.join(b.DUEL, b.PREFIX + "flares_r*_rows_*.json")):
        with open(path, encoding="utf-8") as handle:
            for row in json.load(handle):
                scores[(row["a"], row["b"])].append(row["a_left"] - row["b_left"])
    old = collections.defaultdict(list)
    for path in glob.glob(os.path.join(b.DUEL, "n120_rows_*.json")):
        with open(path, encoding="utf-8") as handle:
            for row in json.load(handle):
                old[(row["a"], row["b"])].append(row["a_left"] - row["b_left"])
                old[(row["b"], row["a"])].append(row["b_left"] - row["a_left"])
    print("\n### Duelos aéreos, 120 parafusos (margem: positivo favorece o primeiro)\n")
    print("| par | agora | n | 27/11 (build h) |")
    print("|---|---|---|---|")
    for pair, values in sorted(scores.items()):
        before = old.get(pair)
        print("| %s x %s | %+.2f | %d | %s |" % (pair[0], pair[1], statistics.mean(values), len(values),
                                                "%+.2f" % statistics.mean(before) if before else "-"))


def main():
    objective_names = dict(enumerate(OBJECTIVES))
    conditions = [("sem skill", "p1_none"), ("reparo", "p1_repair"), ("suprimento", "p1_supply"),
                  ("barragem", "p1_flak"), ("bombardeio", "p1_bomb"), ("supr. recarga 45", "p2_supply_cd45"),
                  ("supr. recarga 90", "p2_supply_cd90"), ("supr.+bomb.", "p5_supply_bomb")]
    data = [(name, load(tag + "_n", tag + "_b")) for name, tag in conditions]
    table("Skills: mesma grade (colunas 3, 4 e chefe)", data)
    paired("Skills contra sem skill", data[0][1], data[1:])
    paired("Recarga contra suprimento sem recarga", data[2][1], data[5:7])
    for label in ["mixed", "subs", "air"]:
        paired("Skills contra sem skill, frota " + label, [r for r in data[0][1] if r["label"] == label],
               [(n, [r for r in rows if r["label"] == label]) for n, rows in data[1:]])
    for name, rows in data:
        table("Por objetivo: " + name, split(rows, "objective", objective_names))
    skill_use(data)

    normal = load("p1_none_n", "p3_cols12", "p3_cols34_more")
    elite = load("p3_elite")
    boss = load("p1_none_b", "p3_boss_more")
    table("Metas, sem skill", [("coluna %d normal" % (f + 1), [r for r in normal if r["floor"] == f]) for f in range(4)]
          + [("normal colunas 2-4", [r for r in normal if r["floor"] > 0])]
          + [("elite coluna %d" % (f + 1), [r for r in elite if r["floor"] == f]) for f in range(1, 4)]
          + [("elite total", elite), ("chefe", boss)])
    for floor in range(4):
        table("Coluna %d por objetivo" % (floor + 1), split([r for r in normal if r["floor"] == floor], "objective", objective_names))
    table("Elite por objetivo", split(elite, "objective", objective_names))
    table("Por frota: normal", split(normal, "label"))
    table("Por frota: elite", split(elite, "label"))
    table("Por frota: chefe", split(boss, "label"))
    table("Todos os modos normais", split(normal, "objective", objective_names))

    bomber = load("p4_bomber_none")
    bomber_more = load("p4_bomber_morebosses")
    bomber_armored = load("p4_bomber_armored")
    boss_more = load("p4_boss_morebosses")
    boss_armored = load("p4_boss_armored")
    table("Modificadores", [("bombardeiro", bomber), ("bombardeiro + mais chefes", bomber_more),
                            ("bombardeiro + blindados", bomber_armored), ("chefe (sementes 1000-1015)", [r for r in load("p3_boss_more", "p1_none_b") if r["seed"] < 1016]),
                            ("chefe + mais chefes", boss_more), ("chefe + blindados", boss_armored)])
    paired("Modificadores no bombardeiro", bomber, [("mais chefes", bomber_more), ("blindados", bomber_armored)])
    paired("Modificadores no chefe", load("p1_none_b", "p3_boss_more"), [("mais chefes", boss_more), ("blindados", boss_armored)])

    base400 = [r for r in load("p1_none_n") if r["seed"] < 1002]
    table("Progressão (colunas 3 e 4, sem skill)", [("250", load("p5_gears250")), ("400", base400), ("700", load("p5_gears700"))])

    built = collections.Counter()
    lost = collections.Counter()
    for row in normal + elite + boss:
        built.update(row["built"])
        lost.update(row["lost"])
    print("\n### Compras e sobrevivência\n\n| tropa | compradas | sobrevivem |\n|---|---|---|")
    for name, count in built.most_common():
        print("| %s | %d | %.0f%% |" % (name, count, 100 * max(count - lost[name], 0) / count))
    print("\n### Motivo das derrotas por objetivo (sem skill)\n")
    for index, name in enumerate(OBJECTIVES):
        rows = [r for r in normal + elite + boss if r["objective"] == index and not r["won"]]
        if rows:
            print("-", name, dict(collections.Counter(r["reason"] for r in rows)),
                  "vida inimiga mediana %.0f%%" % (100 * statistics.median(r["enemy_hp"] for r in rows)),
                  "escolta %.2f" % statistics.median(r["escort_progress"] for r in rows) if name == "escort" else "")
    duels()


if __name__ == "__main__":
    main()
