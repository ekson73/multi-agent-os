# D3-4 Draw — sorteio estratificado (seed 3407, reproduzível)

Pools derivados de `docs/audits/audit-matrix-2026-08-15.md` (firing real). Pool-order: firing desc, nome asc.

- **S1 HIGH (≥10, n=2)** → ambas: `morning-briefing`, `quiesce`
- **S2 MID (4-9, n=5)** → 3 sorteadas: `agentic-tool-forge`, `directive-braindump-triage`, `postflight`
- **S3 LOW (1-3, n=10)** → 3 sorteadas: `agentic-delegation`, `decompose-abstract-to-measurable`, `praxis-audit`
- **S4 DORMANT (0, n=66)**: count-only (zero traces por definição — fatal-1 do red-team R1); rubricas prospectivas ficam FORA do v0.1.

Código canônico: `d34-draw.py` (pool firing-desc/nome-asc · RNG fresco Random(3407) POR POOL · k=2/3/3). Reproduz `d34-sample.json` — verificado pelo auditor: `python3 d34-draw.py` → MATCH.
Executor spawn morreu de quota após escrever os scripts; lead rodou o draw (determinístico, zero julgamento) e completou a extração (journaled no ledger vault). Nota de derivação: skills-matrix.json derivado da matrix.md com 82 entradas (1 perdida na derivação do executor — bands intactas; não afeta o sorteio).

## Nota (Qodo finding 5)
`9router-concierge` (nome começa com dígito) existe no corpus desde antes deste PR — violação de naming pré-existente, registrada aqui como dado do corpus; correção pertence a governance de naming do repo (semântica + refs cruzadas), não a este pacote de rubricas. Não está na amostra sorteada.
