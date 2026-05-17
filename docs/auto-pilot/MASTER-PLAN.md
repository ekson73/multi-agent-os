# `auto-pilot` Master-Plan / Manifesto

> **Living document** — captura a estratégia + decisões + roadmap do projeto `auto-pilot`. Atualizado por convergência de debates (Git-PR-as-Debate-Prompt). NÃO é o body do skill (esse vive em [`skills/auto-pilot/SKILL.md`](../../skills/auto-pilot/SKILL.md)).
>
> **Version**: v0.2-draft · **Date**: 2026-05-17 · **Status**: PRE-CONVERGENCE (debate ainda não rodou) · **License**: MIT.

---

## 1. Identity (Mission · Vision · Values)

**Mission**: Prover ao multi-agent-os um **goal-level autonomous-orchestration entry point** que delega um objetivo do operador end-to-end através de sub-agents, respeitando Sentinel Protocol + Anti-Conflict + 6-attempt escalation, com autonomia bandeada (L1/L2/L3) e DNA payload adicional retro-compatível.

**Vision**: Tornar-se a **fachada community-facing canônica** para orquestração autônoma multi-AI — composta com `skills/converge` (debate), `skills/agent-select` (routing), `protocols/delegation/*` (GaaS) — e o **gateway de promoção** entre experimentos user-scope (e.g., [`~/.claude/skills/auto-orchestrator/`](https://github.com/ekson73/vek-dot-claude/tree/main/skills/auto-orchestrator)) e adoção community/AAIF cross-vendor.

**Values**:
- **Compose, don't reimplement** — toda seta de fluxo termina em artifact existente neste repo.
- **Goldilocks** — ≤ 12 KB ceiling enforced para skill bodies (`SKILL.md`); master-plan prioriza summary-first com sub-docs linkados para extensões; tamanho atual reflete escopo fundacional do v0.2 (não-binding cap, revisitar após convergência).
- **Backward-compat additive** — DNA payload extensions opt-in, nunca breaking.
- **Anti-theater** — REALITY 8/8 check por artifact (real / not-faz-de-conta / not-hallucinated / not-invented / viable / applicable / implementable / useful).
- **HITL conservation** — autonomia agentic ≥ 90% / humans ≤ 10% como **tendência declinante de HITL/round**, não absoluto unprovable.
- **Layer-purity unidirectional** — community pode ser consumida por corp; community NUNCA contém corp-specific.

---

## 2. Architecture relation map

```text
                 ┌──────────────────────────────────────────────────┐
                 │  USER-SCOPE (operator's private `~/.claude/`)    │
                 │  ┌────────────────────────────────────────────┐  │
                 │  │ skills/auto-orchestrator/  v1.1.0          │  │
                 │  │  7 phases · 5 companion subagents          │  │
                 │  │  6-factor autonomy_score · goal-aware mode │  │
                 │  └─────────────────┬──────────────────────────┘  │
                 └────────────────────│─────────────────────────────┘
                                      │ (consume direction TBD per Stream 2)
                                      ▼
┌──────────────────────────────────────────────────────────────────────┐
│ COMMUNITY (ekson73/multi-agent-os — open-source MIT)                  │
│                                                                       │
│   commands/auto-pilot.md  ──►  skills/auto-pilot/SKILL.md  v0.1.0     │
│                                       │                               │
│                                       ▼                               │
│   ┌───────────────────────────────────────────────────────────────┐   │
│   │  COMPOSED PRIMITIVES (do not re-author):                       │   │
│   │  • skills/agent-select/SKILL.md       (Phase 1 routing)       │   │
│   │  • skills/converge/SKILL.md  v1.1.1   (debate-converge mode)  │   │
│   │  • skills/anti-conflict/SKILL.md      (Phase-1 checklist)     │   │
│   │  • skills/worktree-policy/SKILL.md    (write discipline)      │   │
│   │  • skills/status-map/SKILL.md         (status templates)      │   │
│   │  • protocols/delegation/{init,dna,finalize}-prompt.md  (GaaS) │   │
│   │  • agents/{orchestrator,consolidator,sentinel-monitor}.md     │   │
│   │  • sentinel/{config.json,detection_rules.md}                  │   │
│   └───────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. Current state (v0.1.0 baseline shipped 2026-05-17)

- **PR**: [ekson73/multi-agent-os#65](https://github.com/ekson73/multi-agent-os/pull/65) merged as commit `7f8fd64` (squash) on 2026-05-17 (HITL authorized scope-limited per [`[C07]`](https://github.com/ekson73/vek-dot-claude/blob/main/CLAUDE.md) v2.1.0).
- **Bot convergence achieved (PDCA per [`pr-review-protocol`](https://github.com/ekson73/vek-dot-claude/blob/main/rules/pr-review-protocol.md) v2.0.0)**: amazon-q `SUCCESS` + Copilot `SUCCESS` + gitleaks `SUCCESS` + Trivy x2 `SUCCESS` + pip-audit `SUCCESS` + OpenSSF `SUCCESS` + governance-validation `SUCCESS`. Out-of-action: CodeRabbit (rate-limit + credits zerados — `pr-review-protocol` §4 escape clause); Qodo (paid-seat — out of scope).
- **Capabilities shipped**:
  - 4 delegation modes: `sequential` · `parallel` · `recursive` · `debate-converge`
  - 2 operator-facing aliases: `dueto` (parallel N=2) · `swarm` (parallel N≥3)
  - 3 autonomy bands: `L1-cautious` · `L2-bounded` (default) · `L3-extended`
  - DNA Payload v1.1 additive (parent_agent_id · depth ≤ 2 · mode · autonomy_band · goal_root · attempts_remaining · escalation_triggers)
  - Goldilocks ≤ 12 KB SKILL.md ceiling enforced
- **Follow-up issues created** (community sub-issues for v0.2+ axes):
  - [#67 N3 Archetypal-persona library](https://github.com/ekson73/multi-agent-os/issues/67)
  - [#68 N4 9-factor autonomy matrix](https://github.com/ekson73/multi-agent-os/issues/68)
  - [#69 N5 Multi-vendor MCP channel layer](https://github.com/ekson73/multi-agent-os/issues/69)
  - [#70 7-perspective comparative-research artifact](https://github.com/ekson73/multi-agent-os/issues/70)
- **Umbrella tracker (user-scope dependency)**: operator-private (not enumerated in this community doc — tracked in operator's private `~/.claude/` repo).
- **Plan-mode artifact**: [`ekson73/vek-dot-claude#47`](https://github.com/ekson73/vek-dot-claude/pull/47) — submitted 2026-05-17, contains §0-§16 of the strategic plan that drove this master-plan.

---

## 4. Phase-1 critical findings (must be addressed in v0.2)

| # | Finding | Severity | Source |
|---|---|---|---|
| F1 | **~80% functional overlap** entre `auto-pilot` community e [`auto-orchestrator`](https://github.com/ekson73/vek-dot-claude/blob/main/skills/auto-orchestrator/SKILL.md) user-scope (latter is AAIF-compliant superset: 5 companion subagents + 6-factor autonomy_score + goal-aware STOP markers + 5-path PR interaction + 12-role universal diversity matrix) | HIGH | Differential read 2026-05-17 |
| F2 | **Schizophrenia interna**: [`skills/auto-pilot`](https://github.com/ekson73/multi-agent-os/blob/main/skills/auto-pilot/SKILL.md) universal #1 "no auto-merge" CONFLITA com L3-extended "auto-merge of green-bot PRs" (fail Self-Application Test per `[C17]` §11) | HIGH | Same-file contradiction |
| F3 | **Inconsistência numérica**: auto-pilot depth cap=2 hard vs auto-orchestrator depth cap=3 Phase 0.5 — qual é canônico? | MED | Cross-skill diff |
| F4 | **Over-engineering candidate**: `dueto`/`swarm` aliases adicionam vocabulário sem diferenciação real (são `parallel` com N=2/N=3) | MED | SKILL.md Delegation modes table |
| F5 | **Strategic blind-spot**: `auto-pilot` §Related NÃO referencia `auto-orchestrator` — drift community ↔ user-scope **invisibilizado** | HIGH | §Related audit |
| F6 | **Missing empirical grounding**: design não cita AutoGPT pivot (unbounded autonomy abandonado 2024), 47.8% completion em 7-step chains (90%^7), [CrewAI](https://www.crewai.com/) hierarchical manager (−40% failures), [AutoGen Magentic-One](https://www.microsoft.com/en-us/research/blog/magentic-one-a-generalist-multi-agent-system-for-solving-complex-tasks/) dual-ledger, [LangGraph](https://langchain-ai.github.io/langgraph/) state-machine, [OpenHands](https://github.com/All-Hands-AI/OpenHands) Docker sandboxing, [AAIF spec](https://agentskills.io/specification) compliance | HIGH | Agent-3 web research 2026-05-17 |
| F7 | **No goal-aware mode**: `auto-orchestrator` tem §5.5/§7.0 canonical STOP-* markers (`<!--ORCH-STATUS: STOP-DONE/HITL/ERROR/CONTINUE -->`); `auto-pilot` não tem | MED | Differential read |
| F8 | **Naming theater risk**: `auto-pilot` vs `auto-orchestrator` operator confusion previsível (Q1 do UP review [#47](https://github.com/ekson73/vek-dot-claude/pull/47) §8 ainda em aberto) | MED | UP review |

---

## 5. Four proposals for v0.2 (to be debated via Git-PR-as-Debate-Prompt)

| ID | Proposal | Stance |
|---|---|---|
| **A** | **Status-quo refinement**: v0.1.0 as shipped → v0.2 adds N3 archetypes ([#67](https://github.com/ekson73/multi-agent-os/issues/67)) only; fix F2/F3/F5/F7 as patches | Conservative |
| **B** | **Thin wrapper**: `auto-pilot` becomes community-facing facade que internally delegates a `auto-orchestrator` v1.1.0 (canonical engine no user-scope) | Hybrid / Reuse-max |
| **C** | **v0.2 tight integration**: keep `auto-pilot` como engine MAS absorve `auto-orchestrator`'s superior features (6-factor score + goal-aware markers + companion subagents + 5-path PR) e reconcilia drift | Evolutionary |
| **D** | **Deprecate community auto-pilot**: importar `auto-orchestrator` para multi-agent-os como canonical entry point; renomear para `auto-orchestrator` na community também. Single brand, single engine | Radical / Sole-source |

Selection criteria during debate (per [`skills/converge`](../../skills/converge/SKILL.md) §ACT 3): dimensions × proposals × verdict × rationale, with parity enforcement (each proposal contributes BOTH kept + rejected elements per §ACT 5).

---

## 6. Roadmap (post-convergence, version-gated)

| Version | Scope | Gate |
|---|---|---|
| **v0.1.0** ✅ | shipped 2026-05-17 (this baseline) | merged |
| **v0.2.0** (post-debate) | F1-F8 addressed per debate verdict + N3 archetypes [#67](https://github.com/ekson73/multi-agent-os/issues/67) | ≥ 2 dogfood cycles · ≤ 12 archetypes · §11 Quality Tests 6/6 |
| **v0.3.0** | N4 9-factor autonomy matrix [#68](https://github.com/ekson73/multi-agent-os/issues/68) | ≥ 3 real decisions per band logged · empirical calibration |
| **v0.4.0** | N5 MCP channel layer [#69](https://github.com/ekson73/multi-agent-os/issues/69) + DNA v1.x bump iff schema delta | cross-vendor round-trip test (Claude↔Cursor↔Codex) |
| **v0.5.0** | 7-perspective comparative-research artifact [#70](https://github.com/ekson73/multi-agent-os/issues/70) — docs-only, **before v1.0** | informational not gating |
| **v1.0.0** | Stabilization · all axes converged · ≥ 3 cumulative dogfood cycles | full §11 Quality Tests 6/6 + §0 SER PASS on entire stack |
| ~~**v2.0.0**~~ | ~~AAIF certification~~ — **DROPPED** v3.1 (sem certifying body / test suite / rubric concretos); v1.x evolves open-ended; revisit if cross-vendor spec materializes | TBD |

---

## 7. Ecosystem cross-references

### Community (open-source, MIT)

- This repo: [`ekson73/multi-agent-os`](https://github.com/ekson73/multi-agent-os) — auto-pilot skill + protocols + sentinel + sister skills
- Marketplace (personal/community): [`ekson73/eko-claude-plugins`](https://github.com/ekson73/eko-claude-plugins)

### User-scope (operator's private master)

- [`ekson73/vek-dot-claude`](https://github.com/ekson73/vek-dot-claude) — operator's private `~/.claude/` master (rules · skills · plans · commands · agents); contains `auto-orchestrator` skill v1.1.0 + governance frameworks (private to operator's setup)

### Corp-layer (community-decoupled per layer-purity — NOT enumerated here)

Per `layer-precedence-policy` Rule 2 (unidirectional purity), this community master-plan does NOT enumerate corp-specific paths/repos/acronyms. Corp adopters maintain their own private layer (out of scope of this document) and consume the community kernel without contributing corp-specific content upstream.

### Sister artifacts within this repo

- [`skills/auto-pilot/SKILL.md`](../../skills/auto-pilot/SKILL.md) — skill body (v0.1.0)
- [`skills/converge/SKILL.md`](../../skills/converge/SKILL.md) — 5-act debate-convergence (v1.1.1)
- [`skills/agent-select/SKILL.md`](../../skills/agent-select/SKILL.md) — perspective routing
- [`skills/delegate-governance/SKILL.md`](../../skills/delegate-governance/SKILL.md) — GaaS framework
- [`commands/auto-pilot.md`](../../commands/auto-pilot.md) — operator command surface
- [`protocols/delegation/`](../../protocols/delegation/) — init/dna/finalize prompts
- [`sentinel/`](../../sentinel/) — anomaly detection rules
- [`.claude/rules/pr-reviewer-communication.md`](../../.claude/rules/pr-reviewer-communication.md) — PR comment convention (bot mentions)
- [`docs/auto-pilot/GIT-PR-AS-DEBATE-PROMPT.md`](./GIT-PR-AS-DEBATE-PROMPT.md) — methodology + templates

---

## 8. Decision log (placeholder — populated by debate ADRs)

> Entries appended chronologically post-convergence. Each entry: ID · date · proposal-chosen · rationale · rejected alternatives · evidence · provenance.

- **ADR-001** (pending — to be created by debate cycle): auto-pilot architecture (chosen among A/B/C/D)
- ...

---

## 9. Quality gates (every master-plan edit MUST pass)

| Gate | Check |
|---|---|
| Anti-theater REALITY 8/8 | Real · ¬Theater · ¬Hallucinated · ¬Invented · Viable · Applicable · Implementable · Useful |
| §11 Quality Tests 6/6 | Self-Application · Non-Contradiction · Survival · Bounded-Responsibility · Explicit-Exception · Utility-Sunset |
| §0 SER > Rules | Rule-application HELPS operator NOW? (skip + log se OBSTRUCTS) |
| Goldilocks ceiling | Master-plan ≤ 5 KB summary; sub-docs linked, not inlined |
| Scope-discipline 6Q | Q1 WHERE · Q2 WHAT-exists · Q3 WHY-now · Q4 WHO-for · Q5 HOW-fits · Q6 MIN-form |

---

## 10. Changelog

| Version | Date | Change |
|---|---|---|
| v0.2-draft | 2026-05-17 | Initial master-plan draft — captures v0.1.0 baseline + F1-F8 findings + 4 proposals A/B/C/D + roadmap + ecosystem cross-refs. PRE-CONVERGENCE: aguarda Git-PR-as-Debate cycle output. |
