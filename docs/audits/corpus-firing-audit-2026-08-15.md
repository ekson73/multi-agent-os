# Corpus Firing Audit — Camada 0 (2026-08-15)

> Régua híbrido-ancorada, Camada 0 (council decision [[ruler-33-synthesis]]).
> Corpus: **83/83 skills** `skills/*/SKILL.md` · branch audit/corpus-firing-r2.
> Anchors estruturais derivados de logs reais (não assertados — red-team R2 C1) e codificados em script reproduzível.

## Fontes (DoR)
- **Claude**: `~/.claude/projects/**/*.jsonl` (2032) · anchor `<command-name>/x</command-name>` (875 invocações totais)
- **Codex**: `~/.codex/sessions/**/*.jsonl` (362) · anchor `"/x"` em input_text (359 hits totais)
- **pi**: `~/.pi/agent/sessions/**/*.jsonl` (71) · anchor `read` tool-call de `*/skills/x/SKILL.md` (58 hits genuínos — preload-listing NUNCA é tool-call; sessão da auditoria excluída via glob)

## Resultado (83/83 classificadas)
| Bucket | n | % |
|---|---|---|
| **FIRING** (estrutural>0) | 17 | 20% |
| **DORMANT/NO-EVIDENCE** | 66 | 80% |
| Boundedness proxy UNBOUNDED | 52 | 63% |
| Frontmatter INVALID | 0 | 0% |

## Top 10 FIRING
- **quiesce** — claude=161 codex=0 pi=0 (total 161)
- **morning-briefing** — claude=129 codex=0 pi=3 (total 132)
- **agentic-tool-forge** — claude=0 codex=0 pi=7 (total 7)
- **anima** — claude=0 codex=0 pi=7 (total 7)
- **content-recast** — claude=1 codex=0 pi=3 (total 4)
- **directive-braindump-triage** — claude=0 codex=0 pi=4 (total 4)
- **postflight** — claude=4 codex=0 pi=0 (total 4)
- **decompose-abstract-to-measurable** — claude=0 codex=0 pi=2 (total 2)
- **preflight** — claude=2 codex=0 pi=0 (total 2)
- **agentic-delegation** — claude=0 codex=0 pi=1 (total 1)

## DORMANT/NO-EVIDENCE (66)
9router-concierge, agent-select, agentic-session-harness, agentic-tool-evaluator, agentic-tool-intake, agentic-tool-pipeline, agentic-tool-trainer, anti-conflict, audit, auto-pilot, bitbucket-pipeline-watch, bot-finding-arbiter, chief-of-staff, claude-code-concierge, context-prep, converge, convergence-engine, corpus-firing-audit, council-gate, decision-capture, delegate-governance, deliberate-coding, derive-system-from-goal, dogfood-ledger, find-docs, founder-playbook, founder-stage-idea, founder-stage-launch, founder-stage-mvp, founder-stage-scale, gap-loop, goal-recovery, hierarchical-merge, lens-dispatch, maos-concierge, memory-gateway, mvv-synthesis, notebooklm, omniroute-concierge, ontological-analysis, opendesign-concierge, opera-debrief, pii-masking, proofread, pulse, reactivate, red-team, repo-custody-transfer, research-dossier, response-compression, reveng, rule-quality-tests, session-fission, session-reentry, skill-writer, slm-routing, status-map, sync-to-git, system-health-responder, transcript-corrector, ttl-policy, voice-director, walkthrough-concierge, work-compass, work-drain, worktree-policy

⚠️ **NO-EVIDENCE ≠ THEATER.** Sem evidência de gatilho-frequente-sem-disparo nesta camada. Preventivas protegidas por análise contrafactual (council condição 3). Dormant-aqui ≠ remover — significa "não observado nos logs destes 3 vendors na janela disponível".

## Limitações
1. **Claude anchor = slash-commands apenas**; trigger-natural (skill invocada por descrição, sem /) não registra — under-count real. Claude é o vendor dominante do corpus.
2. Codex `/x` inclui comandos que falharam — over-count leve; e cobre poucas skills maos (codex quase não rodou maos).
3. pi anchor = reads genuínos; pode perder invocações que não passam por read do SKILL.md.
4. Logs vivos driftam (snapshot: `snapshot-2026-08-15.json`).
5. Boundedness = regex-proxy de vocabulário. Não-contradição = frontmatter apenas (semântica = Camada 1).
6. UNBOUNDED (52): 9router-concierge, agent-select, agentic-session-harness, agentic-tool-evaluator, agentic-tool-trainer, anti-conflict, audit, auto-pilot, bitbucket-pipeline-watch, claude-code-concierge, context-prep, converge, corpus-firing-audit, decision-capture, decompose-abstract-to-measurable, delegate-governance, deliberate-coding, directive-braindump-triage, dogfood-ledger, find-docs, founder-playbook, founder-stage-idea, founder-stage-launch, founder-stage-mvp, founder-stage-scale, hierarchical-merge, lens-dispatch, maos-concierge, memory-gateway, morning-briefing, mvv-synthesis, notebooklm, omniroute-concierge, ontological-analysis, pii-masking, postflight, preflight, pulse, quiesce, research-dossier, response-compression, session-fission, signoff, skill-writer, slm-routing, status-map, sync-to-git, system-health-responder, ttl-policy, walkthrough-concierge, work-drain, worktree-policy

## Auditoria independente (2 rounds)
R1: 4 achados (anchor pi frágil · auto-referência · tabela não persistida · counts dessincronizados) → todos corrigidos. Recounts amostrais batiam (quiesce=161, morning-briefing=129). R2 (self-audit do lead): glob de exclusão com dots-matava-tudo → corrigido para dashes; anchor pi re-derivado (read tool-call).

Script: `scripts/corpus-firing-audit.py` (reproduzível) · Matriz 83-row: `audit-matrix-2026-08-15.md` · Lead: Pi-Lead-01a0-340.
