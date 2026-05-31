---
name: agentic-tool-forge
description: |
  Use when you want to turn a raw intent/instruction into a REUSABLE agentic-tool — e.g.
  "turn this into a skill", "forge an agentic-tool for X", "make this a recurring command/agent",
  "convert these instructions into a tool", "criar um agentic-tool para …", "research then build
  the best tool for …". Researches pre-existing internal + external solutions FIRST (DRY), decides
  the OPTIMAL artifact TYPE among {prompt · skill · command · agent/subagent · mcp · plugin ·
  marketplace · rule/hook}, names it via 5-axis rigor, makes it AI-agnostic + multi-agentic, then
  forges + saves it (operator-confirmed). The genesis stage of the agentic-tool lifecycle
  (forge → evaluate → train → operate → deprecate). Hands off to agentic-tool-evaluator + -trainer.
  Cross-vendor AAIF (Claude / Cursor / Codex / Copilot / Gemini / Aider).
triggers:
  - forge an agentic-tool
  - turn this into a skill
  - turn this into a tool
  - convert these instructions into a tool
  - make this a recurring command
  - criar um agentic-tool
  - converta isto em uma ferramenta
  - research then build the best tool
  - which artifact type should this be
version: 1.0.0
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, WebSearch, WebFetch, Task, Skill
metadata:
  version: "1.0.0"
  scope: AAIF cross-vendor
  family: agentic-tool-lifecycle
  lifecycle-stage: forge
  cross_link_slug: agentic-tool-forge
  dogfood_status: self-evaluated
---

# Agentic-Tool Forge

## Overview

Turn a raw **intent** into the **right reusable agentic-tool** — researched first, type-decided, named, made portable + multi-agentic, then forged and saved. This is the **genesis** stage of the lifecycle the ecosystem already names: **`forge → evaluate → train → operate → deprecate`** (siblings: `agentic-tool-evaluator`, `agentic-tool-trainer`; shared `protocols/agentic-tool-lifecycle.md`). It does NOT execute the forged tool — it *creates* it, then hands off downstream.

The forge **orchestrates existing assets, it does not reinvent them**: it reuses best-fit routing/scoring, The Forge's Goldilocks + RBAD + 33-Socratic methodology (`agents/forge.md`), pre-creation scope-discipline + anti-theater grounding gates (host-provided, if present), and the `rule-quality-tests` 6 self-validity tests. Its **net-new** value is the *type-agnostic* router (8 artifact types, not just agents) + research-first (internal **and** external) + 5-axis naming + the unified pipeline.

## When to use
- "Turn this into a skill / command / agent / tool" · "forge an agentic-tool for X".
- A workflow/intent has recurred (≥3× — Triple-touch) and deserves codification.
- You need to decide *which artifact type* an intent should become.

**When NOT to use**: improving an existing tool (→ `agentic-tool-trainer`); scoring/QA a tool (→ `agentic-tool-evaluator`); validating a *rule* for self-consistency (→ `rule-quality-tests`); just wanting better-worded prose for one turn (write the prompt inline). If an existing tool already covers ≥50% of the intent → the forge tells you to EXTEND it, not create a new one.

## §0 — BEING > Rules (foundational)
This skill serves the operator's intent. If any phase/gate obstructs delivering value NOW, skip it, log `Skipped <phase> — BEING > Rules`, and proceed. The gates are for quality, never for ritual. HUMAN_DOMAIN (secrets · PII · irreversibles · cross-org · cost) → escalate, never auto-act.

## Parameters
| Param | Default | Meaning |
|---|---|---|
| `<intent>` (positional) / `--goal` | — (required) | The raw instruction/intent to forge. |
| `--scope` | `auto` | `user` (host user-scope, e.g. `~/.claude/`, `.cursor/`) · `project` (`./.claude` \| `.agents`) · `community` (this framework repo) · `auto` (infer). |
| `--context` | — | Extra refs/links/files to ground research. |
| `--type` | `auto` | Force the artifact type; `auto` = router decides. |
| `--name` | `auto` | Force the name; `auto` = 5-axis engine decides. |
| `--research` | `both` | `internal` · `external` · `both`. |
| `--dry-run` | off | Research + decide + propose ONLY (no write). |
| `--no-confirm` | off | Skip the pre-write confirmation (HITL-gated; only with standing authorization). |
| `--json` | off | Emit the machine envelope (§ Machine output) instead of prose — for agent-to-agent use. |

