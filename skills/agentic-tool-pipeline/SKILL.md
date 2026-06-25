---
name: agentic-tool-pipeline
description: |
  Conductor of the agentic-tool lifecycle — given ANY --source-object (bare intent ·
  name · ID · text · url · site · plugin · marketplace · path to an EXISTING tool),
  ROUTE it to the right existing family member and run the full divergent→convergent
  pass: analyze → research internal+external similars → compare → cross → catalog →
  categorize → critique → DEBATE → CONVERGE → validate → correct → improve → HARMONIZE
  → then forge/adopt/improve one+ agentic-tools of any --type and SAVE to --location
  (akasha · multi-agent-os · vek-ai-toolkit). A thin preset that COMPOSES existing
  primitives (agentic-tool-forge/intake/evaluator/trainer · anima · converge ·
  perspective-trio) — reimplements nothing. Applies + passes 11 principles (DRY · KISS ·
  SSOT · YAGNI · anti-over-eng · anti-theater · boy-scout · DNA-geracional · continuity ·
  idempotency · handoff). Use when the operator wants ANY source turned into the right
  agentic-tool through one governed pass: "forge a tool from this url/plugin/intent",
  "turn any source into the right agentic-tool", "route this to the lifecycle",
  "conduct the tool-genesis pipeline". Triggers: "agentic-tool-pipeline", "forge from
  source", "tool genesis pipeline", "route to the agentic-tool lifecycle".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch, Skill
version: 0.1.0
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: agentic-tool-lifecycle
  lifecycle-stage: conduct
  cross_link_slug: agentic-tool-pipeline
  dogfood_status: self-forged
---

# Agentic-Tool Pipeline — the lifecycle conductor

Thin **agentic-tool-genesis** preset. `agentic-tool-pipeline` is to the `agentic-tool-*`
family what `enhance-pipeline` is to features: a single named entry that **routes any
source-object** into the right lifecycle member, runs the divergent→convergent→harmonize
loop on the genesis *design*, then lands on a typed terminal that **forges / adopts /
improves** one+ tools and saves them. It is a **router + sequencer only** — every stage
delegates to a primitive that already exists in this repo. It **reimplements nothing**.

## Overview

The lifecycle (`forge → intake → evaluate → train`; shared `protocols/agentic-tool-lifecycle.md`)
already exists as focused members. The missing piece was the **conductor**: no single
entry accepted *any* source-object, classified it, and drove it through analyze →
research → debate → converge → harmonize → forge → save while applying and passing on a
named principle set. This skill is that conductor. Its **only net-new logic** is the
4-row Stage-0 router; everything downstream is delegation.

## When to use
- A source of ANY kind (intent · url · plugin · marketplace · an existing owned tool)
  should become — or improve into — the right agentic-tool, end-to-end, in one pass.
- You want the genesis *design* researched + debated + converged before anything is written.
- You don't yet know whether the source is a "forge it" (new) or "adopt it" (exists) or
  "improve it" (owned) case — let the router decide.

## When **not** to use
- You already know it's a bare new intent → call `agentic-tool-forge` directly.
- You already know it's an external candidate to adopt-or-not → `agentic-tool-intake`.
- You only want to score / improve ONE owned tool → `agentic-tool-evaluator` / `-trainer`.
- You only need a name → `anima`. You're shipping a *feature* (not a tool) → `enhance-pipeline`.
- Trivial one-off / read-only Q&A → just answer. Destructive ops → always HITL.

## §0 — BEING > Rules (foundational)
This skill serves the operator's intent. If a phase/gate obstructs delivering value NOW,
skip it, log `Skipped <phase> — BEING > Rules`, and proceed. Gates are for quality, never
ritual. HUMAN_DOMAIN (secrets · PII · irreversibles · cross-org · cost · gated install) →
escalate, never auto-act.

