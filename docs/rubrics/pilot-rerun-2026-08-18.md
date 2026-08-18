# Piloto RE-RUN — delta pós-fixes (2026-08-18)

> Juiz externo pi/Gemini (3ª família; claude org-limit persiste) × rubricas v0.1 × skills em main pós-fixes (#355-#360, #375, #378).
> Mesma disciplina do piloto original: blind à derivação, "absent evidence ⇒ FAIL", adversarial.

## Delta

| Skill | Piloto (08-16) | Re-run (08-18) | Nota |
|---|---|---|---|
| quiesce | 0/3 | **3/3** ✅ | conjuncts operando |
| agentic-delegation | 0/2 | **2/2** ✅ | artifact-verification + fallback-chain verbatim |
| decompose-abstract-to-measurable | 0/2 | **2/2** ✅ | após nit-fix #378 (2 números sem provenance pegos NO RE-RUN — a régua acha até o resto) |
| postflight | 0/2 | **2/2** ✅ | owner-discrimination + FAILURE-verdict |
| directive-braindump-triage | 1/2 | **2/2** ✅ | atomicidade banner↔ledger |
| agentic-tool-forge | 2/2 | **2/2** ✅ | sustentado (adversarial caveat: §0 escape-clause pode pular recon — registrado) |
| morning-briefing | 0/2 | **2/2** ✅ | o port v1.7.0 (#375) trouxe Pulse/zero-counts — **o FAIL curou pela disposição, não por patch** |
| praxis-audit | 0/2 | **0/2** | ESPERADO: critérios mis-scoped (disposição D2: migram p/ v0.2) — não é falha do skill |
| **TOTAL** | **3/17 (18%)** | **15/17 (88%)** | os 2 FAILs restantes são os critérios com disposição registrada |

## Leitura
- Escopo legítimo: **15/15 = 100%** nos critérios corretamente escopados.
- Os 2 FAILs de praxis-audit são a régua detectando erro de AUTORIA da rubrica (disposição D2 já registrada — migram para a rubrica de PR-review no v0.2).
- O re-run já pagou um dividendo extra: o nit de decompose (2 números) só apareceu porque a régua rodou de novo. **Re-run = onde a régua pega o que o fix esqueceu.**

## Conclusão do ciclo
A régua v0.1 completa seu primeiro ciclo de melhoria fechado com delta medido: 18% → 88% (100% no escopo legítimo). Critérios, fixes, juiz externo e deltas todos persistidos. v0.2 é o próximo ciclo (migração de critérios + Camada 1 contrafactual das 66 dormant).
