#!/usr/bin/env python3
"""D3-4: derive skills-matrix.json from audit-matrix-2026-08-15.md + seeded draw.

Reproducible: seed 3407, sorted pools, random.Random(3407).sample().
Writes:
  - docs/rubrics/skills-matrix.json   [{name, firing}]
  - stdout: pools + drawn (captured by caller into d34-draw.md)
"""
import json
import random
import re
import sys

AUDIT = "docs/audits/audit-matrix-2026-08-15.md"
OUT_MATRIX = "docs/rubrics/skills-matrix.json"
SEED = 3407

rows = []
with open(AUDIT, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line.startswith("|") or line.startswith("|---") or line.startswith("| skill"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 5:
            continue
        name = cells[0]
        try:
            firing = int(cells[4])
        except ValueError:
            continue
        rows.append({"name": name, "firing": firing})

with open(OUT_MATRIX, "w", encoding="utf-8") as f:
    json.dump(rows, f, indent=2, ensure_ascii=False)

s1 = sorted(r["name"] for r in rows if r["firing"] >= 10)
s2 = sorted(r["name"] for r in rows if 4 <= r["firing"] <= 9)
s3 = sorted(r["name"] for r in rows if 1 <= r["firing"] <= 3)

drawn_s1 = s1[:]  # n=2, ambas
rng = random.Random(SEED)
drawn_s2 = rng.sample(s2, 3) if len(s2) >= 3 else s2[:]
drawn_s3 = rng.sample(s3, 3) if len(s3) >= 3 else s3[:]

print(json.dumps({
    "seed": SEED,
    "n_parsed": len(rows),
    "pools": {"S1_firing_ge_10": s1, "S2_firing_4_9": s2, "S3_firing_1_3": s3},
    "drawn": {"S1": drawn_s1, "S2": drawn_s2, "S3": drawn_s3},
}, indent=2, ensure_ascii=False))
