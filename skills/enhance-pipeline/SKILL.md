---
name: enhance-pipeline
version: "0.2.0"
description: |
  Drive ONE feature/enhancement through the full divergent→convergent→deliver
  lifecycle: EXPAND (analyze · internal+external research · find gaps/fails/errors/
  logical-fails/pendings · compare · critique · ideate) → FILTER (filter · select ·
  debate · refine · critique · correct) → HARMONIZE (debate · converge · de-entropy ·
  harmonize) → DELIVER (plan · execute · test · validate · deploy). A thin preset that
  COMPOSES existing primitives (find-docs, converge, audit, auto-pilot, quiesce, Task
  fan-out, WebSearch) — reimplements nothing. Sibling of auto-pilot (one goal), quiesce
  (the session), converge (N proposals). Accepts: --feature, --blocks, --driver,
  --dry-run, --output, --auto-merge[-reason], --autonomy-threshold, --max-pdca.
  Use when the operator wants a feature taken from idea → researched → critiqued →
  converged → planned → shipped as one governed pass: "enhance X end-to-end",
  "research and ship this feature", "full pipeline on Y", "dynamic workflow for Z".
  Triggers: "enhance-pipeline", "/enhance-pipeline", "dynamic workflow", "research and
  ship", "full lifecycle on", "divergent to convergent to deliver".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch
---

# Enhance-Pipeline

Thin **feature-lifecycle** preset. `enhance-pipeline` does not re-implement research,
critique, convergence, delegation, or delivery — it sequences four stages, and **every
stage lands on a primitive that already exists in this repo** (or a host built-in).
It is the divergent→convergent→deliver complement to its siblings.

## Purpose

Take a single feature/enhancement from raw idea to shipped artifact through one
governed, override-friendly, token-economic pass — diverging wide (research + gap-find
+ ideation), filtering down (select + debate + correct), harmonizing to one synthesis
(`converge`), then delivering (plan → execute → test → validate → deploy). Codifies the
operator's recurring "analyze, research, compare, critique, expand, converge, plan,
execute, deploy" invocation as one reusable command.

## When to use

- A feature/enhancement needs the full research→critique→converge→ship lifecycle.
- The solution space is wide and benefits from divergent expansion before convergence.
- Internal + external research must precede a build (avoid NIH; ground in prior art).
- The operator wants a single command to drive idea → PR, not N manual steps.

## When **not** to use

- Single-shot edit / typo / one-file fix — disproportionate ceremony (just do it).
- Read-only Q&A — answer directly.
- The SESSION (not one feature) needs driving to green → use `quiesce`.
- ONE already-scoped goal needs decompose+delegate (no research/converge) → `auto-pilot`.
- Merging N existing proposals only → `converge` directly.
- Destructive ops (force-push protected, drop prod) — always HITL.

## Trigger Phrases

- "enhance-pipeline" / "/enhance-pipeline"
- "dynamic workflow for <X>" / "full lifecycle on <X>"
- "research and ship <feature>" / "divergent to convergent to deliver"
- "analyze, research, converge, and deliver <feature>"

## The four stages (the pipeline predicate)

```text
EXPAND     := analyze + internal-research + find[gaps,fails,errors,logical-fails,pendings]
              + external-research + compare + critique + ideate/brainstorm/expand
FILTER     := filter + select + debate + refine + critique + correct
HARMONIZE  := debate + converge + refine + correct + de-entropy + harmonize
DELIVER    := plan + execute + test + validate + deploy
```

A stage is COMPLETE when its primitive returns a structured artifact the next stage
consumes. The pipeline is DONE when DELIVER's artifact is shipped (PR merged/green) or,
under `--dry-run`, when the plan is emitted without execution.

## How it works

```text
operator invokes /enhance-pipeline "<feature>"
        |
        v   resolve flags -> defaults unless overridden
        v
  STAGE 1 EXPAND (divergent)  -> findings + ideas + prior-art bundle
        |
        v
  STAGE 2 FILTER (converge-1) -> ranked/selected candidate set + corrections
        |
        v
  STAGE 3 HARMONIZE (converge-2) -> ONE synthesized spec (via `converge` 5-act)
        |
        v
  STAGE 4 DELIVER -> plan -> execute -> test -> validate -> deploy (PR + PDCA)
        |
        v   emit exactly ONE STOP marker as the last line of the turn
```

## Composition (the wiring it emits)

Every stage prefers an **in-repo / host primitive** (always available, portable,
layer-pure per `rules/` Layer-Purity). User-scope or plugin primitives are **optional
enhancements** invoked only *if installed* — never a hard dependency.

| Stage | In-repo / host primitive (ALWAYS) | Optional enhancement (IF installed) |
|---|---|---|
| **1 EXPAND** | `Grep`/`Glob`/`Read` internal scan · `Task` analysis subagent(s) · `skills/find-docs` · `WebSearch`/`WebFetch` external | `pre-decision-audit` skill · `auto-perspective-trio` agent · `exa`/`context7`/`ref-tools` MCP |
| **2 FILTER** | `Task` fan-out (N reviewer lenses) · `skills/audit` · `skills/rule-quality-tests` | `auto-persona-pipeline` agent (6-stage board) |
| **3 HARMONIZE** | `skills/converge` (in-repo 5-act: steelman→critique→compare→synthesize→reject-log) | — |
| **4 DELIVER** | `skills/auto-pilot` (decompose+delegate) · test-runner via `Bash` · `skills/worktree-policy` · `skills/quiesce` (PDCA-converge the PR) | `gsd-*` agents · `verification-before-completion` (superpowers) · `ship`/gstack |

