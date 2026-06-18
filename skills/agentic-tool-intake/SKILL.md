---
name: agentic-tool-intake
description: Use when you have a CANDIDATE tool that already exists (an external repo/MCP/plugin/skill someone found, e.g. from a GitHub trend or a YouTube review — OR an internal proposal) and need to decide whether and HOW to take it on. Triggers — "should I adopt this tool?", "is X worth installing?", "vet/appraise this repo/MCP for us", "should we install or build our own?", "does this conflict with what we already have?", "intake this candidate", "avalie se vale adotar X", "instalar ou criar?". It runs the adoption-decision pipeline (understand → research similars → compare/cross → validate viability → DECIDE among install/create-internally/absorb/adapt/sub-agent/abandon/defer-HITL) and, only when the verdict is INSTALL and the operator says GO, delegates a governed install. It does NOT create a tool from a bare intent (→ agentic-tool-forge), score an already-owned tool (→ agentic-tool-evaluator), or improve one (→ agentic-tool-trainer). A thin composer — it reimplements none of those; it decides.
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: agentic-tool-lifecycle
  lifecycle-stage: intake
---

# Agentic-Tool Intake

## Overview

Decide **whether and how to take on a candidate tool that already exists**. Where `agentic-tool-forge`
answers *"I have an intent — what should I create?"*, **intake** answers the inverse: *"someone handed me a
tool that already exists — should I adopt it, and if so how?"* The candidate enters the front door, is
triaged across a decision-matrix, and is routed to **one** disposition.

This is a **thin composer**: it orchestrates the existing lifecycle surface and adds **only** the
adoption decision-matrix. It reimplements no research engine, no install machinery, no scorer.

> Shared vocabulary, taxonomy, the lifecycle slot: **`protocols/agentic-tool-lifecycle.md`** (read once).

## When to use / not use

- **Use** — an external candidate (repo · MCP server · plugin · marketplace · skill · npm/pip package) OR an
  internal "should we build/adopt this?" proposal needs an adopt-or-not decision.
- **Not use** — bare intent → tool (`agentic-tool-forge`); score an already-owned tool
  (`agentic-tool-evaluator`); improve/tune one (`agentic-tool-trainer`); just *find* candidates
  (that is upstream discovery, not this); a throwaway one-off you will not reuse (just try it).

## §0 — BEING > Rules (foundational)

Serves the operator's intent. If a phase obstructs delivering the decision NOW, skip it + log
`Skipped <phase> — BEING > Rules` + proceed. **HUMAN_DOMAIN** (secrets/credentials · production/irreversible ·
cross-org · cost · anything the candidate would expose) → the verdict becomes **DEFER-HITL**, never an
autonomous install. Install is ALWAYS confirm-gated (§6).

## Parameters

| Param | Default | Meaning |
|---|---|---|
| `--candidate <repo\|mcp\|plugin\|skill\|url\|pkg>` | — (required) | What to appraise. A URL/repo/package or an internal proposal string. |
| `--mode` | `decide` | `research` (phases 1-2 only) · `decide` (1-5: verdict, no mutation) · `adopt` (1-7: incl. gated install). |
| `--scope-target` | `auto` | Where an adoption would land: `multi-agent-os` · `user` · `project` · `auto` (infer per concierge scope matrix). |
| `--dry-run` | on for `decide` | Render the decision + matrix; **no write**. Forced off only with `--mode=adopt` + operator GO. |
| `--decision-bias` | `balanced` | `conservative` (favor ABANDON/DEFER on doubt) · `balanced`. |
| `--json` | off | Emit the machine envelope ([C06]) instead of prose. |

Default invocation = `--mode=decide --dry-run` → a verdict with zero mutation.

## Pipeline (7 phases — each lands on an existing primitive; compose, don't reimplement)

