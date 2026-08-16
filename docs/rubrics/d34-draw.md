# D3-4 Draw — sorteio estratificado (seed 3407, reproduzível)

Pools derivados de `docs/audits/audit-matrix-2026-08-15.md` (firing real). Pool-order: firing desc, nome asc.

- **S1 HIGH (≥10, n=2)** → ambas: `morning-briefing`, `quiesce`
- **S2 MID (4-9, n=5)** → 3 sorteadas: `agentic-tool-forge`, `directive-braindump-triage`, `postflight`
- **S3 LOW (1-3, n=10)** → 3 sorteadas: `agentic-delegation`, `decompose-abstract-to-measurable`, `praxis-audit`
- **S4 DORMANT (0, n=66)**: count-only (zero traces por definição — fatal-1 do red-team R1); rubricas prospectivas ficam FORA do v0.1.

Código exato: `random.Random(3407).sample(sorted(pool, key=nome-asc), k)` com k=2/3/3 — ver `d34-sample.json`.
Executor spawn morreu de quota após escrever os scripts; lead rodou o draw (determinístico, zero julgamento) e completou a extração (journaled no ledger vault). Nota de derivação: skills-matrix.json derivado da matrix.md com 82 entradas (1 perdida na derivação do executor — bands intactas; não afeta o sorteio).
