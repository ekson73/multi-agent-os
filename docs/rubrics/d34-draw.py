#!/usr/bin/env python3
"""D3-4 draw — CANÔNICO (reproduz d34-sample.json). Auditor-verified 2026-08-15.
Procedimento real: pool ordenado firing-desc/nome-asc; RNG fresco Random(3407) POR POOL;
sample k por estrato (S1=2/2, S2=3/5, S3=3/10); saída ordenada por nome."""
import json, random, os
m = json.load(open(os.path.join(os.path.dirname(__file__), 'skills-matrix.json')))
pool = sorted(m, key=lambda s: (-s['firing'], s['name']))
s1 = [s for s in pool if s['firing'] >= 10]
s2 = [s for s in pool if 4 <= s['firing'] <= 9]
s3 = [s for s in pool if 1 <= s['firing'] <= 3]
def draw(xs, k):
    return sorted(random.Random(3407).sample(xs, min(k, len(xs))), key=lambda s: s['name'])
sel = {'S1': draw(s1, 2), 'S2': draw(s2, 3), 'S3': draw(s3, 3)}
print(json.dumps({k: [s['name'] for s in v] for k, v in sel.items()}, indent=1))
