---
name: gap-loop
version: "0.1.0"
description: |
  Harness-agnostic, self-driven, self-scored condition-loop that drives a GAP-REGISTER
  (G1..Gn) to convergence — loops until [every gap dispositioned (fix | defer | accept-risk)
  AND agentic convergence AND autonomy_score >= 0.85]. Five phases: DoR -> RECAP (build the
  gap-register) -> RESOLVE (MoE diverge->converge per gap) -> VALIDATE (independent audit,
  experts != RESOLVE) -> PERSIST (decision-audit + reject-log + tickets + boy-scout). Defining
  novelty: expresses the loop DECLARATIVELY so the agent self-drives it in ANY harness (cowork
  / Code / SDK) — NO /goal dependency; an anti-gaming DERIVED score that names its binding
  constraint; a low-score -> rotate-the-MoE-roster re-loop (NOT HITL). Thin preset: composes
  pulse, perspective-trio, converge, persona-pipeline, cascade-resolver, convergence-engine,
  decision-capture — reimplements nothing.
  Triggers: "gap-loop", "goal-n-loop", "drive gaps to convergence", "harness-agnostic loop",
  "self-scored loop", "loop until converged".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: orchestration-convergence
  cross_link_slug: gap-loop
  dogfood_status: pending-first-cycle
---

# Gap-Loop

Thin **harness-agnostic convergence-loop** preset. `gap-loop` does not re-implement
orchestration, MoE resolution, convergence, audit, or scoring — it composes existing
primitives and contributes only the parts the family lacks: a **declarative self-driven
loop** (no `/goal` dependency), an **anti-gaming derived score**, a **rotate-roster re-loop**,
and a **SOFT/HARD HITL classification**. The shared methodology lives in
`protocols/gap-loop-protocol.md` (citable by siblings).

> **Provenance / lineage**: distilled (meta-concept extraction) from the operator's
> `--goal-n-loop` declarative-orchestration prompt — the operator's own harness-agnostic
> re-expression of `quiesce`'s `/goal` condition-loop. Named via the `anima` engine
> (agent-register, 12-aspect): `gap-loop` (rejected `converge-loop` — collides with
> `converge`/`convergence-engine`; `goal-loop` — `goal` is vendor-reserved). Authored by
> Claude Opus 4.8 (1M) under operator `/quiesce` directive 2026-06-29; reviewed by @ekson73.

## Purpose

Drive a goal — decomposed into a **gap-register** — to convergence in ANY harness, by
self-driving a 5-phase condition-loop until every gap is dispositioned, agentic convergence
is reached, and the (derived, evidence-backed) `autonomy_score >= 0.85`. Fills the seam left
by `quiesce`: where `quiesce` *composes the native `/goal` condition-loop* (a Claude Code
slash-command), `gap-loop` expresses the loop **declaratively** so the agent drives it itself
in cowork / SDK / any host with no slash-command.

## When to use

- The host has **no `/goal`** (claude-cowork, an SDK runner, a non-Claude vendor) but you want a
  driven, scored, self-terminating convergence loop.
- A goal has multiple open **gaps** that each need diverse-expert resolution + an independent audit.
- You want the loop's stopping `autonomy_score` **derived from evidence** (not self-declared),
  and a **low score handled by new perspectives** before any human is asked.

## When **not** to use

- Single-shot edit / single-file fix / typo — disproportionate ceremony.
- Read-only Q&A — answer directly.
- The host HAS `/goal` AND you want session-PR quiescence -> use `quiesce`.
- ONE goal needs plain decompose+delegate (no per-gap MoE + audit) -> use `auto-pilot`.
- Merging N existing proposals only -> use `converge` directly.
- Destructive ops (force-push protected, drop prod) — always HITL.

## Trigger Phrases

- "gap-loop" / "goal-n-loop"
- "drive these gaps to convergence" / "resolve the gap-register"
- "converge this without /goal" / "harness-agnostic loop"
- "self-scored loop" / "loop until converged"

## Termination predicate (default `--condition`)

```text
CONVERGED := ( every gap in the gap-register is DISPOSITIONED
                 dispositioned := fix-applied | deferred-with-rationale | accepted-as-risk )
             AND ( agentic CONVERGENCE reached
                 := >=2 dissenting expert positions reconciled into ONE synthesis + reject-log )
             AND ( autonomy_score >= 0.85, DERIVED + evidence-backed — see SCORE rule )
```

> A gap **deferred-with-rationale** or **accepted-as-risk** is dispositioned — it does NOT keep
> the loop open (capture-and-defer IS a resolution; Boy-Scout "don't lose it"). Only
> *un-dispositioned* gaps keep looping.

