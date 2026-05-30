# WALKTHROUGH — Creating a pair of lifecycle skills (evaluator + trainer)

> **Dogfood artifact** produced by `agentic-tool-trainer` (mode `distill`) on a real trace: **this session** (operator directive 2026-05-28 → creating `agentic-tool-evaluator` + `agentic-tool-trainer`).
> **Date**: 2026-05-28 · **Trace source**: human↔agent session (Claude Opus 4.8).
> **Purpose**: demonstrate the trainer's `distill` mode end-to-end (trace → WALKTHROUGH → draft hand-off) + serve as a reusable guide for "create N new skills for a framework repo + propagate to consumer plugins".

---

## Goal / Context

Operator asked: *"create new skills (creator/tester/trainer of agentic-tools) for multi-agent-os, propagate to eko/vek-claude-plugins; AAIF + Rovo compatible; 33 socratic questions each."* The task: design + build + register agentic-tool lifecycle skills in a framework repo, gated by review and dogfooding.

## Steps (observed from the trace)

1. **Process-skill first** — invoked `brainstorming` before any creation (HARD-GATE: design before code).
2. **Recon (read-only) BEFORE deciding scope** — located the 3 repos; discovered `skill-writer` + `forge.md` already cover authoring; confirmed NO existing tester/trainer. This flipped the architecture (creator = redundant).
3. **Decision-gate via structured question** — used a calculated `AskUserQuestion` (recommended-option-first) for the 2 genuine forks (architecture · 33Q mode), self-answering the rest (apply-mode, propagation depth) per self-answer-first discipline.
4. **External research via subagent** — kept main context clean; grounded AAIF spec, behavioral-eval methods (promptfoo/DeepEval), reflect-loops (DSPy/GEPA/SIMBA), and the **honest Rovo verdict** (not native — needs Forge bridge).
5. **Worktree isolation** ([C04]) — `feat/agentic-tool-evaluator-trainer`.
6. **Design spec first** (33 Socratic Q+A × 2, ADR, naming, Rovo bridge), committed as a review gate.
7. **Build** — shared `protocols/agentic-tool-lifecycle.md` → 2 SKILL.md (description = "Use when…", name=dir, ≤500 lines).
8. **Register + cross-ref** — README table/categories, CHANGELOG, skill-writer "Related skills" pointer (closes the loop).
9. **Validate** — `validate-plugin.sh` (0/0) + AAIF sanity + gitleaks → commit → push → PR.
10. **Dogfood** — this WALKTHROUGH (distill) + an EVAL-REPORT (evaluator) as evidence before consumer propagation.

## Do

- **Recon for DRY before scoping** — the biggest value-add was discovering authoring already existed (avoided a redundant 3rd skill).
- **Name for accuracy** — `evaluator` over `tester` (behavioral eval ≠ unit-test) prevents downstream theater.
- **Self-answer, ask only genuine forks** — conserved operator attention.
- **Honest scoping** — flag what a tool can't do (Rovo non-native; eval ≠ unit-test) instead of over-claiming.
- **Reuse, don't reinvent** — 33Q structure + KPI from `forge.md`; shared reference for common vocabulary.

## Don't

- Don't jump to file creation on a multi-skill request (use brainstorming + scope-discipline 6Q).
- Don't build a "creator" just because it was literally asked — check what exists first.
- Don't promise "unit/integration tests" for markdown tools (theater).
- Don't ask the operator 66 questions when self-answer + review-artifact serves better.
- Don't propagate to consumer repos before the framework PR converges (rework risk).

## Patterns

- **create → evaluate → train** lifecycle with clean hand-offs (author=skill-writer/forge · evaluate=evaluator · improve/distill=trainer).
- **Shared reference + atomic skills** (Goldilocks) instead of one mega-skill.
- **Design-doc-as-review-gate** before implementation.

## Anti-patterns

- Mega-skill with all 3 capabilities (violates "one skill = one capability").
- Redundant creator (DRY violation vs skill-writer/forge).
- Eval-as-source-assertion instead of behavioral with/without.

## DoR (Definition of Ready)

- Repos located; existing-asset DRY check done; architecture + naming approved; AAIF + Rovo constraints understood.

## DoD (Definition of Done)

- SKILL.md ×2 (name=dir, ≤500 lines, description="Use when…") + shared reference; README/CHANGELOG/cross-ref updated; `validate-plugin.sh` 0/0; gitleaks clean; PR open; ≥1 dogfood cycle each.

## Acceptance criteria

- [x] DRY proven (no redundant creator) · [x] AAIF valid · [x] anti-theater framing · [x] PR open · [ ] bot convergence · [ ] consumer propagation.

---

→ **DRAFT hand-off**: this WALKTHROUGH could itself become a reusable skill `creating-framework-skills` (create-N-skills-for-a-repo-and-propagate). **DRY check first** — overlaps `skill-writer` (authoring) + this lifecycle; likely a *recipe/reference*, not a new skill. Escalate to operator before authoring (forge anti-pattern: don't create disposable/overlapping tools).