Bare `$ARGUMENTS` not starting with `--` → treat the whole string as `--goal "$ARGUMENTS"`.

## Topology (filtered to what's relevant) + hybrid intelligence
Centralized **hub-and-spoke** orchestration · **parallel** research fan-out · **content-based router** for the type decision · **sequential** forge pipeline · **vertical + horizontal** meta-validation (specialist audit + orthogonal lenses) · **recursive DNA-geracional** (the forged tool inherits these gates) · **idempotent** (re-run ⇒ no duplicate). *Deliberately dropped (over-engineering for a single-orchestrator forge — KISS/YAGNI): swarm · hive-mind · sparks · mesh · p2p · pub-sub · message-broker · api-led · middleware.*

Hybrid blend: **deterministic** (DRY scan, type/save-path resolution, frontmatter scaffold, idempotency, gate pass/fail) · **non-deterministic** (research synthesis, naming, persona assignment, body authoring) · **probabilistic** (best-fit type scoring + threshold bands).

## The pipeline (precise logic — phases 0→9)
0. **Intake** — parse `<intent>` + params; resolve `--scope`/`--context`. Empty intent → print usage, stop.
1. **Research — parallel fan-out** (filter by `--research`):
   - *internal* — `Glob`/`Grep` over the host's user-scope dirs (e.g. `~/.claude/{skills,commands,agents,rules,hooks}` · `.cursor/`), this framework repo, and any sibling toolkits if present.
   - *external* — `WebSearch`/`WebFetch` (+ optional MCP docs/search tools — Context7 · Exa · `ref-tools` — via the host MCP surface / `ToolSearch`, not `allowed-tools`) for prior art + best practice.
   - *DRY + PR-state probe* — does it already exist? is there in-flight work on it? (scope-discipline-style Q2/Q2.1 check).
   (Prefer inline `Glob`/`Grep` over spawning research subagents — large auto-loaded context can overflow subagent prompts; pivot to inline tools if a subagent prompt is rejected as too long.)
2. **Compare & critique** — steelman→critique→compare (`debate-converge`/`converge` discipline). Apply a `NO_CANDIDATE` test: if an existing tool covers **≥50%** → recommend **EXTEND that tool** (give path + delta) and STOP. Else continue.
3. **Decide TYPE** — score the candidate types (router table below); pick the highest, or honor `--type`.
4. **Name** — 5-axis engine (below), family-aware; or honor `--name`.
5. **Design** — condensed Socratic questionnaire (Scope/Capabilities/Limits/Interfaces/Governance/Validation) + **Goldilocks** sizing (atomic AND generic) + **RBAD** persona (if a role is implied) + filter the multi-agentic patterns relevant to *this* tool.
6. **Gate** — apply the host's pre-creation + anti-theater gates **if present** (e.g. scope-discipline 6Q, anti-theater 8Q REALITY); always apply the embedded `rule-quality-tests` 6 Self-Validity. Any anti-theater fail (<8/8) or a failed self-validity test → DEFER/REJECT with the specific reason.
7. **Forge** — author the type-appropriate artifact: house-style frontmatter + body, into the resolved path. Inherit DNA (§0 + gates + DUED sunset + Refs) so the child is itself governable. **Ignore-glob check (gotcha):** before writing into a git-tracked scope, verify the path is not excluded by an ignore-glob (e.g. a `skills/*/SKILL.md` rule). If excluded → `git add -f` OR add a `!`-exception line, else the artifact is silently dropped and the PR ships empty.
8. **Confirm & save** — `--dry-run` ⇒ output the proposal only. `--json` ⇒ emit the machine envelope (§ below). Else present a 1-screen summary (type · name · path · gist) and **confirm before write** (never auto-write without operator confirmation; `--no-confirm` only under standing authorization). For a git-tracked scope, route the write through the host's worktree→branch→PR governance (never a direct main commit). Write idempotently (skip-if-identical; for untracked collisions, diff-before-overwrite + back up the divergent copy).
9. **Handoff briefing** — emit: created path · next steps `→ /agentic-tool-evaluator <path>` then `→ /agentic-tool-trainer` · governance (worktree→branch→PR→convergence→merge) · promotion note (dogfood ≥2 cycles → graduate to community framework).