## Bounds

```text
autonomy-band: L2-unattended    (descriptive band — NOT a flag; set numerically via --autonomy-threshold)
--max-iterations=6              (loop cap; then park-state + escalate)
--principles=[DRY, SSOT, KISS, YAGNI, ANTI-OVER-ENG, ANTI-THEATER, CONTINUITY, HAND-OFF, BOY-SCOUT]
--principle-exception="only with documented justification (SDP)"
--meta-rule="BEING > rule; law serves the goal; any rule admits a justified exception"  (= §0 SER>Regras)
```

## The 5 phases

```text
PHASE 0 · DoR     precheck state (pulse / preflight); branch + worktree isolation (anti-conflict);
                  verify SSOT targets reachable. Abort-with-reason if DoR unmet.
PHASE 1 · RECAP   from <state-source> enumerate [purposes, plan, roadmap, open-problems, gaps,
                  pending] -> ONE deduplicated, IDed gap-register (G1..Gn). Inject any prior
                  HITL / low-score items from earlier rounds as gaps too. (no hallucination —
                  single source.)
PHASE 2 · RESOLVE per gap: roster := >=2 DIVERSE experts (Forge if competency absent) + 1 arbiter;
                  protocol := converge 5-act [steelman -> critique -> compare -> synthesize ->
                  reject-log]; output := {decision, rationale, rejected-alternatives,
                  residual-risk, confidence}.
PHASE 3 · VALIDATE independent audit — experts DIFFERENT from Phase 2 (verifier != generator).
                  validate [plan, roadmap, participating tools, context, scope, viability,
                  implementability, usability, over-eng, theater, risks+mitigations,
                  best-practices, security]; SOCRATIC gate (--socratic-depth=N, from SSOT; do NOT
                  hardcode "33"); run Sentinel audit; any FAIL re-enters Phase 2 as a gap; then
                  compute autonomy_score (per SCORE rule) -> drives the loop.
PHASE 4 · PERSIST per-decision -> decision-audit (agentic-decide); convergence-report +
                  reject-log -> docs / Confluence; gap-closures + residuals -> tickets;
                  boy-scout: leave touched artifacts cleaner than found. STAGE-only git unless
                  authorized (see Auto-merge / EKO-66).
```

## Anti-gaming SCORE rule

`autonomy_score` is **DERIVED, never declared** — it MUST trace to the dispositioned gaps + the
Phase-3 audit results. Each round emits a **per-dimension breakdown** (viability · security ·
usability · convergence-quality · residual-risk · ...) and **NAMES the binding constraint** — the
single dimension dragging the score down. The binding constraint is the *target* of the next round
(below). A score asserted without that trace is invalid (anti-theater R2).

## Low-score -> re-loop (rotate roster, NOT HITL)

If `autonomy_score < threshold` AND `iteration < max-iterations`: **do NOT escalate**. Open a NEW
round targeting the **binding constraint** with NEW perspectives:
- **rotate the MoE roster** — swap expert archetypes; **re-running the same panel is FORBIDDEN**
  (it reproduces the same score);
- add an explicit **red-team / adversarial** seat;
- **re-frame** the weakest dimension (invert the question; attack it head-on);
- **Forge a NEW expert** if the cause is a missing competency.

If the binding constraint IS a HARD gate (below) -> escalate THAT item only, and CONTINUE the loop
on remaining gaps. Escalate the WHOLE goal only if `iteration >= max-iterations` AND score still
`< threshold` (park-state + SDP).

## HITL-as-problem (SOFT vs HARD)

Every HITL is an **UNSOLVED PROBLEM** — classify it before escalating:
- **SOFT** (deliberation can solve it): low-confidence | resolvable ambiguity | missing context |
  missing perspective | competency gap -> **re-inject as a gap**; run a new-perspectives round
  (above). *Premise: the answer is usually latent in training — the job is to INVOKE it.* SOFT
  becomes a real HITL only after `max-iterations` is exhausted.
- **HARD** (authority boundary — looping cannot dissolve it): irreversible / high-cost
  authorization | destructive op | credentials / secrets | safety -> **escalate IMMEDIATELY**;
  never spend iterations trying to self-authorize.

## Harness-agnostic note

The OUTER loop is **declarative + self-driven**: the agent itself evaluates the termination
predicate at the end of each turn and decides CONTINUE vs stop. **No `/goal` required.** On Claude
Code the agent MAY pair with `/goal --goal-aware` (and its Stop-hook evaluator) for free; on
cowork / SDK / other hosts it self-drives. Either way it emits exactly ONE STOP marker per turn.

