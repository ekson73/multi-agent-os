---
name: reveng
description: |
  Use to REVERSE-ENGINEER source code into an OpenSpec SPEC model (the as-built behavioral
  contract) — e.g. "reveng this src/ to OpenSpec specs", "reverse-engineer the code into specs",
  "derive specs from the implementation", "extrair specs do código", "engenharia reversa do src
  para SPEC", "what does this codebase actually specify?". It treats the code as a READ-ONLY
  ORACLE, distills each capability into a neutral behavioral brief, recasts it into OpenSpec
  format (## Purpose · ### Requirement[SHALL] · #### Scenario[WHEN/THEN]), runs a FAITHFULNESS
  check (every requirement traces to a code/test oracle — no invented behavior), validates with
  `openspec validate --specs`, documents un-capturable cloud-only truth as a GAP report, and
  prints an end-of-reveng SCORE-CARD. Priority pair = src/ → OpenSpec SPEC; other source→target
  pairs (docs/ADRs/tickets → SPEC; src → README/AGENTS) are documented roadmap, not yet built.
  It RE-TARGETS ABSTRACTION/MODEL (code↔spec); it does NOT re-engineer the code itself
  (refactor/migrate) and does NOT reverse the authority (specs never overwrite code). Cross-vendor AAIF.
triggers:
  - reveng this src to OpenSpec
  - reverse-engineer the code into specs
  - derive specs from the implementation
  - reveng src/ to spec
  - extrair specs do código
  - engenharia reversa do src para SPEC
  - what does this codebase actually specify
  - generate as-built specs from code
version: 0.1.0
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Skill
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: spec-lifecycle
  cross_link_slug: reveng
  dogfood_status: in-progress
  related: [content-recast, openspec-concierge, agentic-tool-forge, anima, converge]
---

# Reveng — code → OpenSpec SPEC reverse-engineering

## Overview
Reverse-derive the **as-built behavioral contract** of a codebase as OpenSpec specs. The code is the
**read-only oracle** (it is the shipped truth); specs are *derived*, never authoritative over it. The
single responsibility = the **abstraction transform** (code → SPEC); validation is **delegated** to the
`openspec` CLI, naming/explanation handoffs to sibling tools. The quality differentiator vs. naive
"generate-specs-from-code" is a mandatory **faithfulness guard** (every `SHALL` + scenario traces to a
concrete code/test oracle — no invented requirements) + a **gap report** for truth that lives outside the
repo (RLS / DB triggers / edge functions / external services). Inherits the `content-recast` pipeline
(distill → neutral-brief-anchor → recast-through-format → faithfulness-check → render) applied to the
abstraction axis instead of the audience axis.

## When to use / NOT use
- **Use**: derive/refresh `openspec/specs/` from a live `src/` tree; produce an as-built contract for a
  codebase that has drifted from (or never had) specs; round-2 fidelity uplift of existing drafted specs.
- **NOT use**: re-engineering the code itself (refactor/migrate angular→react, monolith→microservices →
  `legacy-modernizer` / `10x-fullstack-engineer:refactor`); authoring *forward* specs for unbuilt features
  (→ `openspec-propose` / `opsx:propose`); explaining a migration to a human audience (→ `content-recast`).
  If `openspec/specs/` already exists at full as-built fidelity → this tool *refreshes* (idempotent), it
  does not duplicate.

## §0 — BEING > Rules (foundational)
Serves the operator's intent. If a phase/gate obstructs delivering the spec NOW, skip it, log
`Skipped <phase> — BEING > Rules`, proceed. **Non-negotiable**: never invent a requirement to make the spec
look complete (faithfulness guard) and **never write into `src/`** (the oracle is read-only). HUMAN_DOMAIN
(secrets · production PII · irreversibles · cross-org publish · cost) → escalate, never auto-act.

## Parameters
| Param | Default | Meaning |
|---|---|---|
| `<source>` (positional) / `--from` | `src/` | Source oracle(s), multi-select priority order: `src` FIRST → `docs` · `adrs` · `changelogs` · `memories` · `rules` · `tickets` · `git`. (v0.1.0 builds `src` fully; others = roadmap stub → DEFER with a note.) |
| `--target` | `spec` | Output model(s), multi-select: `spec` (OpenSpec, FIRST/priority) · `docs` · `adrs` · `readme` · `claude` · `agents` · `contributing` · `governance`. Each target passes a **theater filter** (§ Target reality filter). |
| `--out` | `openspec/specs` | Output dir for `--target=spec`. |
| `--scope-lock` | inferred | Niche/MVP constraint (e.g. "AirBnB-Ops only — forbid inventing other niches"). Read from `openspec/config.yaml` if present. |
| `--validate` | on | Run `openspec validate --specs` after emit (off ⇒ lower confidence). |
| `--dry-run` | off | Distill + plan + score-card ONLY; no spec written. |
| `--cap` | all | Limit to ONE capability (e.g. `--cap=auth`) — used for sampling / cycle dogfood. |
| `--json` | off | Emit the machine score-card envelope (§ Machine output) for agent-to-agent use ([C06]). |

**Argument parsing**: token(s) before the first `--` = `<source>`; `--key value`/`--flag` after = params.

## Pipeline (0 → 7)
0. **Intake** — parse `<source>`/params; resolve `--scope-lock` (read `openspec/config.yaml`/`project.md` if
   present). No source resolvable → usage, stop. Detect stack (lang/framework) read-only.
1. **Discover capabilities** — enumerate the source's capability domains (e.g. `src/features/<cap>/`), the
   data/store layer (state + actions), the type boundaries (enums/interfaces), and the **test oracles**
   (`*.spec.*` / `*.test.*` WHEN/THEN assertions). Produce the capability list. Honor `--cap`.
2. **Distill → neutral capability-brief** (per `content-recast` step 1, abstraction-adapted) — for each
   capability extract atomic **behavioral claims + their oracle pointers** (store action, test name, type,
   hook). This brief is the **faithfulness anchor**. NEVER recast directly from raw code.
3. **Recast → OpenSpec format** — rewrite each brief as `openspec/specs/<cap>/spec.md`:
   `## Purpose` (1 sentence + cite the live source files) · `### Requirement: <name>` (begins "The system
   SHALL …") · `#### Scenario: <name>` (`- **WHEN** …` / `- **THEN** …`). Mine scenarios from the test
   oracles + type constraints. Respect `--scope-lock` (forbid niche invention).
4. **Faithfulness check** (MANDATORY) — verify every `SHALL` + scenario traces to a claim in the neutral
   brief (step 2) → which traces to a real oracle. Flag/repair: invented requirements, distorted behavior,
   omitted load-bearing rules. **Drift note**: where a *pre-existing* spec disagreed with the code, the
   code wins (precedence `src/ > openspec/specs/ > docs/`) — record the divergence.
5. **Gap report** — list truth the repo CANNOT capture (DB RLS policies / triggers in the cloud project,
   edge-function server logic, external-service contracts). These become explicit **limitation notes** in
   the relevant spec (e.g. `security`), NEVER silent omissions.
6. **Validate** — run `openspec validate --specs` (if `--validate` on + CLI present). Capture N/N. Format
   failure → repair the offending spec, re-run.
7. **Score-card** — print the end-of-reveng score-card (§ below). `--dry-run`/`--json` short-circuit to the
   card only. Emit handoff: `→ openspec-concierge` (audit) · `→ content-recast` (explain to a human).

## Target reality filter (anti-theater — which `--target`s are real, not over-eng)
Before emitting a non-`spec` target, ask: does this target add real value the source doesn't already
carry, OR is it ceremony? **Real now**: `spec` (the as-built contract — primary). **Real on demand**:
`readme`/`agents`/`contributing` (onboarding deltas) — emit only if missing/stale. **Usually theater**
(DEFER unless explicitly justified): re-deriving `docs`/`adrs`/`governance` that already exist and didn't
drift — re-generating them is noise. v0.1.0 ships `spec` only; others gated behind this filter.

## End-of-reveng SCORE-CARD (the operator-facing verdict)
Criteria are **decision-changing only** (vanity metrics — #files-read, #lines, tokens, wall-clock — are
NOT scored, per the observability discipline "measure to inform, not vanity"):

```
🧬 REVENG SCORE-CARD — <source> → <target>
status:        🟢 complete | 🟡 partial | 🔴 blocked | 🔵 needs-HITL
coverage:      <specs-emitted>/<capabilities-discovered> (NN%)
confidence:    NN%  [🟢≥85 · 🟡 65–84 · 🔴 <65]   (honest fidelity, never inflated)
requirements:  ✅ <done>  ·  ⬜ <pending>
drift:         NN%  (src↔pre-existing-spec divergences found; src wins)
validate:      <N>/<N> openspec validate --specs   (or n/a if CLI absent)
gaps:          <count> cloud-only truths un-capturable (RLS/triggers/edge-fns) → see limitation notes
idempotency:   ♻️ re-run = same output (skip-if-identical) | ⚠️ non-deterministic
attention:     <load-bearing caveats>
next-actions:  <ranked follow-ups>
```

## Faithfulness guard (the differentiator — non-negotiable)
1. Every `SHALL`/scenario MUST trace to the neutral brief → a real oracle (code/test/type). 2. No invented
requirements, fields, or behaviors. 3. No authority reversal — a derived spec NEVER overwrites `src/`
(ADR-026 precedence). 4. Cloud-only / external truth surfaces as a **gap note**, never a silent omission.
5. Scope-lock honored — no inventing capabilities/niches the code doesn't implement.

## Anti-patterns (do NOT)
- ❌ Recast directly from raw code (skip the distill anchor) → invented-requirement drift.
- ❌ Invent a `SHALL` to "complete" a spec → violates the guard (the #1 reveng failure mode).
- ❌ Write into `src/` or let a spec override code → authority reversal (ADR-026).
- ❌ Silently omit cloud-only truth (RLS/triggers/edge-fns) → use the gap report.
- ❌ Re-derive non-drifted `docs`/`adrs` "because the target list allows it" → target-reality-filter theater.
- ❌ Rebuild the `openspec` validator → delegate to the CLI.
- ❌ Reverse-engineer past the scope-lock (invent niches the code doesn't ship).

## §Design interrogation (33-Socratic design-record, grouped — provenance of v0.1.0)
The forge interrogated the tool across 11 dimensions × 3 depths (*is · should-be · must-not-be*) — the
design answers that shaped this skill:
| Group | Dimensions | Design answer (compressed) |
|---|---|---|
| **Intent** | purpose · objective · root-problem | *is* code→as-built-spec; *should* faithful + validatable + idempotent; *must-not* invent behavior. Root-problem = code drifts from specs / has none. |
| **Frame** | context · scope · temporality | *is* S-SDLC SpecDD / OpenSpec ecosystem; *should* src→SPEC first, other pairs roadmap; *must-not* exceed scope-lock. Durable (reverse-engineering is foundational). |
| **Authority** | who-decides-truth · authorization · ownership | *is* `src/` is the oracle (ADR-026 `src > spec > docs`); *should* read-only oracle; *must-not* reverse authority. |
| **Fitness** | capability · competence · resilience | *is* distill→recast→verify→validate; *should* reuse content-recast pipeline + openspec CLI (DRY); *must-not* rebuild a validator or an editor. |
| **Risk** | gaps · pendencies · failures · anti-patterns · out-of-scope | *is* cloud-only truth (RLS/triggers/edge-fns) un-capturable → gap report; *should* flag not omit; *must-not* claim coverage it lacks. Out-of-scope = refactor/migrate + forward-spec authoring. |
Score-card criteria were selected by the same risk lens: keep decision-changing (coverage · confidence ·
drift · validate · gaps · idempotency), drop vanity (LOC · tokens · duration).

## §Quality Tests (self-dogfood — 6/6)
1. **Self-Application** — forged via the forge pipeline (research → name-via-anima → 33-Socratic → gate); its
   own design-record is itself a reveng of the intent into a SKILL contract. ✅
2. **Non-Contradiction** — composes (not duplicates) `content-recast` (pipeline) + `openspec` CLI (validate)
   + `openspec-concierge` (audit/route); consistent with `scope-discipline`/`anti-theater`/ADR-023/026. ✅
3. **Survival** — applied to itself it advocates faithful read-only derivation; survives. ✅
4. **Bounded-Responsibility** — `--dry-run` · `--cap` sampling · src-first (others DEFER) · faithfulness guard
   · DUED sunset. ✅
5. **Explicit-Exception** — §0 BEING>Rules + HUMAN_DOMAIN escalation + target-reality-filter + cognitive-
   adaptation-freedom on scenario mining. ✅
6. **Utility-Sunset** — §DUED below. ✅
Pre-creation `scope-discipline` 6Q: 6/6 (WHERE=community/maos · DRY=gap-confirmed [no reverse-engineering tool in maos; the methodology existed applied-only in a downstream project, not yet a reusable tool] · WHY=operator-priority + recurring SpecDD need · WHO=any agent reverse-deriving specs · FITS=spec-lifecycle family, sibling of content-recast · MIN=Goldilocks src→spec). `anti-theater` 8Q REALITY: 8/8.

## §DUED Sunset (qualitative, not counter-based)
Deprecate when ANY: OpenSpec ships a native `openspec reveng <src>` primitive (E1) · the spec-lifecycle family
absorbs it (E6) · operator retraction (E4) · ≥3 false-positive revengs where the guard misfires (E5).
Dormant-by-design otherwise.

## Machine output (`--json`)
```json
{"source":"src/","target":"spec","status":"complete|partial|blocked|needs-hitl",
 "coverage":{"emitted":0,"discovered":0,"pct":0},"confidence":0.0,
 "requirements":{"done":0,"pending":0},"drift_pct":0.0,"validate":{"pass":0,"total":0},
 "gaps":[],"idempotent":true,"attention":[],"next_actions":[],
 "verdict":"REVENGED|PARTIAL|DEFER|BLOCKED","_agent_feedback":"<governance hints>"}
```
Exit codes ([C06]): `0` revenged · `1` error · `2` partial/deferred.

## §Refs
- Genesis: `agentic-tool-forge` (forged this) · name decided by `anima` (epistemology-locked: `reveng` zero-drift).
- Reused pipeline: `content-recast` (distill→anchor→recast→faithfulness-check→render — abstraction-adapted).
- Validation: `openspec` CLI (`openspec validate --specs`) · OpenSpec format `## Purpose`/`### Requirement`/`#### Scenario`.
- Routing/audit sibling: `openspec-concierge` (the OpenSpec-Stack concierge/router, where present in a downstream toolkit).
- Methodology source (as-applied): a downstream React+Supabase project's reveng corpus — its OpenSpec-adoption ADR · a source-precedence ADR (`src > spec > docs`) · a reveng POC charter · a 9-capability `openspec/specs/` corpus at as-built fidelity.
- Gates: `scope-discipline-pre-creation` (6Q) · `anti-theater-grounding-protocol` (8Q, esp. R4 not-invented) · `rule-quality-tests` (6).
- Governance: `[C04]` worktree · `pr-review-protocol` · `agentic-tool-lifecycle` (→ `/agentic-tool-evaluator` → `/agentic-tool-trainer`).
- Cross-link slug: `[[reveng]]`.

## Changelog
| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-06-10 | Bootstrap — forged via `agentic-tool-forge`, named by `anima` (`reveng`, epistemology zero-drift vs `code-to-spec`). Genuine net-new in the `spec-lifecycle` family (maos had no reverse-engineering tool; the methodology existed applied-only in a downstream React+Supabase project). Encodes that as-applied methodology (oracle=`src/`, OpenSpec `## Purpose`/`### Requirement`/`#### Scenario`, source-precedence `src > spec > docs`, `openspec validate`, scope-lock, gap report) + inherits the `content-recast` distill→anchor→recast→faithfulness-check→render pipeline (abstraction-axis-adapted). Priority pair `src → spec`; other from/target pairs = roadmap stubs behind the target-reality filter. End-of-reveng score-card (decision-changing criteria only). 6/6 self-validity + 8/8 anti-theater + 6/6 scope-discipline. Dogfood cycle 1 = read-only dry-run on a downstream project's `src/` capability sample. |
