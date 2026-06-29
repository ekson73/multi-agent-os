# Gap-Loop Protocol — Harness-Agnostic Convergence-Loop Methodology

> **Shared reference / extracted methodology** for `skills/gap-loop` (its runnable embodiment) —
> and a **citable vocabulary** that sibling orchestration skills (`quiesce`, `convergence-engine`,
> `auto-pilot`, `enhance-pipeline`) MAY adopt without duplicating it.
> **Version**: 1.1.0 (2026-06-29)
> **Scope**: AAIF cross-vendor. Vendor-neutral; runs in cowork / Claude Code / SDK / Cursor / Codex / Gemini / Copilot.
> **Lineage**: distilled (meta-concept extraction) from the operator's `--goal-n-loop` prompt; composes
> `skills/converge` (5-act), `skills/convergence-engine` (three-regime + master condition + economic stop),
> `agents/perspective-trio` + `agents/persona-pipeline` (MoE breadth/depth), `agents/cascade-resolver`
> (score formula + 12-role rotation), `agents/forge` (Forge + 33-Socratic), `skills/decision-capture` +
> `skills/agentic-session-harness` (ASH audit + meta-trace). Autonomy bar + carve-outs SSOT:
> `agents/COWORK-AUTONOMY-POLICY.md` (cited, not re-listed — DRY).
> Complements `quiesce` (which composes the native `/goal` loop) by NOT depending on `/goal`.
> **v1.1.0**: folds the `--goal-n-loop v3 FINAL` deltas — the 4 `--auto-self-*` flag de-theatering (§3.5),
> the three-regime RESOLVE routing + 33Q target-mapping (§4), the COWORK-AUTONOMY-POLICY SSOT + ≥0.90
> substitute band (§3), the ASH loop meta-trace (§6), HARMONIC/STABLE-plateau/keep-best predicate nuance (§2),
> and KIS terminology. Meta-concepts 10 → 12.

This document is the common methodology. Read it once; the skill references it instead of inlining
the rationale, and siblings can cite a concept by name (e.g. "apply Gap-Loop §3 SCORE rule").

---

## §0 — BEING > Rules (foundational)

The loop serves the goal, not the reverse. *"BEING > law; law serves the goal; any rule admits a
justified exception (SDP — documented justification)."* This is the global §0 SER>Regras made
loop-local; it is the `--principle-exception` escape and overrides any §below in genuine conflict.

---

## §1 — The 12 meta-concepts (the M.O.)

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
11. ★ **Self-* flags de-theatered onto canonical primitives** (§3.5) — the operator's `--auto-self-{fix,heal,evolve,aware}`
    map onto EXISTING primitives (REFINE · preflight+Sentinel · boy-scout+capture · Sentinel-health+ASH); they are
    NOT autonomous framework mutation and NOT sentience (anti-theater).
12. ★ **Loop meta-trace → ASH (self-observability)** (§6) — each round persists an observability record
    (round · score+6-factor · binding factor · regime · roster-delta · n*/stop-reason); the operational form of `--auto-self-aware`.

---

## §2 — The loop (declarative, self-driven)