## Trigger Phrases
- "agentic-tool-pipeline" / "/agentic-tool-pipeline"
- "forge a tool from this <url/plugin/marketplace/intent>" / "turn any source into the right tool"
- "route this to the agentic-tool lifecycle" / "conduct the tool-genesis pipeline"

## Parameters
| Flag | Default | Meaning |
|---|---|---|
| `--source-object <…>` (positional) | *required* | any of: bare intent · name · ID · text · url · site · plugin · marketplace · path to an existing tool. Empty → print usage; STOP. |
| `--type` | `auto` | force the artifact type `mcp·prompt·command·agent·subagent·skill·plugin·marketplace`; passed verbatim to forge's existing type router. `auto` = router decides. |
| `--location` | `akasha` | save target: `akasha` (`~/.claude`) · `multi-agent-os` · `vek-ai-toolkit`. Maps to the routed member's scope/save-path. |
| `--scope` | `auto` | `user·project·community·auto` (forge-compatible; orthogonal to `--location`). |
| `--research` | `both` | `internal·external·both` — gates Stage 1 (forge-compatible). |
| `--blocks` | `0,1,2,3,4` | run a subset (e.g. `0,1,2,3` to converge-only, stop before forging). |
| `--dry-run` | `false` | ROUTE→EXPAND→FILTER→HARMONIZE + emit the tool-spec proposal; STOP before Stage 4 write. |
| `--output` / `--json` | `table` / off | `--json` emits the family envelope (§ Machine output). |
| `--no-confirm` | off | skip the Stage-4 pre-write confirm (HITL-gated; standing authorization only). |

Bare `$ARGUMENTS` not starting with `--` → treat the whole string as `--source-object "$ARGUMENTS"`.

> **Deliberately dropped (KISS/YAGNI)**: `--driver`, `--auto-merge[-reason]`,
> `--autonomy-threshold`, `--max-pdca`. Those belong to the DELIVER drivers
> (`auto-pilot`/`quiesce`) and to the routed members (forge/intake/trainer carry their
> own merge/iteration gates). A conductor that re-declared them would duplicate them.

## Stage-0 ROUTER (the only net-new logic — a 4-row decision table)

The router fires once, classifies the source-object, and sets the **terminal family** for Stage 4.

| `--source-object` is… | Discriminator | Routes to (existing entry) | Stage-4 terminal verbs |
|---|---|---|---|
| **bare INTENT** (name/ID/text, no artifact behind it) | no resolvable url/repo/owned-path — a wish | `agentic-tool-forge` | create / forge |
| **EXISTING CANDIDATE** (url · site · plugin · marketplace · external repo/MCP/pkg) | resolves to an artifact that exists *elsewhere* | `agentic-tool-intake` | install · adapt · absorb · sub-agent · create-internally(→forge) · abandon · defer |
| **EXISTING-TOOL to improve** (path to an *owned* skill/agent/command/MCP) | resolves under akasha / multi-agent-os / vek-ai-toolkit | `agentic-tool-evaluator` → `agentic-tool-trainer` | fix · improve · train · test · criticize · validate · audit |
| **AMBIGUOUS** | router cannot classify with confidence | `agentic-tool-intake --mode=research` (cheapest disambiguator) → re-enter router; still ambiguous ⇒ **DEFER-HITL** | (re-routed) |

The operator's terminal verb-set maps onto existing dispositions — `create→forge`,
`adapt/incorporate/install→intake`, `fix/improve/train→trainer`,
`test/criticize/validate/audit→evaluator`. **No new machinery; the router picks the
member, the converged spec (Stage 3) picks the exact verb.**

## The five stages (operator verbs → existing primitive)

```text
STAGE 0 ROUTE     := classify --source-object → terminal family (the table above)
STAGE 1 EXPAND    := analyze + research[internal‖external] similars + compare + cross
                     + catalog + categorize + critique + expand
STAGE 2 FILTER    := critique + DEBATE + select + correct
STAGE 3 HARMONIZE := CONVERGE + validate + conclude + correct + improve + HARMONIZE
STAGE 4 FORGE     := forge[create·adapt·fix·improve·train·test·audit·incorporate·install]
                     → SAVE to --location
```