| # | Phase | Does | Composes (existing) |
|---|---|---|---|
| 1 | **UNDERSTAND** | the candidate's motivation · proposal · purpose · objective · expected results; its real mechanism (read its README/docs — never the hype headline) | `WebFetch` / `find-docs` / `Read` |
| 2 | **RESEARCH** | internal + external similars; categorize/catalog the candidate + alternatives | delegate `agentic-tool-forge` Phase-1 research (internal Glob/Grep + external `WebSearch`/Context7 + DRY probe) |
| 3 | **COMPARE / CROSS** | score the candidate (and rival candidates) across the **decision axes** (below) | the decision-matrix (§ below) + `converge` ONLY if ≥2 candidates genuinely conflict |
| 4 | **VALIDATE** | viability · risks · mitigations · security (local-only? secrets? license) · **trust-tier** | `harmonic §0.5.1` CASC 7-gate + `claude-code-concierge` trust-tier (official > known > individual-unverified → SHA/version-pin) |
| 5 | **DECIDE** | one disposition + rationale + simpler-alternative note + revisit trigger | the rubric → weighted verdict (a *guideline*, not a rigid score — anti-over-eng) |
| 6 | **INSTALL** *(gated, OFF by default)* | only if verdict = INSTALL **and** `--mode=adopt` **and** operator GO | delegate `claude-code-concierge --mode=install` (scope+source+trust-tier+confirm-gate, pinned) |
| 7 | **RECORD** | mark a dogfood cycle · persist the verdict · update the tracking ticket · boy-scout | `dogfood-ledger` · `postflight` · `ticket-as-prompt --op enrich` |

## The decision-matrix

**Axes** (score each; weight by stakes — this is a lens-set, not an algorithm):
cost (install · maintenance · token) · benefit (capability · token/tool-call savings) · features · requirements ·
install-complexity · impact / blast-radius · **conflicts** (tool-surface collision · functional overlap) ·
**family-members** (related/inter-related tools already owned) · **collaborations** (does it *complement* an owned
tool?) · inconsistencies / incompatibilities · **redundancy** (Strata ≥50%-already-covered ⇒ lean EXTEND/ABSORB) ·
**trust-tier** ([C12]: T1 operator > T2 corporate > T3 known-maintainer > T4 individual-unverified).

**The 7 dispositions** (DECIDE returns exactly one):

| Verdict | Meaning | When |
|---|---|---|
| **INSTALL** | adopt the external as-is, governed | high benefit · low redundancy · acceptable trust/cost · no conflict |
| **CREATE-INTERNALLY** | build our own instead (→ `agentic-tool-forge`) | idea is valuable but the artifact is low-trust / unmaintained / mis-fit |
| **ABSORB** | take the *idea/pattern/code* into an existing owned tool | ≥50% covered by an owned tool that the candidate would only improve |
| **ADAPT** | fork / wrap / configure before adopting | good core but needs modification to fit (scope, license, surface) |
| **SUB-AGENT** | wrap as a subagent rather than an MCP/skill | value is task-delegation, not a always-on tool surface |
| **ABANDON** | reject | redundant · low-value · unsafe · the cost/overhead inverts the benefit |
| **DEFER-HITL** | escalate | genuine uncertainty after research · HUMAN_DOMAIN · cost-gated · cross-org |

## Governance baked in (from concierge CANON — enforced, not optional)

C1 official-docs-first (research current docs; cite sources; never the marketing headline) · C2 scope precedence
(enterprise > project > user > local) · C3 trust-tier-before-enable (T4 → SHA/version-pin + operator gate) ·
C4 secrets-never-inline · C5 capability-detect-never-fabricate (verify install-state by probing; never assert it
unprobed) · C6 install-is-confirm-gated · C7 orient/delegate-don't-reimplement (this whole skill is C7) ·
C8 frontmatter + layer-purity (no operator-personal / corporate content in this community artifact).
**Anti-theater**: verify the candidate's claims (stars · benchmark · maturity) against primary sources — the
title is not evidence (Mente Tomé).

## Bounds

- `--dry-run` is the default for `decide`; install is OFF unless `--mode=adopt` + GO.
- DEFER on HUMAN_DOMAIN / ⛔ guardrails — never auto-install those.
- Idempotent: same candidate + same evidence ⇒ same verdict.
- Bounded to the candidate set the operator names — not an open-ended sweep of the ecosystem.
- The verdict is a recommendation; a clean high-confidence INSTALL still confirm-gates the actual install.

## Skip (proportionality, per `agentic-first §4.6` + least-action)