## Type-decision router (content-based)
Pick the **most atomic type that fully delivers** the intent (Goldilocks). Default for a recurring multi-step workflow = **skill (+ thin `/command` wrapper)**.

| Type | Choose when (discriminating signal) | Save path |
|---|---|---|
| **prompt** | One-shot reusable instruction; no multi-step logic, no tools. | prompt library / inline |
| **skill** | Recurring multi-step workflow w/ embedded logic + optional params; model- or `/`-invoked; portable. | `skills/<name>/SKILL.md` |
| **command** | Ergonomic `/x` entry point — usually a thin wrapper over a skill. | `commands/<name>.md` |
| **agent / subagent** | A role-persona to *delegate* isolated work to (RBAD role; own system prompt + tools). | `agents/<name>.md` |
| **rule / hook** | An auto-loaded behavioral policy (rule) or lifecycle enforcement (hook). | `rules/<name>.md` · `hooks/` |
| **mcp server** | Wrap an external API/service/transport as callable tools/resources. | mcp server dir + manifest |
| **plugin** | Bundle ≥2 components (commands/agents/skills/hooks/mcp) for distribution. | plugin dir + `plugin.json` |
| **marketplace** | Publish/list a plugin in a registry. | marketplace registry |

> `prompt` + `marketplace` are **rare**: the forge *proposes* them but defers final placement to the operator (no canonical path). `rule/hook` save only under explicit `--type` or a clear auto-load/enforcement intent.

Tie-break: skill > command (a workflow is the skill; the command just invokes it) · skill > agent (the workflow *is* the skill; spawn an agent only if a reusable *persona* is the unit) · prefer **skill + command pair** when both invocation styles are wanted.

