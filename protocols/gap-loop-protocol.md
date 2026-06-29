# Gap-Loop Protocol — Harness-Agnostic Convergence-Loop Methodology

> **Shared reference / extracted methodology** for `skills/gap-loop` (its runnable embodiment) —
> and a **citable vocabulary** that sibling orchestration skills (`quiesce`, `convergence-engine`,
> `auto-pilot`, `enhance-pipeline`) MAY adopt without duplicating it.
> **Version**: 1.0.0 (2026-06-29)
> **Scope**: AAIF cross-vendor. Vendor-neutral; runs in cowork / Claude Code / SDK / Cursor / Codex / Gemini / Copilot.
> **Lineage**: distilled (meta-concept extraction) from the operator's `--goal-n-loop` prompt; composes
> `skills/converge` (5-act), `skills/convergence-engine` (master condition + economic stop),
> `agents/perspective-trio` + `agents/persona-pipeline` (MoE breadth/depth), `agents/cascade-resolver`
> (score formula + 12-role rotation), `agents/forge` (Forge + 33-Socratic), `skills/decision-capture` (ASH audit).
> Complements `quiesce` (which composes the native `/goal` loop) by NOT depending on `/goal`.

This document is the common methodology. Read it once; the skill references it instead of inlining
the rationale, and siblings can cite a concept by name (e.g. "apply Gap-Loop §3 SCORE rule").

---

## §0 — BEING > Rules (foundational)

The loop serves the goal, not the reverse. *"BEING > law; law serves the goal; any rule admits a
justified exception (SDP — documented justification)."* This is the global §0 SER>Regras made
loop-local; it is the `--principle-exception` escape and overrides any §below in genuine conflict.

---

## §1 — The 10 meta-concepts (the M.O.)

Distilled from `--goal-n-loop`. ★ = net-new to the MAOS family; ○ = composes an existing primitive.

1. ★ **Harness-Agnostic Declarative Condition-Loop** (§2) — the loop is expressed declaratively;
   the agent self-evaluates the predicate each turn. No `/goal` slash-command dependency.
2. ○ **Gap-Register-Driven Resolution** (§2) — a goal is decomposed into a deduplicated, IDed
   gap-register (G1..Gn); each gap is *dispositioned*; full disposition is a termination condition.
3. ○ **MoE Diverge→Converge per Gap** (§4) — >=2 diverse experts + 1 arbiter run the 5-act `converge`.
4. ○ **Independent Validation (verifier != generator)** (§4) — the audit uses experts DIFFERENT
   from the resolve step (the `convergence-engine` master condition).
5. ★ **Anti-Gaming Derived Score** (§3) — `autonomy_score` is derived, per-dimension, names its binding constraint.
6. ★ **Low-Score → New-Perspectives Re-Loop** (§3) — rotate the roster (same panel FORBIDDEN), NOT HITL.
7. ★ **HITL-as-Problem Classification (SOFT vs HARD)** (§5).
8. ○→★ **Socratic-Depth=N Gate** (§4) — question-bank from SSOT at parameterized depth; don't hardcode "33".
9. ○ **Persist + Boy-Scout DoD** (§6) — decision-audit + reject-log + tickets + leave-cleaner + STAGE-only git.
10. ○ **Principle-Exception meta-rule** (§0) — BEING > law; justified exception (SDP).

---

## §2 — The loop (declarative, self-driven)

```text
TERMINATION — keep looping until ALL true; do NOT stop early:
  CONVERGED := ( every gap DISPOSITIONED — fix-applied | deferred-with-rationale | accepted-as-risk )
             AND ( agentic CONVERGENCE — >=2 dissenting positions reconciled into ONE synthesis + reject-log )
             AND ( autonomy_score >= 0.85, DERIVED + evidence-backed — §3 )

BOUNDS: autonomy-band=L2-unattended (set via --autonomy-threshold) · --max-iterations=6 ·
        --principles=[DRY,SSOT,KISS,YAGNI,ANTI-OVER-ENG,ANTI-THEATER,CONTINUITY,HAND-OFF,BOY-SCOUT] ·
        --principle-exception="documented justification (SDP)" · --meta-rule="BEING > law"

PHASES (per round):
  0 DoR     precheck state; branch+worktree isolation (anti-conflict); SSOT targets reachable; abort-with-reason if unmet.
  1 RECAP   from one state-source enumerate [purposes, plan, roadmap, open-problems, gaps, pending]
            -> deduplicated IDed gap-register (G1..Gn). Inject prior HITL / low-score items as gaps. (no hallucination.)
  2 RESOLVE per gap: >=2 DIVERSE experts (Forge if competency absent) + 1 arbiter; 5-act converge
            [steelman -> critique -> compare -> synthesize -> reject-log];
            output {decision, rationale, rejected-alternatives, residual-risk, confidence}.
  3 VALIDATE independent audit (experts != Phase 2); Socratic gate (--socratic-depth=N); Sentinel audit;
            any FAIL re-enters Phase 2 as a gap; compute autonomy_score (§3) -> drives the loop.
  4 PERSIST decision-audit + convergence-report + reject-log + tickets + boy-scout (§6).
```

**Harness-agnostic**: on Claude Code MAY pair with `/goal --goal-aware` (free Stop-hook evaluator);
on cowork/SDK/other the agent self-evaluates the predicate and emits ONE STOP marker per turn. The
methodology never *requires* a slash-command — that is the seam it fills relative to `quiesce`.