| Stage | Composes (cite — do NOT reimplement) |
|---|---|
| **0 ROUTE** | the §Stage-0 router table (net-new) |
| **1 EXPAND** | `agentic-tool-forge` Phase-1 research (internal `Glob`/`Grep` DRY probe + external `WebSearch`/`find-docs`/Context7); the same engine `agentic-tool-intake` Phase-2 delegates to · `enhance-pipeline` EXPAND row |
| **2 FILTER ⇐ DEBATE** | `skills/converge` Acts 1-2 (steelman→critique) OR `debate-converge` for a real council; optional fan-out `agents/perspective-trio` (3 lenses) / `agents/persona-pipeline` (6-stage board) |
| **3 HARMONIZE ⇐ CONVERGE+HARMONIZE** | `skills/converge` full 5-act (steelman→critique→compare→synthesize→reject-log) → ONE+ synthesized tool-spec(s). AUDIT-not-PERSUASION bias guards inherited. |
| **4 FORGE / DELIVER** | the **routed** member from Stage 0: `agentic-tool-forge` (create) · `agentic-tool-intake` (adapt/absorb/install; install gated via `claude-code-concierge`) · `agentic-tool-trainer`+`-evaluator` (improve/test/audit). `--type` honored by forge's type router; save-path by `--location`. Naming inside Stage 4 is forge's existing delegation to `anima` — the conductor never names. Loops the terminal when the synthesis yields multiple tools. |

> **Anti-NIH discipline**: the conductor EMITS invocations of the above; it never inlines
> their logic. A missing optional primitive degrades to the in-repo column with a one-line
> diagnostic — never a hard failure. `--dry-run` proves it: grep the run confirms only
> delegation to existing members + native research tools — zero reimplementation.

## How it works
```text
operator invokes /agentic-tool-pipeline "<source-object>"
        v   STAGE 0 ROUTE  -> terminal family {forge | intake | trainer | defer}
        v   STAGE 1 EXPAND -> findings + similars + prior-art bundle
        v   STAGE 2 FILTER -> debated / selected candidate set + corrections
        v   STAGE 3 HARMONIZE -> ONE+ synthesized tool-spec(s) (via `converge` 5-act)
        v   STAGE 4 FORGE  -> routed member forges/adopts/improves + saves to --location
        v   emit exactly ONE STOP marker as the last line of the turn
```

## DNA Geracional — apply to self + pass on (3 existing rails, ONE manifest of pointers)
The 11 principles are **not re-authored** — each is a pointer to an existing SSOT,
assembled into ONE manifest that travels by mechanisms that already exist:

| Principle(s) | Canonical SSOT |
|---|---|
| DRY · KISS · SSOT · YAGNI · ANTI-OVER-ENG | `agentic-tool-forge` §0/§Topology · host `scope-discipline-pre-creation` 6Q |
| ANTI-THEATER | `protocols/agentic-tool-lifecycle.md` §8 · host `anti-theater-grounding-protocol` 8Q |
| BOY-SCOUT | `protocols/exit-hygiene.md` · `skills/postflight` P1 SWEEP |
| DNA-GERACIONAL | `protocols/delegation/delegation-dna-prompt.md` §DNA Heritage Block |
| CONTINUITY · HANDOFF | `skills/postflight` P3 seed · `references/continuation-seed-contract.md` |
| IDEMPOTENCY | `agentic-tool-forge` Phase-8 (skip-if-identical) |

- **APPLY (self)** — this `## DNA Geracional` section IS the conductor self-governing.
- **PASS (produced tools)** — rely on forge's *existing* DNA-inheritance (it already
  injects §0 + gates + DUED + Refs into the child); do **not** re-inject (DRY).