```text
TERMINATION — keep looping until ALL true; do NOT stop early:
  CONVERGED := ( every gap DISPOSITIONED — fix-applied | deferred-with-rationale | accepted-as-risk
                   AND no gap pending without a disposition )
             AND ( agentic CONVERGENCE — >=2 INDEPENDENT dissenting positions reconciled into ONE
                   synthesis + reject-log; HARMONIC — de-entropy/harmonize, NOT mere majority )
             AND ( STABLE plateau — convergence-engine economic stop n* reached: Δ<ε for K rounds OR
                   consensus; keep-best monotonicity — never ship a regressed round )
             AND ( autonomy_score >= 0.85, DERIVED + evidence-backed — §3 )

BOUNDS: autonomy-band=L2-unattended (set via --autonomy-threshold) · --max-iterations=6 ·
        --principles=[DRY,SSOT,KIS,YAGNI,ANTI-OVER-ENG,ANTI-THEATER,CONTINUITY,HAND-OFF,BOY-SCOUT] ·
        --principle-exception="documented justification (SDP)" · --meta-rule="BEING > law"
        # KIS = Keep It Simple (eliminate accidental complexity, preserve essential — simple, not simplistic);
        #   "smart" is the quality CAVEAT (simple, not simplistic), never a redefinition.

PHASES (per round):
  0 DoR     precheck state via [pulse | directive-braindump-triage | preflight]; branch+worktree isolation
            (anti-conflict); SSOT targets reachable; abort-with-reason if unmet.
  1 RECAP   from one state-source enumerate [ objectives & purposes {mandatory · foundational · generational ·
            primary · secondary · auxiliary} · plan · roadmap · open-problems · gaps · pending ]
            -> deduplicated IDed gap-register (G1..Gn). Inject prior HITL / low-score / regression items as gaps. (no hallucination.)
  2 RESOLVE per gap: regime-routed by verifiability (§4 three-regime) — REFINE / SELECT / DEFER. The MoE form:
            >=2 DIVERSE experts (Forge if competency absent) + 1 arbiter; 5-act converge
            [steelman -> critique -> compare -> synthesize -> reject-log];
            output {decision, rationale, rejected-alternatives, residual-risk, confidence}.
  3 VALIDATE independent audit (experts != Phase 2); Socratic gate (--socratic-depth=N, §4 target-map); Sentinel audit;
            any FAIL re-enters Phase 2 as a gap; compute autonomy_score (§3) -> drives the loop.
  4 PERSIST decision-audit + loop meta-trace (ASH, §6) + convergence-report + reject-log + tickets + boy-scout (§6).
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
- **Bands + carve-outs SSOT = `agents/COWORK-AUTONOMY-POLICY.md`** (cited, not re-listed — DRY). The
  canonical 6-factor bands: **≥0.90 → MAY SUBSTITUTE the human / NO-HITL** (own-domain only; carve-outs
  still hold) · 0.85–0.89 act · 0.65–0.84 act+justify+override-window (reversible ∧ ¬HUMAN_DOMAIN) ·
  <0.65 score-uplift (≤ n*) → re-gate → HITL. **Safety is NOT a score dimension — it is a CARVE-OUT (§5),
  enforced regardless of score.** `certainty` is DERIVED by `persona-pipeline`, never declared.

---

## §3.5 — Operator `--auto-self-*` flags → canonical primitives (de-theatered)

The operator's four self-* flags are NOT new machinery — each maps onto an EXISTING primitive (invoke,
don't invent). De-theatering them is itself an anti-theater act: name the real mechanism, reject the
fantasy reading.

| Flag | → maps onto (existing primitive) | Explicit NON-claim (anti-theater) |
|---|---|---|
| `--auto-self-fix` | `convergence-engine` REFINE (`cascade-resolver` uplift, keep-best) | **reversible-in-scope ONLY** — not a license for irreversible edits |
| `--auto-self-heal` | `preflight` (heal branch from origin) + `sentinel` (anomaly auto-block HIGH) | not self-modifying logic — just branch/anomaly recovery |
| `--auto-self-evolve` | boy-scout (`protocols/exit-hygiene.md`) + `decision-capture` / `operator-quote-capture` | **NOT autonomous framework mutation** — a new tool/agent = Forge under HITL (YAGNI) |
| `--auto-self-aware` | self-observability: `sentinel` health-score + ASH (`agentic-session-harness`) meta-trace (§6) | **NOT literal sentience** — that would be ANTI-THEATER |

---

## §4 — RESOLVE (MoE) + VALIDATE (independent) + Socratic gate

- **RESOLVE — three-regime routing** (owned by `skills/convergence-engine`; this protocol REUSES, does
  not redefine). Classify each gap by verifiability + generator competence, then route:
  - **REFINE** (`gen ≳ 70%`, verifiable) → `perspective-trio` (breadth) → `cascade-resolver` (uplift, keep-best).
  - **SELECT** (`gen 40–70%`, verifiable) → `converge` 5-act (steelman→critique→compare→synthesize→reject-log).
  - **DEFER** (`gen < 40%` OR unverifiable) → council-before-HITL (§5); the deliberate **10–15% residue, never 0%**.
- **RESOLVE — the MoE form** (per gap, in REFINE/SELECT): roster = >=2 DIVERSE experts (`perspective-trio`;
  Forge via `agents/forge` if a competency is absent) + 1 arbiter; the reject-log is first-class (non-lossy);
  output {decision, rationale, rejected-alternatives, residual-risk, confidence}.
- **VALIDATE** (independent): experts DIFFERENT from RESOLVE (verifier != generator) — `persona-pipeline`
  6-stage board + `sentinel` audit. Validate [plan, roadmap, tools, context, scope, viability,
  implementability, usability, over-eng, theater, risks+mitigations, best-practices, security].
- **Socratic gate**: `--socratic-depth=N`, drawn from SSOT (`agents/forge` §33-Socratic /
  `skills/maos-concierge/references/socratic-33q.md`). **Do NOT hardcode "33"** — depth is parameterized.
  Apply the question-bank OVER the **13 validation targets** [proposal · usability · viability · risk ·
  security · gaps · inconsistencies · incompatibilities · errors · failures · mitigations · solutions ·
  market-acceptance], mapping the bank's **6 sections** onto them: Scope(1-7) → proposal/usability ·
  Capabilities(8-14) → viability/solutions · Limits(15-21) → risk/failures/mitigations ·
  Interfaces(22-26) → incompatibilities/integration · Governance(27-30) → security/inconsistencies ·
  Validation(31-33) → errors/market-acceptance.

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
- **loop meta-trace → ASH** (`skills/agentic-session-harness`): per round persist `{round · autonomy_score +
  6-factor breakdown · binding factor · regime (REFINE/SELECT/DEFER) · roster delta · n* / stop-reason}` —
  the observability record (the operational form of `--auto-self-aware`, §3.5).
- convergence-report + reject-log → docs / Confluence.
- gap-closures + residuals → tickets via `maos:postflight` P2.5 TICKET-SYNC (a capability-detected ticketing primitive, ref `ticket-as-prompt`; in-repo SSOT `skills/postflight/references/ticket-sync-protocol.md`).
- boy-scout: leave touched artifacts cleaner than found (`maos:postflight` P1-SWEEP).
- **STAGE-only git unless authorized** (EKO-66): never push/merge without explicit operator authorization.

**DoD**: gap-register fully dispositioned (none undispositioned) · HARMONIC convergence + STABLE plateau
reached · convergence synthesis + reject-log exist · **keep-best** (no unresolved regression) · Socratic
gate passed over the 13 targets · `autonomy_score >= 0.85` (DERIVED, evidence-backed) · **DEFER residue
classified (~10–15% by design — never faked-to-zero)** · artifacts + loop meta-trace persisted
(decision-capture + ASH) · every escalation classified (SOFT looped / HARD escalated) and logged.

---

## §7 — Adoption notes (for siblings — DRY)

- `quiesce` MAY adopt §5 (SOFT/HARD) + §3 (derived score) to enrich its HITL handling; its outer loop
  stays `/goal`-based, gap-loop's stays declarative.
- `convergence-engine` already owns the master condition + economic stop + three-regime switch; this
  protocol REUSES them (it does not redefine them) — §3 + §4 cite them.
- The autonomy bands + carve-outs live ONCE in `agents/COWORK-AUTONOMY-POLICY.md`; §3 cites them (DRY).
- **Layer-purity (porting)**: MAOS-specific *carry-known-risks* (ADR-006-as-HUMAN_DOMAIN, the always-on
  single-conductor collision) live in `skills/gap-loop`'s **"Project carries (MAOS-specific)"** section,
  NOT in this portable methodology — **drop them when porting** this protocol to another host/ecosystem.
- The methodology is cross-vendor; replace named primitives with the host's equivalents where absent.

## §8 — Sunset (qualitative — not counter-based)

Deprecate when ANY: a host makes a declarative condition-loop universal so `quiesce` covers cowork/SDK
too (E1) · the family absorbs gap-loop into a unified loop entry (E6) · operator retraction (E4) ·
>=3 false-positive runs (E5). Dormant-by-design otherwise.

## §9 — Refs

- `skills/gap-loop/SKILL.md` (runnable embodiment) · `commands/gap-loop.md`
- `agents/COWORK-AUTONOMY-POLICY.md` (autonomy bands + carve-outs SSOT — §3) · `skills/directive-braindump-triage` (alt state-loader — §2 Phase 0)
- `skills/quiesce` · `skills/convergence-engine` (+ `PRIOR-ART.md`) · `skills/converge` · `skills/pulse`
- `agents/perspective-trio.md` · `agents/persona-pipeline.md` · `agents/cascade-resolver.md` · `agents/forge.md`
- `skills/decision-capture` · `skills/agentic-session-harness` (ASH meta-trace — §6) · `maos:postflight` P2.5 (ticketing, ref `ticket-as-prompt`) · `sentinel/detection_rules.md`
- `protocols/agentic-tool-lifecycle.md` (shared-protocol precedent)
- External grounding inherited from `skills/convergence-engine/PRIOR-ART.md` (Du et al. 2023 society-of-minds;
  Madaan 2023 Self-Refine; Huang 2024 verifier>generator; multi-agent-debate).
