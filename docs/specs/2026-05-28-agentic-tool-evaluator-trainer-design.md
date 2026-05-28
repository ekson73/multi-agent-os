# Design Spec — Agentic-Tool Lifecycle Skills (Evaluator + Trainer)

> **Status**: DRAFT — awaiting operator review (brainstorming gate per superpowers:brainstorming HARD-GATE).
> **Date**: 2026-05-28
> **Author**: Claude (Opus 4.8) under operator directive 2026-05-28 via `/enhance`.
> **Repo**: `multi-agent-os` (framework SSOT) → propagate to `eko-claude-plugins` + `vek-claude-plugins`.
> **Branch**: `feat/agentic-tool-evaluator-trainer`.

---

## 1. Operator directive (verbatim, pt-BR per language-policy-en-pt §3)

> *"Crie mais novos skills [criador de agentic-tools, testador de agentic-tools, treinador de agentic-tools] para o projeto multi-agent-os... agentic-tools pode ser [mcp, commands, prompts, skills, agents, subagents, etc]. Analise/critique/valide se devem ser skills separados ou 1 só. Já existe skill-creator da Anthropic e outros no mercado; analise/compare/decida. Os skills devem ser AI-agnostic (AAIF), compatíveis com [claude, atlassian rovo]. ... faça 33 perguntas socráticas por skill."*

**Operator-approved decisions (AskUserQuestion 2026-05-28)**:
1. **Architecture** → "2 novos + creator-extend": build **evaluator** (tester) + **trainer**; "creator" = extend existing `skill-writer` + `forge.md`, no redundant 3rd skill; + shared `references/`.
2. **33 Socratic Questions** → "Gerar + auto-responder p/ revisão" (forge.md style; this doc IS that artifact).

---

## 2. Architecture Decision Record (ADR)

### 2.1 Context — what already exists (DRY check per scope-discipline 6Q · Q2)

| Existing asset | Covers | Verdict |
|---|---|---|
| `skills/skill-writer/SKILL.md` | Authoring SKILL.md (AAIF, 30+ tools) | **Authoring covered** — do NOT duplicate |
| `agents/forge.md` | Meta-agent creator: 33 Socratic Q + Goldilocks + RBAD + **KPI eval** + **post-mortem feedback loop** | **Creator + agent-eval + evolve partially covered** |
| `skills/rule-quality-tests/SKILL.md` | 6 self-validity tests for *rules* | Adjacent (quality discipline, reusable rubric) |
| `agents/qa-validator.md` | QA validation of outputs | Adjacent |
| **(none)** | **Behavioral evaluation of any agentic-tool** | **GAP → evaluator** |
| **(none)** | **Improve a tool over time + distill skill from observed task** | **GAP → trainer** |

### 2.2 Decision

- **NO new "creator" skill.** Authoring already lives in `skill-writer` (skills) + `forge.md` (agents). The genuinely-new creator-flavored need — *"observe a human↔agent task → distill a walkthrough → emit a skill"* — is folded into the **trainer** (mode `distill`), because it is a trace→distill→codify operation, not from-scratch authoring.
- **2 net-new skills** + 1 shared reference library:
  - `agentic-tool-evaluator` — behavioral eval-harness for any agentic-tool.
  - `agentic-tool-trainer` — improve-over-time + distill-from-trace.
  - `references/agentic-tool-lifecycle.md` (shared) — common vocabulary: agentic-tool taxonomy, registry discovery, AAIF frontmatter parsing, scoring rubric, Rovo bridge. Referenced by both skills (progressive disclosure, one level deep per AAIF).