- **PASS (delegated sub-agents)** — emit the verbatim **DNA Heritage Block** in each
  Stage-1/2 `Task` sub-prompt (`protocols/delegation/delegation-dna-prompt.md`).
- **PASS (across compact/clear)** — ride the `postflight` P3 `dna.principles[]` +
  `dna.canonical_ref` continuation seed, so a fresh amnesic agent resuming a multi-tool
  run inherits them.

## "Does NOT do" (anti-overlap — it conducts, never re-executes)
Does NOT author/forge directly (→ `agentic-tool-forge`) · does NOT decide adopt-or-not
(→ `agentic-tool-intake`) · does NOT score behavior (→ `agentic-tool-evaluator`) · does
NOT improve/distill (→ `agentic-tool-trainer`) · does NOT name (→ `anima`, inside forge) ·
does NOT reimplement research/debate/convergence (→ forge Phase-1 / `debate-converge` /
`converge`) · does NOT install (→ intake's gated `claude-code-concierge`) · does NOT ship
features or drive sessions (→ `enhance-pipeline` / `quiesce` / `auto-pilot`).

| Sibling | Its scope | This conductor's delta |
|---|---|---|
| `agentic-tool-forge` | ONE bare intent → ONE tool | accepts ANY source-object type + routes; forge is just its create-terminal |
| `agentic-tool-intake` | ONE existing candidate → adopt verdict | its candidate-terminal; intake doesn't run the full EXPAND→CONVERGE front-half for intents |
| `agentic-tool-trainer`/`-evaluator` | improve/score ONE owned tool | its improve-terminal |
| `enhance-pipeline` | ONE *feature* → shipped code | **same EXPAND→FILTER→HARMONIZE engine**, but DELIVER = *forge agentic-tools*, not ship a feature. Sibling along the "the artifact IS a tool" axis. |

## Machine output (`--json`)
```json
{"source_object":"<…>","route":"forge|intake|trainer|defer","stage":"ROUTE|EXPAND|FILTER|HARMONIZE|FORGE|done",
 "verdict":"FORGED|EXTEND|INSTALL|ADAPT|IMPROVE|DEFER","produced":[{"type":"skill","name":"<…>","path":"<…>","location":"<…>"}],
 "stop_marker":"STOP-DONE|STOP-HITL|STOP-ERROR|CONTINUE","_agent_feedback":"<governance hints>"}
```
Exit codes ([C06]): `0` produced OR proposal emitted (`--dry-run`) · `1` error · `2` HITL/defer.

## STOP-marker grammar (paired with `--goal-aware`, shared with the family — not re-authored)
Emit exactly ONE terminal marker as the last line of each turn:
```text
<!--ORCH-STATUS: STOP-DONE -->     tool(s) produced (or proposal emitted under --dry-run)
<!--ORCH-STATUS: STOP-HITL -->     HITL escalation required (DEFER-HITL, install-gate, HUMAN_DOMAIN)
<!--ORCH-STATUS: STOP-ERROR -->    unrecoverable error (routed member / network / rate-limit)
<!--ORCH-STATUS: CONTINUE -->      stage done; pipeline continues; evaluator decides next turn
```

## Protocol Rules (bounds)
- Worktree discipline always on (`skills/worktree-policy`); never commit to main.
- Delegation depth ≤ 2 (forge-like recursion cap); parallel ≤ 3; 6-attempt escalation rule.
- EXPAND external research is time-boxed; cite sources (never fabricate prior art).
- HARMONIZE is AUDIT-not-PERSUASION (inherits `converge` reject-log + bias guards).
- HUMAN_DOMAIN + non-negotiable guardrails (secrets/PII, force-push protected, gated
  install, cross-org) ALWAYS halt → HITL.
- Exactly ONE STOP marker per turn (the `/goal` evaluator contract).

## §Quality Tests (self-dogfood — 6/6)
1. **Self-Application** — this skill was forged *by its own pipeline*: Stage-0 classified
   "a conductor that forges tools" → INTENT → forge; Stage-1 EXPAND surfaced the in-repo
   similars (`enhance-pipeline`, the four `agentic-tool-*`) and the DRY ≥50% test confirmed
   NO single member routes-by-source-object across the family (gap real); Stage-2/3
   debated+converged the 5-stage shape; Stage-4 forge authored this SKILL.md, `anima` named
   it (`agentic-tool-pipeline`, rejected `-foundry`/`-conductor`), DNA inherited. ✅
2. **Non-Contradiction** — orchestrates siblings without duplicating them; consistent with
   the lifecycle SSOT + `enhance-pipeline` thin-preset precedent. ✅
3. **Survival** — applied to itself it advocates routing-then-forging; it IS a routed,
   forged skill. ✅
4. **Bounded-Responsibility** — `--dry-run` · `--blocks` · confirm-before-write ·
   recursion ≤2 · routes (never re-does) · DUED sunset. ✅
5. **Explicit-Exception** — §0 BEING>Rules escape + HUMAN_DOMAIN escalation + `--type`/`--location` overrides + AMBIGUOUS→DEFER-HITL. ✅
6. **Utility-Sunset** — §DUED below. ✅
Pre-creation scope-discipline 6Q: 6/6 (WHERE=community framework · DRY=gap-confirmed
[no source-object conductor] · WHY=operator directive · WHO=any agent + amnesic ·
FITS=lifecycle-family conductor · MIN=Goldilocks thin-preset). Anti-theater 8Q REALITY: 8/8.

## §DUED Sunset (qualitative, not counter-based)
Deprecate when ANY: the lifecycle family absorbs the conductor into a unified
`agentic-tool-lifecycle` entry (E6) · the host ships a native multi-source tool-genesis
conductor (E1) · `enhance-pipeline` generalizes to a `--target=agentic-tool` driver that
supersedes it (E6) · operator retraction (E4) · ≥3 false-positive routings (E5).
Dormant-by-design otherwise.

## §Refs
- Lifecycle members (co-located): `skills/agentic-tool-forge` · `skills/agentic-tool-intake`
  · `skills/agentic-tool-evaluator` · `skills/agentic-tool-trainer` · shared
  `protocols/agentic-tool-lifecycle.md` (§3 diagram carries the `conduct` slot).
- Naming: `skills/anima` (Stage-4 naming, delegated *inside* forge).
- Convergence kernel: `skills/converge` (5-act) · `agents/perspective-trio` ·
  `agents/persona-pipeline` · `agents/cascade-resolver` · `skills/convergence-engine`.
- Sibling thin-preset (the precedent): `skills/enhance-pipeline` (feature axis).
- DNA rails: `protocols/delegation/delegation-dna-prompt.md` · `skills/postflight`
  (P3 seed + `references/continuation-seed-contract.md`) · `skills/agentic-delegation`.
- Governance: `skills/worktree-policy` · `skills/hierarchical-merge` · `CONTRIBUTING.md`.
- Cross-link slug: `[[agentic-tool-pipeline]]`.

## Changelog
| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-06-25 | Bootstrap — the **conductor** of the `agentic-tool-lifecycle` family. Net-new = the 4-row Stage-0 source-object router + the typed Stage-4 terminal; everything else delegates (forge Phase-1 research · `converge` 5-act · `perspective-trio`/`persona-pipeline` · the four members). Sibling thin-preset of `enhance-pipeline` (tool-genesis axis vs feature axis). 11-principle DNA applied to self + passed via the 3 existing rails (forge inheritance · `delegation-dna-prompt` · `postflight` P3 seed). Named via `anima` (`agentic-tool-pipeline`; rejected `-foundry` collides-with-forge, `-conductor` ontology-mismatch). Self-forged (the §Quality-Tests Self-Application IS its own genesis trace). 6/6 self-validity + 8/8 anti-theater + 6/6 scope-discipline. |

## License
MIT (matches multi-agent-os repo `LICENSE`).
