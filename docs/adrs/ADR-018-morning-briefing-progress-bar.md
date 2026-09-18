# ADR-018: morning-briefing recap progress-bar (v1.9.0) — a bar is a measured-denominator privilege

- **Status**: Accepted
- **Date**: 2026-09-18
- **Deciders**: council-of-MoE (7 seats: prisma-anatomy · ux-ui-design · ba-sa-metrics · arc-eng-hybrid · qa-devsecops · anima-naming · forge-landing), synthesized by the R1 sub-conductor as aggregating judge; operator opened the goal via `/grill-with-docs` and delegated Q1-Q7 to the council as Technical/Role/Function domain (not human domain).
- **Scope**: MAOS (community, MIT, AAIF cross-vendor). Skill `skills/morning-briefing/SKILL.md` (`prompt_version` `1.8.1` → `1.9.0`, MINOR). Companion to **ADR-005** (dogfood-cycle ledger, the ≥2-cycle gate) and the `dogfooding-mandate` (referenced across the ecosystem as "ADR-017 R1" — a policy label, not a file in this dir).

## Context

`morning-briefing` is a declarative markdown skill (no executable scripts; its bash blocks are LLM-implemented pseudo-code per host capability). Recap-mode `## 4. $execution_metrics` already surfaced four percentages: `% Plan execution`, `% Principais completos`, `% PRs Green`, `% PR Agentic Convergence`. The operator asked for a **progress-bar** — a HYBRID tool (probabilistic to infer scope/context, deterministic for render/calc) that also incorporates the self-heal M.O., defined+tested+exampled in **both** multi-agent-os and eko-engram.

The load-bearing problem is the **denominator**. A progress bar is a *confidence affordance*: proportional fill communicates "this was measured". The four metrics do not share one denominator class:

| Class | Metrics | Denominator source | Falsifiable? |
|---|---|---|---|
| World-anchored | `% PRs Green`, `% PR Agentic Convergence` | `gh` probe (`SKILL.md:627`) | Yes — re-run `gh` reproduces it |
| Self-referential | `% Plan execution`, `% Principais completos` | LLM synthesis of "the plan" (`SKILL.md:626`) | No — nothing external to compare against |

Lending a bar's visual authority to a number whose denominator is the model's own opinion launders an estimate as a measurement (vanity-metric / stale-state theater). That single fact drove most of the decision.

## Decision

The council's Design Decision Record (DDR, 368 lines §0-§11, kept in the session scratch workspace — see References) resolved Q1-Q7. Verdicts, as shipped in PR #435:

1. **Q1 — Denominator.** Two always-on ASCII **per-metric** bars for the two probe-measured, falsifiable metrics ONLY: `prs_green` + `pr_agentic_convergence`. `% Plan execution` + `% Principais completos` stay **text**, labelled `(LLM-estimated)`, **no bar**. **No aggregate bar** (averaging heterogeneous denominators produces a number nothing in the world corresponds to).
2. **Q2 — Mode scope.** **recap-only.** Nothing in briefing-mode or the `$pulse` callout — briefing-mode has no measured denominator to show (open-state, not closure).
3. **Q3 — Render.** `[####------]`, **10 cells**, glyphs `#`/`-`/`[`/`]`, `filled = 0 if pct==0 else max(1, floor(pct/10))` (floor never rounds 95%→full; 1-cell floor so `0<pct<10` is not visually equal to `0%`). State cuts `GREEN ≥90 / WARN 60-89 / RED <60`. **No emoji, no Unicode block** (`█`/`░` desalign in proportional fonts, breaking the v1.1.0 "render identically" invariant); ANSI only in `console` under `[ -t 1 ]`; in `md` inside a fence.
4. **Q4 — Dual legibility.** The human line ALWAYS carries `<label> <TOKEN> <pct>% (<n>/<total>)` (the bar is decorative — a screen reader / monochrome terminal loses nothing). `--format=json` is THE machine contract: an `execution_metrics` array inside the single recap object, each `{metric, numerator, denominator, pct, state, bar}`; a hole keeps its object with `state:"UNKNOWN"`, `bar:null`, null numerics (never a faked `0`). `md` is explicitly rejected as a regex-stable contract.
5. **Q5 — Taxonomy.** Keep **4 tiers** (`$originating`/`$primary`/`$secondary`/`$auxiliary`). 12 of the operator's 15 named items already exist under other names; the 3 extra tiers + `DoR` are **DEFERRED with a named unblock condition** (falsifiable definition landed first in the `goal-recovery` SSOT), not refused. Net-new structural change accepted now: a **dedicated `$risks` recap section** (§12; old §12-16 renumbered §13-17). **One PR** (no cross-tool sync fires while tiers stay at 4).
6. **Q6 — Hybrid split.** **No bundled script.** The deterministic layer is an exhaustive **12-row literal lookup table** in the template: the LLM copies a row, never computes (`pct` is already materialized by R3), so same-state reruns are byte-reproducible. Reopening condition (a denominator not already materialized as `pct`) documented in DDR §6.4.
7. **Q7 — Versioning.** MINOR `v1.8.1 → v1.9.0` (additive capability; default preserves v1.8.1). The ADR-017-R1 `cycles_completed` reset is a **no-op** (already `0`); `promotion_eligible:false` kept; **no Bundle-Now waiver** (it would buy nothing).
8. **Self-heal M.O. — N/A por artefato.** The 7 properties of `eko-executable-scripts` presuppose an executable (`trap self_heal ERR`, `exec > >(tee)`, `command -v kiro-cli`) — there is no `scripts/` dir for them to live in. Declaring adoption without an artifact is theater type A; inventing a script only to host the pattern is theater type B. The honest analogue is the documented **degradation/diagnostic** path for the bar's NEW deps (denominator 0 · unmeasured · partial probe · `gh` absent · cold-start · missing i18n key → omit bar + one stderr line, **never** draw `0%` as measured).

