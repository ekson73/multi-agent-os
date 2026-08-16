#!/usr/bin/env python3
"""D3-4 draw — CANÔNICO (reproduz d34-sample.json). Auditor-verified 2026-08-15.
Procedimento real: pool ordenado firing-desc/nome-asc; RNG fresco Random(3407) POR POOL;
sample k por estrato (S1=2/2, S2=3/5, S3=3/10); saída ordenada por nome."""
import json, random, os
_mpath = os.path.join(os.path.dirname(__file__), 'skills-matrix.json')
if not os.path.exists(_mpath):
    raise SystemExit(f'ERRO: {_mpath} ausente — derive de docs/audits/audit-matrix-2026-08-15.md')
m = json.load(open(_mpath, encoding='utf-8', errors='replace'))
m = m['skills'] if isinstance(m, dict) and 'skills' in m else m  # aceita envelope com _comment
pool = sorted(m, key=lambda s: (-s['firing'], s['name']))
s1 = [s for s in pool if s['firing'] >= 10]
s2 = [s for s in pool if 4 <= s['firing'] <= 9]
s3 = [s for s in pool if 1 <= s['firing'] <= 3]
def draw(xs, k):
    if len(xs) < k:
        # pré-registro fixa k por estrato; pool menor = violação da spec, NÃO shrink silencioso
        raise SystemExit(f'ERRO: pool com {len(xs)} < k={k} pré-registrado — a spec foi violada, redesenhe o estrato')
    return sorted(random.Random(3407).sample(xs, k), key=lambda s: s['name'])
sel = {'S1': draw(s1, 2), 'S2': draw(s2, 3), 'S3': draw(s3, 3)}
print(json.dumps({k: [s['name'] for s in v] for k, v in sel.items()}, indent=1))