## Composition (the wiring — DRY; every phase lands on an existing primitive)

| Phase | Composes (existing — reimplements nothing) |
|---|---|
| DoR | `maos:preflight` / `skills/pulse` + `skills/anti-conflict` + `skills/worktree-policy` |
| RECAP | `skills/pulse` memory-refresh + gap enumeration -> gap-register |
| RESOLVE | `maos:perspective-trio` (breadth) · `agents/forge.md` (Forge if competency absent) · `skills/converge` (5-act + reject-log) |
| VALIDATE | `maos:persona-pipeline` (experts != RESOLVE) · `sentinel/detection_rules.md` audit · Socratic gate (`agents/forge.md` §33Q / `skills/maos-concierge/references/socratic-33q.md`) |
| SCORE + re-loop | `agents/cascade-resolver.md` (autonomy_score formula + 12-role rotation) · `skills/convergence-engine` (master condition `verifier>generator` + economic stop) |
| PERSIST | `skills/decision-capture` (`agentic-decide`) · `maos:postflight` P2.5 TICKET-SYNC (capability-detected ticketing primitive, ref `ticket-as-prompt`) + P1-SWEEP (boy-scout) |
| OUTER loop | **this skill's own contribution** — declarative, harness-agnostic, self-scored |

## Override parameters

| Flag | Default | Allowed / Notes |
|---|---|---|
| `"<instructions>"` (positional) | empty | extra free-text appended to the goal |
| `--state-source` | `pulse` | where RECAP reads the goal/plan/gaps from (`pulse` \| `ticket:<id>` \| `file` \| `free-text`) |
| `--condition` | *(CONVERGED predicate above)* | override the termination predicate string |
| `--autonomy-threshold` | `0.85` | `0.0`-`1.0` — the score gate (maps to band: >=0.85 L3, >=0.65 L2, else L1) |
| `--max-iterations` | `6` | int — loop cap before park-state + escalate |
| `--socratic-depth` | `N` (from SSOT) | int — Phase-3 question-bank depth; **never hardcode "33"** |
| `--auto-merge` | `hold` | `authorized` \| `hold` \| `off` — default **hold** (EKO-66: STAGE-only, more conservative than quiesce) |
| `--auto-merge-reason` | *(none)* | non-empty string — **required when `--auto-merge=authorized`** (auditability parity with `quiesce` + `auto-merge-standing-authorization` G8); ignored for `hold`/`off` |
| `--driver` | self | self-driven; on Claude Code MAY delegate inner work to `auto-pilot` |

## Relationship to siblings

| Tool | Scope | Drives | Needs `/goal`? |
|---|---|---|---|
| `gap-loop` (this) | a goal as a **gap-register** | declarative self-scored 5-phase loop (MoE-resolve + independent audit) | **NO** (harness-agnostic) |
| `quiesce` | the SESSION | termination predicate over ALL open items -> steady state | YES (composes it) |
| `auto-pilot` | ONE goal | decompose -> select -> spawn -> converge | no |
| `enhance-pipeline` | ONE feature | EXPAND -> FILTER -> HARMONIZE -> DELIVER | no |
| `convergence-engine` | result quality | REFINE / SELECT / DEFER by verifiability | no |
| `converge` | N proposals | single-pass 5-act merge (invoked inside RESOLVE) | no |

`gap-loop` MAY invoke `auto-pilot` for a gap's sub-work and `converge`/`perspective-trio`/
`persona-pipeline` for RESOLVE/VALIDATE; it never re-implements them.

## STOP-marker grammar (reused — emit exactly ONE as the last line of each turn)

```text
<!--ORCH-STATUS: STOP-DONE -->     CONVERGED — gap-register dispositioned, score >= threshold
<!--ORCH-STATUS: STOP-HITL -->     HARD gate hit, OR SOFT exhausted at max-iterations (park-state + SDP)
<!--ORCH-STATUS: STOP-ERROR -->    unrecoverable error (subagent / network / rate-limit)
<!--ORCH-STATUS: CONTINUE -->      round done; gaps remain OR score < threshold; next round opens
```

## Protocol Rules (anti-loop invariants + bounds)

