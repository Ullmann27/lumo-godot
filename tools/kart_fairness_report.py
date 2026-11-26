#!/usr/bin/env python3
"""Summarise LUMO Kart fairness runs (scripts/tests/kart_rival_fairness_probe.gd).

Reads the probe's JSON lines (files or directories with *.jsonl), groups the races
by driver label and difficulty and prints wins, places and the gap to the fastest
rival. Optional requirements make it a pass/fail gate, e.g.

    python3 tools/kart_fairness_report.py runs/ \
        --require kind_ungenau:gemuetlich:0.8 --require vernuenftig:gemuetlich:0.95

(at least 80 % wins for the imprecise child on Entdecken, 95 % for the careful
child). Exit code 1 when a requirement fails or a race did not finish.
"""
from pathlib import Path
import json
import statistics
import sys

LEVEL_NAMES = {"gemuetlich": "Entdecken", "flott": "Abenteuer", "pro": "Extrem"}


def load(paths):
    rows = []
    for raw in paths:
        path = Path(raw)
        files = sorted(path.rglob("*.jsonl")) if path.is_dir() else [path]
        for file in files:
            for line in file.read_text().splitlines():
                line = line.strip()
                if line:
                    rows.append(json.loads(line))
    return rows


def main(argv):
    paths = []
    requirements = []
    args = iter(argv)
    for arg in args:
        if arg == "--require":
            label, level, share = next(args).split(":")
            requirements.append((label, level, float(share)))
        else:
            paths.append(arg)
    rows = load(paths)
    if not rows:
        print("no races found")
        return 1
    groups = {}
    for row in rows:
        key = (row.get("label") or "vernuenftig", row["level"])
        groups.setdefault(key, []).append(row)
    failed = False
    print("Fahrer         Stufe       Rennen Siege  Anteil  Platz(Median)  Abstand Median (s)  Zeit Kind (s)  bester Rivale (s)  Treffer/Rennen  Planke/Rennen")
    for (label, level), races in sorted(groups.items()):
        finished = [r for r in races if r.get("finished")]
        if len(finished) != len(races):
            failed = True
        wins = sum(1 for r in finished if int(r["place"]) == 1)
        gaps = [float(r["gap_to_winner"]) for r in finished]
        times = [float(r["player_time"]) for r in finished]
        best = [min(t for t in r["rival_times"] if t > 0) for r in finished if any(t > 0 for t in r["rival_times"])]
        hits = [int(r.get("hits_taken", 0)) for r in finished]
        walls = [int(r.get("wall_contacts", 0)) for r in finished]
        share = wins / max(1, len(races))
        print(
            f"{label:14s} {LEVEL_NAMES.get(level, level):11s} {len(races):6d} {wins:5d}  {share:6.0%}  "
            f"{statistics.median([int(r['place']) for r in finished]) if finished else 0:13.1f}  "
            f"{statistics.median(gaps) if gaps else 0:18.2f}  {statistics.mean(times) if times else 0:13.2f}  "
            f"{statistics.mean(best) if best else 0:17.2f}  {statistics.mean(hits) if hits else 0:14.1f}  "
            f"{statistics.mean(walls) if walls else 0:13.1f}"
        )
    for label, level, needed in requirements:
        races = groups.get((label, level), [])
        wins = sum(1 for r in races if r.get("finished") and int(r["place"]) == 1)
        share = wins / max(1, len(races))
        ok = bool(races) and share >= needed
        failed = failed or not ok
        print(f"{'PASS' if ok else 'FAIL'} {label} {LEVEL_NAMES.get(level, level)}: {wins}/{len(races)} Siege ({share:.0%}, verlangt {needed:.0%})")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