Two new anti-patterns codify the rationale: **#30 — Bar without a measured denominator** and **#31 — Bar as source of truth / glyph-only**.

## Alternatives rejected

- **All 4 metrics get a bar** (PRISMA) — treats "the number is in the table" as "the denominator was measured". The conflation the bar must not commit.
- **One aggregate bar** (UX/UI) — averages non-commensurable denominators; fails the pre-registered falsification test. The "scan in 5s" argument was premised on 4+ bars and is satisfied by 2.
- **`% Principais completos` as primary aggregate denominator** (ARC/ENG) — the least falsifiable of the four; the worst candidate to carry the main signal.
- **`█`/`░` blocks + emoji accents, cuts ≥80/50** (PRISMA) — blocks desalign in proportional fonts; emoji-as-state violates anti-pattern #14; the cuts came without rationale.
- **Expand to 7 tiers** (ANIMA) — 3 of 7 have no falsifiable membership definition; `P0..P6` breaks the `P0=originating` short-code continuity. Deferred, not refused.
- **Bundled `bin/mb-progress-bar.sh`** (ARC/ENG) — defeated by its own fallback: if a literal lookup suffices (it does, `pct` already exists), the LLM never computes and the script's justification reduces to "it would be testable". Testability of the unnecessary is not a reason to add it. It would also change the skill's nature, add a test surface the repo lacks for it, and introduce a new failure mode.
- **Localized state display `VERDE/ATENÇÃO/VERMELHO`** (ANIMA, self-dissented) — a `"state":"VERMELHO"` breaks every consumer matching `state == "RED"`. `GREEN|WARN|RED` is PRESERVE-class; only the column header (`Barra`) and row labels localize.

## Consequences

- **Positive**: the bar is anti-theater by construction — only measured, falsifiable metrics earn one, and holes omit-and-diagnose rather than fabricate. Deterministic-by-lookup means zero render variance. Zero cross-tool blast radius (4 tiers kept). The machine contract is `--format=json`, not a fragile `md` regex.
- **Negative (mitigated)**: the operator's 3 extra tiers + `DoR` are deferred, not delivered — the unblock condition (§5.3: falsifiable definition in the `goal-recovery` SSOT first) is named, and an operator override reopens it legitimately with DDR §5.1 as the evidence.
- **Negative (mitigated)**: "6/6 Self-Validity Tests" is the `rule-quality-tests` skill applied to this change and recorded in the changelog row, NOT an in-file §11 section (none exists — pre-refuted in DDR §10). One dogfood cycle is recorded via `bin/dogfood-mark`; **one cycle does not promote** (the gate is ≥2 per ADR-005; `promotion_eligible` stays `false`).
- **Anti-theater rationale (why 2 bars not 4, why no script, why 4 tiers not 7)**: each is a refusal to paint rigor onto something unmeasured. 2 bars because only 2 have a `gh` probe; no script because the LLM never computes (so testability buys nothing); 4 tiers because 3 of the proposed extras have no falsifiable definition and expanding here (not in the SSOT) would be source drift.

## References

- **Design Decision Record** (368 lines §0-§11): `/Users/emilson.moraes/Projects/.scratch/mb-progress-bar/DESIGN-DECISION-RECORD.md` — session scratch, not versioned; 7-seat council synthesized by the R1 sub-conductor. Also captured in the MAOS knowledge base for durability.
- **PR**: `ekson73/multi-agent-os#435` (`feat/morning-briefing-progress-bar`) — the shipping vehicle for v1.9.0 and this ADR.
- **Skill SSOT**: `skills/morning-briefing/SKILL.md` (Phase 3b.6 bar spec + lookup + json + degradation; anti-patterns #30/#31; §12 `$risks`; changelog row `1.9.0`).
- **Distribution**: `skills/morning-briefing/DISTRIBUTION.md` (MAOS is the SSOT; other harness copies follow each harness's best practice, preferably a symlink).
- **eko-engram** counterpart (definition + test/quality criteria + worked examples): `ekson73/eko-engram` `designs/morning-briefing-progress-bar.md`.
- **Companion**: `ADR-005-dogfood-cycle-ledger.md` (the ≥2-cycle gate this version defers to); the `dogfooding-mandate` (aka "ADR-017 R1", policy).
- Anti-patterns echoed: #2 (vanity metric) · #7 (stale-state hallucination) · #14 (label carries full meaning) · #27 (factor-flag inference theater) · #29 (default scope no sibling scan).