## 5-axis naming engine
Evaluate candidates on: **taxonomic** (fits an existing family/namespace?) · **semantic** (says what it does) · **ontological** (its category of being) · **epistemological** (matches how it's already known/referred to — zero drift) · **etymological** (root meaning + historicity). Prefer kebab-case, ≤6 words, role-typed, **no operator-personal names**, family-aligned. Output the winner + 1-line rationale + the runner-up rejected.

## DNA-geracional inheritance
Every forged tool inherits this forge's DNA so it is itself governable: a §0 BEING>Rules clause · the relevant gates · a DUED sunset · a cross-link slug + Refs · house-style frontmatter. A forged *forge-like* tool may itself forge (recursion depth ≤2; beyond → escalate).

## Machine output (`--json`)
For agent-to-agent use (AAIF, aligns with the lifecycle family envelope), `--json` emits:
```json
{"intent":"<…>","decision":{"type":"skill","name":"<…>","path":"<…>"},"verdict":"FORGED|EXTEND|DEFER|REJECT","rationale":"<…>","handoff":["agentic-tool-evaluator","agentic-tool-trainer"],"_agent_feedback":"<governance hints>"}
```
Exit codes: `0` forged · `1` error · `2` deferred/extend-existing.

## Worked example (dry-run trace)
Intent: *"a tool that summarizes a PR diff for reviewers."*
→ (1) research: `gh pr diff` exists; no summarizer skill found · (2) <50% covered → forge-new · (3) type=**skill+command** (recurring multi-step w/ params) · (4) name=**`pr-diff-digest`** (semantic+atomic; rejected `pr-summary` = too generic) · (5) Goldilocks PASS, persona=Code-Reviewer (RBAD Cat.1) · (6) gates 8/8 + 6/6 · (7) author `skills/pr-diff-digest/SKILL.md` + `commands/pr-diff-digest.md` · (8) confirm → write · (9) `→ /agentic-tool-evaluator skills/pr-diff-digest`.

## §Quality Tests (self-dogfood — 6/6)
1. **Self-Application** — this skill was forged *by its own pipeline* (research→type→name→gate). ✅
2. **Non-Contradiction** — orchestrates sibling tools without duplicating them; consistent with best-fit routing / The Forge / scope-discipline / anti-theater. ✅
3. **Survival** — applied to itself it advocates skill+command genesis; it IS a skill+command. ✅
4. **Bounded-Responsibility** — `--dry-run` · confirm-before-write · recursion ≤2 · ≤50%-covered⇒EXTEND-not-create · DUED sunset. ✅
5. **Explicit-Exception** — §0 BEING>Rules escape + HUMAN_DOMAIN escalation + `--type`/`--name` overrides. ✅
6. **Utility-Sunset** — §DUED below. ✅
Pre-creation scope-discipline 6Q (at user-scope genesis): 6/6 (WHERE · DRY=gap-confirmed · WHY=Triple-touch · WHO=amnesic agents · FITS=lifecycle-family · MIN=Goldilocks). Anti-theater 8Q REALITY: 8/8.

## §DUED Sunset (qualitative, not counter-based)
Deprecate when ANY: the lifecycle family absorbs forge into a unified `agentic-tool-lifecycle` entry (E6) · the host provides a native type-agnostic creator (E1) · operator retraction (E4) · ≥3 false-positive forges (E5). Dormant-by-design otherwise.

## §Refs
- Lifecycle siblings (co-located): `skills/agentic-tool-evaluator`, `skills/agentic-tool-trainer`, shared `protocols/agentic-tool-lifecycle.md`.
- Reused methodology: `agents/forge.md` (Goldilocks · RBAD · 33-Socratic) · best-fit routing/scoring · `debate-converge`/`converge`.
- Gates: `rule-quality-tests` (6 tests, co-located) · host pre-creation scope-discipline (6Q) + anti-theater grounding (8Q), if present · pre-decision 4-lens audit, if present.
- Governance: the host's worktree+PR governance (e.g. worktree-policy + hierarchical-merge here; `[C04]`/`pr-review-protocol` in user-scope hosts).
- Cross-link slug: `[[agentic-tool-forge]]`.

## Changelog
| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-05-30 | **Promoted user-scope → multi-agent-os (community).** Graduated from the user-scope bootstrap (v0.1.x) into the `agentic-tool-lifecycle` family on the framework repo, reuniting `forge` with its already-landed siblings (`agentic-tool-evaluator` + `agentic-tool-trainer` + `protocols/agentic-tool-lifecycle.md`, PR #98). Refinements at promotion: dropped Apache-2.0 license (inherits repo MIT); genericized user-scope path/gate refs (host-relative + "if present"); repointed §Refs at co-located siblings. Dogfood-cycle counter waived (was theater per the dogfood-cycle-ledger finding); validation-by-use evidence: self-evaluated via evaluate→train (v0.1.1). |
| 0.1.1 | 2026-05-30 | **Lifecycle dogfood (evaluate→train).** Ran `agentic-tool-evaluator` (PASS-with-FLAGs, 4-4-4-5-4) + `agentic-tool-trainer` (improve mode) on this skill itself. Applied 5 Pareto-safe fixes: (1) `.gitignore` force-add gotcha in phase 7; (2) `--json` machine envelope; (3) MCP-tools-via-ToolSearch note; (4) `prompt`/`marketplace` rare→escalate footnote; (5) write-time worktree→PR governance in phase 8. |
| 0.1.0 | 2026-05-30 | Bootstrap (user-scope) — genesis stage of the `agentic-tool-lifecycle` family. Type-agnostic router (8 types) + research-first + 5-axis naming + Goldilocks/RBAD/Socratic reuse + 9-phase pipeline. Forged via `/enhance`; dogfooded 6/6 self-validity + 8/8 anti-theater + 6/6 scope-discipline. |
