"""Compare Shared/Net/Contracts (mirror) with docs/API_CONTRACTS.md (A1.8, CLAUDE.md rule 6).

Every contract in the registry must have its API_CONTRACTS.md row in the table for its direction, with the same
channel, rate (client->server only) and "Since". Every row whose "Since" substage is at or before the substage
being checked (default: the one in docs/CURRENT_PHASE.md; ROADMAP.md order) must have a contract.

Usage: python tools/check_contracts.py [--through <substage id>]   (from the repo root)
Prints one line per contract and MATCH, or the differences and DIFFER (exit 1).
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTRACTS = ROOT / "mirror/src/shared/Net/Contracts.luau"
DOC = ROOT / "docs/API_CONTRACTS.md"
ROADMAP = ROOT / "docs/ROADMAP.md"
PHASE = ROOT / "docs/CURRENT_PHASE.md"


def registry():
    text = CONTRACTS.read_text(encoding="utf-8")
    block = text.split("Contracts.list = Contracts.build({", 1)[1].split("\n})\n", 1)[0]
    out = {}
    for entry in re.split(r"\n\t\{", block)[1:]:
        field = lambda name: (re.search(name + r' = "([^"]*)"', entry) or [None, None])[1]
        rate = re.search(r"Rate = \{ Sustained = ([\d.]+), Burst = (\d+) \}", entry)
        out[field("Name")] = {
            "Channel": field("Channel"),
            "Direction": field("Direction"),
            "Since": field("Since"),
            "Rate": (float(rate[1]), int(rate[2])) if rate else None,
        }
    return out


def rows():
    out = {}
    direction = None
    for line in DOC.read_text(encoding="utf-8").splitlines():
        if line.startswith("## Client"):
            direction = "C2S"
        elif line.startswith("## Server"):
            direction = "S2C"
        elif line.startswith("## "):
            direction = None
        if direction is None or not line.startswith("| `"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        name = cells[0].strip("`")
        rate = None
        if direction == "C2S":
            m = re.match(r"([\d.]+) / (\d+)", cells[4])
            rate = (float(m[1]), int(m[2])) if m else cells[4]
        out[name] = {"Channel": cells[1], "Direction": direction, "Since": cells[-1], "Rate": rate}
    return out


def order():
    # Substage rows in ROADMAP order. Some ids (A3.5) also appear earlier in the stage table, so keep the last occurrence.
    last = {}
    for i, m in enumerate(re.finditer(r"^\| ([A-Z]\d+(?:\.\d+)?) \|", ROADMAP.read_text(encoding="utf-8"), re.M)):
        last[m[1]] = i
    return sorted(last, key=last.get)


def main():
    through = None
    if "--through" in sys.argv:
        through = sys.argv[sys.argv.index("--through") + 1]
    else:
        through = re.search(r"\*\*Substage:\*\* (\S+)", PHASE.read_text(encoding="utf-8"))[1]
    ids = order()
    if through not in ids:
        print(f"unknown substage {through}")
        return 1
    reg, doc = registry(), rows()
    problems = []
    for name, c in sorted(reg.items()):
        row = doc.get(name)
        if row is None:
            problems.append(f"{name}: no API_CONTRACTS.md row")
            continue
        diffs = [f"{k} {c[k]} vs doc {row[k]}" for k in ("Channel", "Direction", "Since", "Rate") if c[k] != row[k]]
        print(f"{name}: {c['Direction']} {c['Channel']} since {c['Since']} rate {c['Rate']} | " + ("; ".join(diffs) or "row OK"))
        problems += [f"{name}: {d}" for d in diffs]
    limit = ids.index(through)
    for name, row in sorted(doc.items()):
        if row["Since"] in ids and ids.index(row["Since"]) <= limit and name not in reg:
            problems.append(f"{name}: row since {row['Since']} (<= {through}) has no contract")
    print(f"contracts: registry {len(reg)} | rows through {through} " +
          f"{sum(1 for r in doc.values() if r['Since'] in ids and ids.index(r['Since']) <= limit)}")
    for p in problems:
        print("  " + p)
    print("DIFFER" if problems else "MATCH")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