> **Anti-NIH discipline**: the skill EMITS invocations of the above; it never inlines
> their logic. A missing optional primitive degrades gracefully to the in-repo column
> with a one-line diagnostic — never a hard failure.

## Override parameters

| Flag | Default | Allowed / Notes |
|---|---|---|
| `"<feature>"` (positional) | *required* | the feature/enhancement to drive through the pipeline |
| `--blocks` | `1,2,3,deliver` | comma list — run a subset (e.g. `1,2` to stop before HARMONIZE) |
| `--driver` | `auto-pilot` | DELIVER driver: `auto-pilot` (in-repo) \| `quiesce` (in-repo) \| `auto-orchestrator` (user-scope, IF installed — degrades to `auto-pilot`) \| `<custom>` |
| `--dry-run` | `false` | run EXPAND→FILTER→HARMONIZE + emit the plan; STOP before execution. With `--blocks`: `--blocks` chooses WHICH stages run, then `--dry-run` suppresses execution of any remaining DELIVER block (so `--blocks=1,2 --dry-run` ≡ `--blocks=1,2`) |
| `--output` | `table` | report format: `table` \| `list` \| `json` (machine contract — see §Output contract) |
| `--auto-merge` | `hold` | `authorized` \| `hold` \| `off` (DELIVER PR; `authorized` requires reason + gates) |
| `--auto-merge-reason` | *(none)* | required-non-empty when `--auto-merge=authorized` |
| `--autonomy-threshold` | `0.85` | `0.0`-`1.0` — DELIVER merge-gate band |
| `--max-pdca` | `6` | per-PR PDCA iteration cap in DELIVER |

## Output contract (`--output=json`)