---

## §3 — Anti-gaming SCORE rule + Low-score re-loop

- `autonomy_score` is **DERIVED, never declared** — it MUST trace to dispositioned gaps + Phase-3
  audit results. Each round emits a **per-dimension breakdown** (viability · security · usability ·
  convergence-quality · residual-risk · ...) and **NAMES the binding constraint** (the dimension
  dragging the score down). Score asserted without that trace = invalid (anti-theater R2).
  Reuse `agents/cascade-resolver` autonomy_score formula + `convergence-engine` master condition + economic stop.
- **Low-score → re-loop, NOT HITL** (while `iteration < max-iterations`): open a NEW round targeting
  the binding constraint with NEW perspectives — **rotate the MoE roster (re-running the same panel
  is FORBIDDEN)** · add a red-team seat · re-frame the weakest dimension · Forge a missing competency.
  Escalate the whole goal only when `iteration >= max-iterations` AND score still `< threshold`
  (park-state + SDP). If the binding constraint is a HARD gate (§5) → escalate THAT item only and
  CONTINUE the loop on remaining gaps.

---

## §4 — RESOLVE (MoE) + VALIDATE (independent) + Socratic gate

- **RESOLVE** (per gap): roster = >=2 DIVERSE experts (`perspective-trio`; Forge via `agents/forge`
  if a competency is absent) + 1 arbiter; protocol = `converge` 5-act (steelman→critique→compare→
  synthesize→reject-log). The reject-log is first-class (non-lossy).
- **VALIDATE** (independent): experts DIFFERENT from RESOLVE (verifier != generator) — `persona-pipeline`
  6-stage board + `sentinel` audit. Validate [plan, roadmap, tools, context, scope, viability,
  implementability, usability, over-eng, theater, risks+mitigations, best-practices, security].
- **Socratic gate**: `--socratic-depth=N`, drawn from SSOT (`agents/forge` §33-Socratic /
  `skills/maos-concierge/references/socratic-33q.md`). **Do NOT hardcode "33"** — depth is parameterized.

---

## §5 — HITL-as-problem (SOFT vs HARD)

Every HITL is an UNSOLVED PROBLEM; classify before escalating:
- **SOFT** (deliberation can solve): low-confidence | resolvable ambiguity | missing context |
  missing perspective | competency gap → re-inject as a gap; run a new-perspectives round (§3).
  *Premise: the answer is usually latent in training — the job is to INVOKE it* (AI-as-PwD §3.3).
  SOFT becomes a real HITL only after `max-iterations`.
- **HARD** (authority boundary — looping cannot dissolve it): irreversible/high-cost authorization |
  destructive op | credentials/secrets | safety → escalate IMMEDIATELY; never self-authorize.

---

## §6 — PERSIST + Boy-Scout DoD

- per-decision → decision-audit (`skills/decision-capture` / `agentic-decide`).
- convergence-report + reject-log → docs / Confluence.
- gap-closures + residuals → tickets via `maos:postflight` P2.5 TICKET-SYNC (a capability-detected ticketing primitive, ref `ticket-as-prompt`; in-repo SSOT `skills/postflight/references/ticket-sync-protocol.md`).
- boy-scout: leave touched artifacts cleaner than found (`maos:postflight` P1-SWEEP).
- **STAGE-only git unless authorized** (EKO-66): never push/merge without explicit operator authorization.

**DoD**: gap-register fully dispositioned · convergence synthesis + reject-log exist · Socratic gate
passed · `autonomy_score >= 0.85` (evidence-backed) · artifacts persisted · every escalation classified
(SOFT looped / HARD escalated) and logged.

---

## §7 — Adoption notes (for siblings — DRY)

- `quiesce` MAY adopt §5 (SOFT/HARD) + §3 (derived score) to enrich its HITL handling; its outer loop
  stays `/goal`-based, gap-loop's stays declarative.
- `convergence-engine` already owns the master condition + economic stop; this protocol REUSES them
  (it does not redefine them) — §3 cites them.
- The methodology is cross-vendor; replace named primitives with the host's equivalents where absent.

## §8 — Sunset (qualitative — not counter-based)

Deprecate when ANY: a host makes a declarative condition-loop universal so `quiesce` covers cowork/SDK
too (E1) · the family absorbs gap-loop into a unified loop entry (E6) · operator retraction (E4) ·
>=3 false-positive runs (E5). Dormant-by-design otherwise.

## §9 — Refs

- `skills/gap-loop/SKILL.md` (runnable embodiment) · `commands/gap-loop.md`
- `skills/quiesce` · `skills/convergence-engine` (+ `PRIOR-ART.md`) · `skills/converge` · `skills/pulse`
- `agents/perspective-trio.md` · `agents/persona-pipeline.md` · `agents/cascade-resolver.md` · `agents/forge.md`
- `skills/decision-capture` · `maos:postflight` P2.5 (ticketing, ref `ticket-as-prompt`) · `sentinel/detection_rules.md`
- `protocols/agentic-tool-lifecycle.md` (shared-protocol precedent)
- External grounding inherited from `skills/convergence-engine/PRIOR-ART.md` (Du et al. 2023 society-of-minds;
  Madaan 2023 Self-Refine; Huang 2024 verifier>generator; multi-agent-debate).
