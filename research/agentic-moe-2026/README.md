# agentic-moe-2026 — MAOS Evolution Chapter

> **What this is:** a native MAOS evolution chapter (**ratified** via `docs/adrs/ADR-006-ath-moe-hub-adoption.md` — **Accepted 2026-06-29**; WAVE-0 gating-seam shipped #180).
> **Decision (ratified):** absorb `agentic-moe-2026` into MAOS and realize the ATH hub as the **MAOS Hub**
> (native MoE gating-network, evolution of `mcp-tools/maos-mcp-hub`). **ATH ⊂ agentic-moe-2026 ⊂ MAOS.**
> Prose pt-BR · identifiers en-US · stars = dated order-of-magnitude (2026-06-27), `[sec]` = secondary.

## Índice do capítulo

### 1. Pesquisa (Fases 0–3 + síntese)
- `20260627-00-canonicalization.md` — Fase 0: canonicalização + gate de supply-chain (EXCLUÍDOS: GSD `$GSD` rug-pull, MemPalace).
- `20260627-01a-substrates.md` · `01b-knowledge.md` · `01c-pipeline.md` · `01d-amplifier.md` — Fase 1: landscape L0–L9 (26 experts INCLUDED).
- `20260627-02-ntree-moe.md` — Fase 2: N-Tree / MoE routing graph + receitas + incompatibilidades.
- `20260627-03-orchestrator-hub.md` — Fase 3: o hub (ATH) — artefatos (a)–(m). **→ a realizar como MAOS Hub (proposto, pendente ratificação).**
- `20260627-final-report.md` — síntese + reconciliação de estrelas/licenças + cheat-sheet de roteamento.

### 2. Publicação
- `20260627-CONSOLIDATED.pdf` (100 pág.) · `20260627-CONSOLIDATED.html` · `20260627-exec-deck.pptx`.

### 3. Prompts (não-lançados)
- `20260627-prompt-jira-confluence.md` · `20260627-notebooklm-source-digest.md` · `…-exec-prompt.md` · `…-tech-prompt.md`.

### 4. Integração com o MAOS (esta camada)
- `20260627-ATH-OODA-RECON.md` — inventário do repo × ATH (MAOS já é ~70% do hub).
- **Nativos (fora desta pasta):** `docs/adrs/ADR-006-ath-moe-hub-adoption.md` · `protocols/moe-hub-architecture.md` · `openspec/specs/maos-hub/spec.md` · entrada no `CHANGELOG.md [Unreleased]`.
- **`20260627-HANDOFF-claude-code.md`** — ⭐ prompt de continuidade para o **Claude Code** fazer o hands-on em git-worktrees (GitHub Flow, ADR-004).

## Próximo passo (hands-on)
Abra o `20260627-HANDOFF-claude-code.md`, copie o bloco de prompt e cole numa sessão **Claude Code**
no repo `multi-agent-os`. Ele executa o backlog P0→P2 (single-conductor, AgentShield, ISO universal,
CTS scorer, memória mem0, OTel, model-router, registry, eval) — cada item em seu próprio worktree → PR → squash-merge.

## Status do hands-on — roadmap vivo (SSOT desta tabela; atualizada 2026-07-02)

> Execução via `/maos:quiesce GO 20260627-HANDOFF-claude-code.md` (sessões Claude Code,
> auto-merge sob standing authorization; gate humano reportado ao fim de cada WAVE).

| Wave | Item | Story | Status | PR |
|---|---|---|---|---|
| 0 | WT0 routing-eval (eval-first, mede o "~70%") | S8 | 🟢 merged | [#187](https://github.com/ekson73/multi-agent-os/pull/187) |
| 0 | WT1 C1 single-conductor — hook de runtime RULE-011 | — | 🟢 merged | [#188](https://github.com/ekson73/multi-agent-os/pull/188) |
| 0 | WT2 C6 AgentShield — egress-allowlist + tainting RULE-012 | — | 🟢 merged | [#189](https://github.com/ekson73/multi-agent-os/pull/189) |
| 1 | WT3 ISO universal (summary pool + top-k) | S3 | 🟢 merged | [#197](https://github.com/ekson73/multi-agent-os/pull/197) |
| 1 | WT4 CTS scorer unificado (hard-filters-first) | S2 | 🟢 merged | [#198](https://github.com/ekson73/multi-agent-os/pull/198) |
| 1 | WT5 memória L8 (mem0 default; graphiti DEFERRED) | S4 | 🟢 merged | [#199](https://github.com/ekson73/multi-agent-os/pull/199) |
| 2 | WT8 tool-registry auto-gerado (keystone) | S1 | 🟢 merged | [#200](https://github.com/ekson73/multi-agent-os/pull/200) |
| 3 | WT10 intake-batch — 26 experts como dados | S10/S9 | 🟢 merged (2026-07-02) | [#201](https://github.com/ekson73/multi-agent-os/pull/201) |
| 4 | WT11 docs reframe + CONSOLIDATED regen + MVV (**HITL**) | — | 🔴 not started | — |
| — | WT6 OTel-Sentinel | — | ⏸ DEFERRED (C3 severidade baixa; sem consumidor de telemetria) | — |
| — | WT7 LiteLLM router | — | ✂️ CUT (os3pd adia gateway de runtime até ≥3 incidentes) | — |
| 5 | Console do operador T1–T7 (T1 registry-SSOT → T2 profile-as-gating-input primeiro) | ADR-007 | 🔴 not started | — |
| 6 | Front-door da comunidade T8–T10 (gatekeeper exige piso CI verde da WAVE-0) | ADR-007 | 🔴 not started | — |

Tracking do restante: issue de backlog (Waves 4–6) no GitHub; contratos em
`openspec/specs/maos-hub/spec.md` + `openspec/changes/maos-hub-console/{proposal,tasks}.md` +
`openspec/specs/maos-hub-registry/spec.md`.