`--output=table` (default) and `list` are human-facing. `--output=json` emits one
machine-consumable object (per the repo's parseable-output discipline):

```jsonc
{ "stage": "EXPAND|FILTER|HARMONIZE|DELIVER|done",
  "status": "ok|error|hitl",
  "stop_marker": "STOP-DONE|STOP-HITL|STOP-ERROR|CONTINUE",
  "plan": [ /* DELIVER steps (present under --dry-run or pre-execute) */ ],
  "findings": [ /* EXPAND/FILTER findings, if any */ ] }
```

Exit codes: `0` = delivered OR plan emitted (`--dry-run`) · `1` = error (`STOP-ERROR`) ·
`2` = HITL escalation (`STOP-HITL`). Mirrors `[C06]` AI-native structured-output.

## STOP-marker grammar (paired with `--goal-aware`, not re-authored)

Emit exactly ONE terminal marker as the last line of each turn — the `/goal` Stop-hook
evaluator (shared with `quiesce`/`auto-pilot`) reads it:

```text
<!--ORCH-STATUS: STOP-DONE -->     pipeline complete (delivered, or plan emitted under --dry-run)
<!--ORCH-STATUS: STOP-HITL -->     HITL escalation required (also prepend above any action block)
<!--ORCH-STATUS: STOP-ERROR -->    unrecoverable error (subagent / network / rate-limit)
<!--ORCH-STATUS: CONTINUE -->      stage done; pipeline continues; evaluator decides next turn
```

## Relationship to siblings

| Tool | Scope | Drives |
|---|---|---|
| `enhance-pipeline` (this) | ONE feature | divergent EXPAND → convergent FILTER+HARMONIZE → DELIVER |
| `auto-pilot` | ONE goal | decompose → select → spawn → converge (no research/ideation phase) |
| `quiesce` | the SESSION | termination predicate over ALL open items → steady state |
| `converge` | N proposals | 5-act merge (this skill's STAGE 3 lands here) |
| `refine-braindump-to-prompt` | ONE braindump | RECOVER → DRAFT → REFINE → RED-TEAM → RENDER **one executable prompt** (does not ship; may hand the prompt to a driver) |

`enhance-pipeline` MAY invoke `auto-pilot`/`quiesce` in DELIVER and `converge` in
HARMONIZE; it never re-implements delegation, convergence, or anomaly detection.

## Auto-merge

`--auto-merge=authorized` lets the DELIVER driver queue GitHub native auto-merge **only**
when all gates pass (mergeable + green + all-comments-answered + agentic convergence +
autonomy ≥ `--autonomy-threshold` + non-empty reason) and no refusal applies (protected
deploy branch, CI/infra files touched, native auto-merge disabled, operator cancel).
Otherwise `hold` (operator merges) or `off`. Always `--squash --delete-branch`.
Fire-and-forget — no local merge queue across turns (amnesic-safe).

## Protocol Rules (anti-loop invariants + bounds)

- `--max-pdca` (default 6) caps per-PR PDCA in DELIVER; diminishing returns → escalate.
- Worktree discipline always on (`skills/worktree-policy`); never commit to main.
- Delegation depth ≤ 2; Sentinel HIGH auto-blocks (`sentinel/config.json` authoritative).
- 6-attempt escalation rule (different approach each attempt).
- Exactly ONE STOP marker per turn (the `/goal` evaluator contract).
- EXPAND external research is time-boxed; cite sources (anti-hallucination — never
  fabricate prior art).
- HARMONIZE is AUDIT-not-PERSUASION (inherits `converge` bias guards + reject-log).
- HUMAN_DOMAIN + non-negotiable guardrails (secrets/PII, force-push protected,
  prod/irreversible, cross-org) ALWAYS halt the pipeline → HITL.

## Failure modes

Each lands on the existing STOP-marker grammar — no new mechanism:

- **STAGE 3 `no-convergence-possible`** (`converge` cannot reconcile proposals) →
  `STOP-HITL` carrying `converge`'s reject-log; operator arbitrates.
- **EXPAND research empty / all-rate-limited** → proceed internal-only + emit a
  one-line diagnostic (never fabricate prior art); `CONTINUE`.
- **DELIVER driver failure** (subagent/network/rate-limit) → `STOP-ERROR`.
- **Empty / invalid `"<feature>"`** → `STOP-ERROR` before STAGE 1 (nothing to drive).
- **`--max-pdca` exhausted in DELIVER** → `STOP-HITL` (diminishing returns → escalate).

## DNA Geracional (inherited by every spawned agent)

- **Dogfood**: validate the pipeline on its own artifacts before declaring done.
- **Persist-over-fail**: write-ahead-checkpoint each obligation (task/ticket/note)
  BEFORE executing, so a mid-pipeline collapse is recoverable.
- **DRY / KISS / YAGNI / SSOT** — compose primitives, never duplicate them.
- **No self-destructive decisions** — nothing that boomerangs on a future session.
- **Boy-Scout** — leave every repo cleaner than found.

## Examples

```text
/enhance-pipeline "decision-audit report for ASH/walkthrough"
/enhance-pipeline "rate-limit middleware" --dry-run            # plan only, no execute
/enhance-pipeline "dark-mode toggle" --blocks=1,2 --output=json
/enhance-pipeline "auth refactor" --driver=quiesce --auto-merge=hold
/enhance-pipeline "search index" --auto-merge=authorized --auto-merge-reason="nightly feature run"
```

## Validation

- `tests/validate-plugin.sh` enforces (generically): `skills/enhance-pipeline/` contains
  `SKILL.md` with valid frontmatter.
- Skill file size in the sibling norm (≈14KB; cf. `converge` 15KB, `maos-concierge` 14.6KB).
  The hard 12288B ceiling in `validate-plugin.sh` is `auto-pilot`-specific, not a global gate.
- `commands/enhance-pipeline.md` carries matching `name: enhance-pipeline` frontmatter.
- Satisfies the 10-item checklist in `skills/skill-writer/SKILL.md`.
- `--dry-run` proves composition: grep the run confirms only `Task`-delegation to existing
  skills/agents + native research tools — zero reimplementation.

## Related

- `commands/enhance-pipeline.md` — operator-facing command surface
- `skills/auto-pilot/SKILL.md` — single-goal delegation kernel (default DELIVER driver)
- `skills/quiesce/SKILL.md` — session-quiescence preset (alternate DELIVER driver)
- `skills/converge/SKILL.md` — 5-act proposal merge (STAGE 3 HARMONIZE)
- `skills/find-docs/SKILL.md` — documentation discovery (STAGE 1 internal research)
- `skills/audit/SKILL.md` — audit primitive (STAGE 2 FILTER)
- `skills/worktree-policy/SKILL.md` — write discipline every stage honors
- `skills/status-map/SKILL.md` — status reporting templates
- `CONTRIBUTING.md` — PR convergence + tracker conventions

## Versioning

- v0.2.0 — self-enhance via recursive `--dry-run` on itself (3 orthogonal lenses:
  completeness · DX · composition). Fixes 3 paradox-gated real defects: **F1** layer-purity
  guard on `--driver=auto-orchestrator` (user-scope, IF installed — was mis-leveled as
  in-repo); **F2** new `## Failure modes` section (parity with converge/auto-pilot, reusing
  STOP-marker grammar); **F6** `## Output contract` for `--output=json` (JSON skeleton +
  exit-code map). Folded F3 (`--blocks`+`--dry-run` precedence) into the `--dry-run` row.
  Deferred F4/F5 (low doc-consistency) to a batched PATCH; F7/F8/F9 paradox-gated out.
- v0.1.0 (initial) — four-stage feature lifecycle (EXPAND→FILTER→HARMONIZE→DELIVER)
  composing in-repo primitives with optional-enhancement degradation; override flags
  incl. `--blocks`/`--dry-run`/`--output`/`--driver`; STOP-marker grammar reuse;
  depth/PDCA bounds; AUDIT-not-PERSUASION HARMONIZE; DNA Geracional.

## License

MIT (matches multi-agent-os repo `LICENSE`).