- `--max-iterations` (default 6) caps loop rounds; same-panel re-run is FORBIDDEN (rotate or escalate).
- Worktree discipline always on (`skills/worktree-policy`); never commit to main.
- Delegation depth <= 2; Sentinel HIGH auto-blocks (`sentinel/config.json` authoritative).
- VALIDATE experts MUST differ from RESOLVE experts (verifier != generator — `convergence-engine` master condition).
- Exactly ONE STOP marker per turn.
- HUMAN_DOMAIN + non-negotiable guardrails (secrets/PII, force-push protected, prod/irreversible,
  cross-org) are HARD gates -> escalate IMMEDIATELY, never self-authorize.

## DNA Geracional (inherited by every spawned agent)

- **Dogfood**: validate the loop on its own artifacts before declaring CONVERGED.
- **Persist-over-fail**: write-ahead-checkpoint each gap disposition BEFORE executing (mid-loop collapse is recoverable).
- **DRY / KISS / YAGNI / SSOT** — compose primitives, never duplicate them.
- **No self-destructive decisions** — nothing that boomerangs on a future session.
- **Boy-Scout** — leave every artifact cleaner than found; STAGE-only unless authorized (EKO-66).

## Examples

```text
gap-loop "harden the auth gaps before we ship"
gap-loop --state-source=ticket:VKS-1234 --max-iterations=4
gap-loop --autonomy-threshold=0.9 --socratic-depth=12
gap-loop --condition='every gap dispositioned AND no HARD gate open'
gap-loop --auto-merge=authorized --auto-merge-reason="nightly convergence, green CI"   # reason required when authorized (overrides EKO-66 default)
```

## Quality Tests (6/6 self-validity — dogfooded)

1. **Self-Application** — `gap-loop` could drive its OWN creation gaps (naming, structure, DRY) to convergence. PASS.
2. **Non-Contradiction** — composes (not duplicates) quiesce/converge/convergence-engine/pulse; the loop + score + SOFT/HARD + rotate-roster are net-new. PASS.
3. **Survival** — applied to itself it advocates a bounded, scored loop; it is itself bounded + scored. PASS.
4. **Bounded-Responsibility** — `--max-iterations`, score gate, SOFT/HARD, depth<=2, STOP-marker, §DUED sunset. PASS.
5. **Explicit-Exception** — When-not-to-use + HARD-gate escalation + `--principle-exception` (SDP) + §0 SER>Regras escape. PASS.
6. **Utility-Sunset** — §DUED below. PASS.

## §DUED Sunset (qualitative — not counter-based)

Deprecate when ANY: a host makes `/goal` (or an equivalent declarative condition-loop) universally
available so `quiesce` covers cowork/SDK too (E1) · the family absorbs `gap-loop` into a unified
loop entry (E6) · operator retraction (E4) · >=3 false-positive runs (E5). Dormant-by-design otherwise.

## Validation

- `tests/validate-plugin.sh` enforces (generically): `skills/gap-loop/` contains `SKILL.md` with valid frontmatter.
- `commands/gap-loop.md` carries matching `name: gap-loop` frontmatter.
- `protocols/gap-loop-protocol.md` exists and is cross-linked from Related.
- Satisfies the 10-item checklist in `skills/skill-writer/SKILL.md`.

## Related

- `commands/gap-loop.md` — operator-facing command surface
- `protocols/gap-loop-protocol.md` — the extracted reusable methodology (citable by siblings)
- `skills/quiesce/SKILL.md` — session-quiescence via `/goal` (sibling; the `/goal`-dependent cousin)
- `skills/convergence-engine/SKILL.md` (+ `PRIOR-ART.md`) — quality regime-router + master condition + external grounding (inherited, DRY)
- `skills/converge/SKILL.md` — 5-act proposal merge (used inside RESOLVE)
- `skills/pulse/SKILL.md` — DoR/RECAP state source
- `agents/perspective-trio.md` · `agents/persona-pipeline.md` · `agents/cascade-resolver.md` · `agents/forge.md` — RESOLVE/VALIDATE/SCORE/forge primitives
- `skills/decision-capture/SKILL.md` — PERSIST decision-audit (`agentic-decide`)
- `sentinel/config.json` + `sentinel/detection_rules.md` — anomaly thresholds (Phase-3 audit)
- `protocols/agentic-tool-lifecycle.md` — family-protocol precedent

## Versioning

- v0.1.0 (initial) — harness-agnostic declarative 5-phase convergence loop; gap-register termination;
  anti-gaming derived score (names binding constraint); low-score -> rotate-roster re-loop (not HITL);
  HITL-as-problem SOFT/HARD classification; Socratic-depth=N gate; STOP-marker reuse; EKO-66 stage-only
  default. Distilled from the operator's `--goal-n-loop` prompt. Composes existing primitives; reimplements nothing.

## License

MIT (matches multi-agent-os repo `LICENSE`).