- **Rationale for separate (not 1 combined)**: distinct lifecycles (evaluate = validate-correctness *now*; train = improve *over time*) + AAIF "one skill = one capability" (skill-writer's own rule) + Goldilocks atomicity. Shared infra goes in `references/`, not a mega-skill.

### 2.3 "agentic-tool" scope (operator: mcp/commands/prompts/skills/agents/subagents/etc)

Both skills operate on the union **{skill (SKILL.md) · agent (.md) · subagent · command (.md) · prompt · MCP-tool-surface}**. Evaluation/training method adapts per type (see references). v1 depth: **skills + agents + commands** first-class; **MCP-tool / prompt** supported via the same behavioral-eval contract (input→behavior→rubric); subagent = agent variant.

---

## 3. Naming decision (operator delegated "calcule e decida")

| Role | Chosen name | Rationale | Operator may override |
|---|---|---|---|
| Tester | **`agentic-tool-evaluator`** | "Evaluator" is semantically accurate (behavioral eval, not unit-test — see §4). kebab-case, AAIF-valid, no collision. Operator said "testador"; `agentic-tool-tester` is the alias-acceptable alt. | ✅ confirm `evaluator` vs `tester` |
| Trainer | **`agentic-tool-trainer`** | Matches operator vocabulary; accurate (improve + distill). Alt: `-coach`/`-tuner`. | ✅ |

Naming anchors (recognized historicity): "evaluator" (eval/G-Eval/DeepEval lineage), "trainer" (ML training-loop + DSPy teleprompter lineage). Avoids `forge` collision (agent already named forge).

---

## 4. Anti-theater constraint — what "test" and "train" REALLY mean (Tomé / 8Q REALITY)

A SKILL.md is **prompt-markdown, not executable code.** Honest framing (validated via external research):

- **Evaluation = behavioral, not assertion-on-source.** Run a host agent **WITH vs WITHOUT** the tool against a **golden task set** (20–50 curated input→expected cases); score outputs with a **rubric** (deterministic checks where possible + LLM-as-judge for qualitative). Pattern: promptfoo / DeepEval (task-completion · tool-correctness · step-efficiency metrics). **NOT** "unit/integration/functional tests of code" — promising that would be theater.
- **Training = trace→reflect→distill loop** (GEPA/SIMBA/DSPy reflective-optimizer lineage): capture execution trajectory → reflect (what worked/failed) → emit improved instructions/examples → re-evaluate → keep a **Pareto frontier** of candidate versions (avoid regressing complementary cases). A/B two versions on the identical golden set.
- **Gamification + "collaboration/share results"** from the operator's feature list → **deferred to v2** (YAGNI / anti-over-engineering §4.6; low value in single-operator AI-native context; high build cost). Documented as explicit scope-cut, not silently dropped.

---

## 5. Rovo compatibility — the bridge (critical design constraint)

**Atlassian Rovo does NOT natively consume agentskills.io SKILL.md.** Rovo agents use a **Forge YAML manifest** (`rovo:agent` module: `key`, `name`≤30, `prompt` [string or `resource:`], `conversationStarters`, `actions[]`); actions are `rovo:action` Forge **functions** (code), knowledge = attached Confluence/Jira/Drive.

**Bridge (the only confirmed path)**: SKILL.md stays the **portable SSOT**; a transform step emits a Rovo Forge manifest:
- SKILL.md `body` → agent `prompt` (via `resource:key;path`)
- SKILL.md `description` → agent `description`
- `scripts/*` → `rovo:action` Forge functions

→ Both new skills carry a `## Rovo Bridge` section + the shared `references/agentic-tool-lifecycle.md` documents the codegen contract. "Compatible with Rovo" = **bridgeable**, not natively-loadable. (Honest per anti-theater R4 not-invented.)

---

## 6. 33 Socratic Questions + Answers — `agentic-tool-evaluator`

*(Structure reused from `agents/forge.md` §33 Socratic Questions — DRY.)*

### Scope (1–7)
1. **Atomic domain?** Behavioral evaluation of an agentic-tool. One verb: *evaluate*.
2. **In-scope tasks?** Build golden task set · run with/without tool · score via rubric · detect triggering failures · regression-diff vs baseline · compare 2 tools/versions · produce eval report.
3. **Out-of-scope?** Authoring (→ skill-writer) · improving the tool (→ trainer) · executing the tool's domain task for real · code unit-testing.
4. **Another asset covers part?** `rule-quality-tests` (rules only, static) · `qa-validator` (output QA). Evaluator generalizes to ANY agentic-tool, behaviorally. No full overlap.
5. **Reusable for future tasks in domain?** Yes — any new skill/agent/command/MCP-tool is evaluable by the same input→behavior→rubric contract.
6. **Typical input?** A target tool (path to SKILL.md/agent.md/command.md) + optional golden-set + optional baseline version.
7. **Typical output?** `EVAL-REPORT.md` (scores per dimension, pass/fail vs threshold, regressions, strengths/weaknesses, recommendation) + machine-readable JSON (`--json`, [C06]).

### Capabilities (8–14)
8. **Essential technical knowledge?** AAIF SKILL.md structure · behavioral-eval methodology · LLM-as-judge rubrics · golden-dataset design · regression diffing.
9. **Domain knowledge?** The agentic-tool taxonomy (skill/agent/command/MCP/prompt) + the host's discovery mechanism.
10. **Host tools needed?** Read, Grep, Glob, Bash (run eval cases), Write (report). Optionally Task (spawn a sub-agent to execute a case in isolation).
11. **External sources?** agentskills.io spec · promptfoo/DeepEval patterns (referenced, not hard-dependency).
12. **Patterns/conventions?** Golden-set 20–50 cases · CI <5min · rubric with deterministic-first then LLM-judge · `_agent_feedback` JSON shape (maos house style).
13. **Warm-start context?** `references/agentic-tool-lifecycle.md` (shared) + the target tool's frontmatter.
14. **Autonomy level?** Consultative-to-supervised: produces a report + recommendation; does NOT mutate the evaluated tool (that is the trainer's job → clean separation).

### Limits (15–21)
15. **NEVER do?** Never mutate the evaluated tool · never claim code-unit-test coverage · never fabricate golden cases that don't exercise real behavior (anti-theater R4) · never leak secrets/PII in eval traces (gitleaks pre-report).
16. **Escalate to user when?** Golden-set absent and cannot be auto-derived · target tool ambiguous · eval requires production data (HUMAN_DOMAIN).
17. **Delegate when?** Improvement actions → `agentic-tool-trainer`. Authoring fixes → `skill-writer`.
18. **No-touch zones?** The evaluated tool's source (read-only) · production data.
19. **Risk if mis-calibrated?** False-green (skill ships broken) OR false-red (blocks good tool). Mitigate: rubric transparency + with/without control + human-reviewable report.
20. **Revert?** Read-only by design — nothing to revert beyond deleting the report.
21. **Fallbacks?** If no golden-set: generate a minimal smoke-set (3–5 cases) from the tool's own description/examples + flag low-confidence.

### Interfaces (22–26)
22. **Interacts with?** Upstream: `skill-writer`/`forge` (authored tool). Downstream: `agentic-tool-trainer` (consumes eval report to improve). Sibling: `rule-quality-tests` (rules), `qa-validator`.
23. **Comms format?** Markdown report + `--json` machine block ([C06]); `_agent_feedback` envelope.
24. **Receives tasks how?** Skill invocation with target path arg; or via trainer/orchestrator dispatch.
25. **Reports results how?** `EVAL-REPORT.md` + JSON; scores 0–5 per dimension + overall verdict (PASS/FLAG/FAIL).
26. **Integrates with ecosystem?** Reuses forge's KPI scale (Efficacy/Efficiency/Autonomy/ScopeFit) extended with eval-specific (Triggering · TaskCompletion · ToolCorrectness · Regression).

### Governance (27–30)
27. **Who can invoke?** Any agent/operator. Read-only → low-risk.
28. **Documents decisions how?** Audit trail in report (which golden cases, which rubric, which baseline).
29. **Success metrics (KPIs)?** Eval reproducibility · false-positive rate <20% · time-to-report <30min · regression-catch rate.
30. **Evolve how?** Feedback loop: golden-set grows from production failures; rubric refined when false +/- observed (→ DUED, not counter).

### Validation (31–33)
31. **Functional test of the skill itself?** Self-eval: run evaluator on a known-good and known-broken skill; expect PASS and FAIL respectively (dogfood).
32. **Edge cases?** Tool with no examples · non-deterministic tool output · tool that only triggers in rare context · MCP-tool with side effects (sandbox).
33. **ROI (value vs cost)?** Prevents shipping broken/untriggering tools (compounding cost) at ~30min eval cost. Reusable across every tool in 3 repos.

---

## 7. 33 Socratic Questions + Answers — `agentic-tool-trainer`

### Scope (1–7)
1. **Atomic domain?** Improve an agentic-tool over time + distill a new one from an observed trace. Verb: *train* (incl. *distill*).
2. **In-scope tasks?** (a) **improve**: consume eval report → trace→reflect→distill improved version → re-eval → A/B → recommend/apply; (b) **distill**: observe a human↔agent task → generate walkthrough (steps · do/don't · patterns/anti-patterns · DoR · DoD · acceptance criteria) → emit a new draft skill (hand to skill-writer for finalization); (c) track operator instructions/corrections → patch the tool; (d) progress tracking over time; (e) compare versions; (f) strengths/weaknesses + training plan + goals.
3. **Out-of-scope?** Behavioral scoring itself (→ evaluator — trainer *consumes* its report) · from-scratch authoring polish (→ skill-writer) · gamification/collaboration (v2).
4. **Another asset covers part?** `forge.md` already does agent *evolve* + KPI + post-mortem → trainer **reuses forge's evolve/KPI patterns** and extends to all agentic-tool types + the distill-from-trace mode. `skill-writer` finalizes distilled drafts. Clear composition, not duplication.
5. **Reusable?** Yes — any tool + any trace.
6. **Typical input?** (improve) target tool + its `EVAL-REPORT.md` + golden-set; (distill) a session transcript / task trace + the tool-type target.
7. **Typical output?** (improve) improved tool version + diff + re-eval delta + Pareto note; (distill) `WALKTHROUGH.md` + draft `SKILL.md`/agent spec + handoff to skill-writer.

### Capabilities (8–14)
8. **Technical knowledge?** Reflective prompt-optimization (GEPA/SIMBA/DSPy lineage) · trace analysis · walkthrough distillation · AAIF authoring (delegates final polish).
9. **Domain knowledge?** agentic-tool taxonomy · the operator's conventions (naming, governance) · forge's RBAD/Goldilocks.
10. **Host tools?** Read, Grep, Glob, Write, Edit (mutate tool — supervised), Bash, Task (re-eval via evaluator).
11. **External sources?** DSPy/GEPA reflective-optimizer patterns · agentskills.io.
12. **Patterns?** trace→reflect→distill · Pareto frontier of candidates · A/B on golden-set · forge KPI scale · operator-correction capture (links to `operator-quote-capture` skill).
13. **Warm-start?** Shared `references/agentic-tool-lifecycle.md` + target tool + its eval report + trace.
14. **Autonomy?** Supervised for **apply** (mutates a tool → PR + review); autonomous for **propose** (emit improved draft + diff).

### Limits (15–21)
15. **NEVER?** Never apply a mutation that regresses the golden-set (Pareto guard) · never claim improvement without re-eval evidence (anti-theater) · never auto-merge tool changes (PR + review per [C07]) · never distill a skill from a trace containing secrets/PII (sanitize first) · never create disposable/task-specific tools (forge anti-pattern).
16. **Escalate when?** Eval shows no improvement after N reflect iterations (cap) · distilled tool overlaps existing (DRY → ask) · mutation touches HUMAN_DOMAIN.
17. **Delegate when?** Scoring → evaluator · final SKILL.md polish/validation → skill-writer · agent-specific evolve → forge.
18. **No-touch?** Production data · other tools not in scope · auto-merge.
19. **Risk if mis-calibrated?** Over-fitting a tool to golden-set (loses generality) · prompt bloat · regression. Mitigate: Pareto frontier + held-out cases + size budget.
20. **Revert?** Tool mutations are PR'd → revert = close/revert PR; drafts are non-destructive.
21. **Fallbacks?** If improve plateaus: report "no further gain, escalate" rather than churn (bounded iterations).

### Interfaces (22–26)
22. **Interacts with?** Upstream: `agentic-tool-evaluator` (report). Downstream: `skill-writer` (finalize distilled draft) · `forge` (agent evolve). Sibling: `operator-quote-capture` (corrections feed).
23. **Comms?** Markdown (WALKTHROUGH/diff/training-plan) + `--json`.
24. **Receives tasks?** Invocation with mode (`improve`/`distill`/`track`) + target/trace.
25. **Reports?** Improved version + re-eval delta + Pareto note; OR walkthrough + draft + handoff.
26. **Integrates?** forge KPI loop + evaluator report contract + operator-quote-capture corrections.

### Governance (27–30)
27. **Who invokes?** Operator/orchestrator. Apply-mode gated by review.
28. **Documents?** Training log (versions, scores over time, decisions) — enables "progress tracking" + "version comparison" features.
29. **KPIs?** Score delta per iteration · iterations-to-plateau · regression count (must be 0) · distilled-skill acceptance rate.
30. **Evolve?** Meta: trainer's own reflection prompts improve via the same loop (bounded).

### Validation (31–33)
31. **Functional test?** Dogfood: take a deliberately weak skill → train → evaluator confirms score↑ with 0 regressions. Distill: feed a known trace → expect a coherent walkthrough + draft.
32. **Edge cases?** Trace too short to distill · improvement that helps one case but regresses another (Pareto) · tool already optimal (report "no-op") · conflicting operator corrections.
33. **ROI?** Compounds tool quality over time + converts ad-hoc human↔agent work into reusable assets (forge "asset not cost" principle). Cost: bounded reflect iterations + eval runs.

---

## 8. Shared reference library — `references/agentic-tool-lifecycle.md`

Common to both skills (progressive disclosure, one level deep per AAIF):
- **agentic-tool taxonomy** (skill/agent/subagent/command/MCP-tool/prompt) + per-type discovery path.
- **AAIF frontmatter contract** (name/description rules, ≤500 lines, ≤5000 tokens).
- **Golden-set format** + minimal smoke-set generation.
- **Rubric / scoring scale** (forge KPI extended: Triggering · TaskCompletion · ToolCorrectness · Efficiency · ScopeFit · Regression), 0–5.
- **`--json` / `_agent_feedback` envelope** ([C06] · maos house style).
- **Rovo bridge codegen contract** (§5).
- **DUED sunset triggers** + anti-theater 8Q reference.

---

## 9. Deliverables & Phases

| Phase | Deliverable | Gate |
|---|---|---|
| **P0 (this doc)** | Design spec + 33 Q+A ×2 + ADR | **operator review** ← we are here |
| **P1** | `skills/agentic-tool-evaluator/SKILL.md` + `references/agentic-tool-lifecycle.md` | dogfood self-eval |
| **P2** | `skills/agentic-tool-trainer/SKILL.md` | dogfood train+distill |
| **P3** | Update `skills/skill-writer` cross-ref (creator-extend pointer) + multi-agent-os CHANGELOG + plugin manifest if needed | validate-plugin.sh |
| **P4** | PR on `multi-agent-os` → bot convergence (Copilot/qodo/CodeRabbit) → merge | green PR |
| **P5** | Propagate to `eko-claude-plugins` + `vek-claude-plugins` (sync/copy + their CHANGELOGs) → PRs | green PRs |

**Dogfood gate** (Vek mandate R1/R3): ≥1 real cycle each (evaluator evaluates a real skill; trainer improves/distills a real one) before community promotion.

---

## 10. Success criteria

- [ ] AAIF/agentskills.io valid (name=dir, ≤500 lines, ≤5000 tokens, references one-level-deep)
- [ ] Cross-vendor portable (pure markdown, no Claude-only hardcode) — Cursor/Codex/Gemini/Copilot readable
- [ ] Rovo-bridgeable (§5 codegen contract documented)
- [ ] Zero duplication with skill-writer/forge (composition, not overlap) — DRY proven
- [ ] Eval = behavioral (not theater unit-test); Train = trace→reflect→distill (evidence-backed)
- [ ] gamification/collaboration explicitly deferred to v2 (scope-cut documented)
- [ ] Dogfood pass (self-eval + train-the-weak-skill)
- [ ] 3 repos consistent; all PRs green

---

## 11. Open questions for operator (review gate)

1. **Naming**: confirm `agentic-tool-evaluator` (semantic) vs `agentic-tool-tester` (your word)?
2. **v1 scope-cut**: OK to defer gamification + collaboration/share-results to v2?
3. **Apply-mode autonomy**: trainer mutating a tool → always PR+review (recommended), or allow autonomous propose-only for low-risk?
4. **Propagation depth**: full SKILL.md copy into eko/vek `plugins/multi-agent-os/skills/`, or reference-only per framework-consumption doc?
