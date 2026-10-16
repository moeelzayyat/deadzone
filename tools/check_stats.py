"""Check that docs/STATS.md and Shared/Stats/StatRegistry agree row for row (A1.7, D-020).

Usage (repo root, after the mirror export): python tools/check_stats.py
Compares the STATS.md "Registry" table with the row(...) calls in mirror/src/shared/Stats/StatRegistry.luau:
order, unit, base source, allowed layers, form, Min and Max. Prints MATCH and exits 0 when they agree.
"""
import re
import sys

DOC = "docs/STATS.md"
CODE = "mirror/src/shared/Stats/StatRegistry.luau"
LAYER = {"F": "Flat", "A": "AdditivePct", "M": "Multiplier"}


def number(text: str) -> float:
    text = text.strip()
    if text.endswith("%"):
        return float(text[:-1]) / 100
    return float(text)


def doc_rows():
    lines = open(DOC, encoding="utf-8").read().split("\n")
    start = lines.index("## Registry")
    rows = []
    for line in lines[start + 1:]:
        if line.startswith("## "):
            break
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 7 or not cells[0].startswith("`"):
            continue
        stat, unit, base, layers, form, low, high = cells[:7]
        base = base if base in ("Class", "Weapon") else number(base)
        rows.append((stat.strip("`"), unit, base, [l.strip() for l in layers.split(",")], form, number(low), number(high)))
    return rows


def code_rows():
    text = open(CODE, encoding="utf-8").read()
    pattern = re.compile(
        r'row\("(\w+)", "([^"]*)", ("Class"|"Weapon"|[-\d.]+), \{ ([FAM, ]+) \}, ([-\d.]+), ([-\d.]+), "(Value|Bonus)"'
    )
    rows = []
    for match in pattern.finditer(text):
        stat, unit, base, layers, low, high, form = match.groups()
        base = base.strip('"') if base.startswith('"') else float(base)
        rows.append((stat, unit, base, [LAYER[l.strip()] for l in layers.split(",")], form, float(low), float(high)))
    return rows


def main() -> int:
    doc, code = doc_rows(), code_rows()
    problems = []
    if len(doc) != len(code):
        problems.append(f"row count: STATS.md {len(doc)}, StatRegistry {len(code)}")
    for index, (d, c) in enumerate(zip(doc, code), 1):
        for name, a, b in zip(("StatId", "Unit", "Base", "Layers", "Form", "Min", "Max"), d, c):
            same = abs(a - b) < 1e-9 if isinstance(a, float) and isinstance(b, float) else a == b
            if not same:
                problems.append(f"row {index} {d[0]}: {name} STATS.md {a!r} vs StatRegistry {b!r}")
    for problem in problems:
        print(problem)
    print(f"rows: STATS.md {len(doc)} · StatRegistry {len(code)} · " + ("MATCH" if not problems else "DIFFER"))
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