- Trivial / throwaway candidate you will not reuse → just try it inline; skip the pipeline.
- Operator already decided ("install X") → honor it; only flag a hard conflict / trust-tier risk.
- Mid-orchestration under a parent that already ran intake upstream.

## Machine output (`--json`, [C06])

```json
{"candidate":"<id/url>","mode":"research|decide|adopt",
 "verdict":"INSTALL|CREATE-INTERNALLY|ABSORB|ADAPT|SUB-AGENT|ABANDON|DEFER-HITL",
 "scope_target":"multi-agent-os|user|project","trust_tier":"T1|T2|T3|T4",
 "matrix":{"redundancy":"…","conflicts":"…","benefit":"…","cost":"…","trust":"…"},
 "rationale":"<…>","simpler_alternative":"<…>","internal_similars":["<…>"],
 "installed":false,"human_domain":false,"_agent_feedback":"<hints>"}
```
Exit: `0` decided · `1` error · `2` DEFER-HITL / dry-run.

## §Quality Tests (6/6 self-validity)

1. **Self-Application** — intake was itself the product of an adoption decision (the "should we build this?" question for the gap it fills returned CREATE-INTERNALLY → forged as a thin composer). ✅
2. **Non-Contradiction** — composes forge (create) / evaluator (score) / trainer (improve) / concierge (install) without duplicating any; fills the empty ADOPT slot between them. ✅
3. **Survival** — applied to itself it advocates "compose, don't reinvent"; it composes. ✅
4. **Bounded-Responsibility** — dry-run default · install gated · DEFER on HUMAN_DOMAIN · candidate-bounded · §DUED. ✅
5. **Explicit-Exception** — §0 BEING>Rules + HUMAN_DOMAIN DEFER + skip conditions. ✅
6. **Utility-Sunset** — §DUED. ✅

`scope-discipline` 6Q PASS (WHERE = multi-agent-os community skill · DRY = composes, gap < 50% covered · WHY = recurring "should I adopt X?" · WHO = any agent · FITS = lifecycle family slot · MIN = one thin skill). `anti-theater` 8Q PASS.

## §DUED Sunset (qualitative, not counter-based)

Deprecate when ANY: the lifecycle family merges intake into forge as a unified `--adoption-mode` (E6) · a host
ships a native tool-adoption advisor (E1) · operator retraction (E4) · ≥3 false-positive verdicts (E5).
Dormant-by-design otherwise.

## §Refs

- **SSOT**: `protocols/agentic-tool-lifecycle.md` (the family slot: forge → **intake** → evaluate → train → operate → deprecate).
- Composes: `skills/agentic-tool-forge` (research/compare/name) · `skills/claude-code-concierge` (scope/source/trust-tier/guarded-install) · `skills/agentic-tool-evaluator` (post-adopt scoring) · `skills/dogfood-ledger` (cycle tracking) · `skills/converge` (multi-candidate conflict) · `skills/postflight` (record/close) · `skills/anima` (naming, if ADAPT/CREATE) · `skills/ticket-as-prompt` (enrich).
- Gates: `anti-theater-grounding-protocol` (8Q · R4 not-invented) · `scope-discipline-pre-creation` (6Q) · CASC (`harmonic §0.5.1`).
- Cross-link slug: `[[agentic-tool-intake]]`.

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-06-18 | Bootstrap — fills the empty **ADOPT** slot in the agentic-tool lifecycle (forge=create · intake=adopt-or-not · evaluator=score · trainer=improve). Thin composer: 7-phase pipeline (UNDERSTAND→RESEARCH→COMPARE/CROSS→VALIDATE→DECIDE→INSTALL(gated)→RECORD) + the 7-disposition decision-matrix (install/create-internally/absorb/adapt/sub-agent/abandon/defer-HITL). Reimplements nothing — composes forge/concierge/evaluator/dogfood-ledger/converge/anima. Named via `anima` (`agentic-tool-intake`; runner-up `vet`). Genesis: operator `/enhance /deep-research` 2026-06-18; first dogfood = CodeGraph (`docs/adoption/codegraph-2026-06-18.md`). VKS-2244. |
