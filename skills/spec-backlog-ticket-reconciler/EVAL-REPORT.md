# EVAL-REPORT — spec-backlog-ticket-reconciler (skill) — 2026-09-29

- Target: MAOS PR #466, head `62406af`, skill version 0.1.0; model/agent auto-trigger or scoped `maos:spec-backlog-ticket-reconciler`, not a human slash command.
- Baseline: none. Golden cases: 4-case smoke-set (one positive scenario exercised twice, three negative/boundary cases specified but not host-executed). Confidence: low. No with/without-tool control and no regression comparison.
- Scope: read-only evaluation of a synthetic repository scenario; no live tracker inventory or issue writes. The observed host run itself was **not** side-effect-free.

## Scores and evidence

Scores are provisional observations, not an aggregate qualification. `N/O` means not observed; ScopeFit uses −2..+2 (0 = appropriate). Trigger score is capped because the trace does not show a `Skill` invocation.

| Case / input → expected behavior | Host evidence | Trigger 0–5 | TaskCompl 0–5 | ToolCorr 0–5 | Effic 0–5 | ScopeFit −2..+2 | Regression |
|---|---|---:|---:|---:|---:|---:|---|
| Positive: synthetic OpenSpec pending outcome + local backlog; request spec-to-issue reconciliation → discover skill, distinguish source status, inventory open/closed tracker issues, plan only when inventory unavailable | **Executed twice with plugin directory.** First JSON-output run identified the skill and plan-only steps in final answer, but no tool trace was retained. Second Haiku stream-JSON run identified `maos:spec-backlog-ticket-reconciler`, reported reading `SKILL.md` and issue-body template, enumerated open/closed inventory requirements, and held create/update because GitHub inventory was incomplete. Actual trace: assistant (no tool) → Glob → Read → Read → Write → assistant → result; **no `Skill` tool invocation shown**. No network issue operation observed. | 2 | 2 | 2 | 1 | 0 | N/O |
| Accepted spec with authoritative pending implementation and an existing matching ticket → retain accepted spec as contract, update/no-op rather than skip or duplicate | **Not host-executed**; static expectation from skill procedure only. | N/O | N/O | N/O | N/O | 0 (static only) | N/O |
| Ambiguous authority or incomplete destination inventory → review/HOLD all affected creates and updates | **Not separately host-executed**; positive run did show an incomplete GitHub inventory HOLD, but did not test ambiguous authority or a complete-inventory comparison. | N/O | N/O | N/O | N/O | 0 (static only) | N/O |
| Irrelevant request unrelated to specs/backlog/tickets → do not trigger | **Not host-executed**; false-positive triggering unknown. | N/O | N/O | N/O | N/O | 0 (static only) | N/O |

## Verdict: FLAG — not qualified / no PASS

The positive output is compatible with skill guidance, but attribution to the skill cannot be established: the host may have inferred the workflow from the prompt or plugin context, and there is no without-tool control. Reading a skill file and naming its scoped identifier are **not** proof that the host invoked the `Skill` tool. Checklist items 9–10 (relevant-query activation and correct following) remain unproven end-to-end. The positive run did not complete a real issue inventory, so correct reconciliation and write gates are also unproven. Negative-trigger behavior and accepted-pending handling remain static expectations, not behavioral successes. No regression verdict is possible without a baseline.

**Plan-mode side effect:** despite a synthetic prompt requesting no writes or network, the second host trace included a `Write` invocation, and Claude plan mode wrote a generated plan under `~/.claude/plans/`. The generated synthetic plan file was read and removed after the run. This was not a tracker write, but it invalidates a claim of strict no-write behavior. Whether the write arose from the host's plan-mode harness rather than this skill is unresolved; neither host nor skill is exonerated or blamed by this trace alone. The first JSON-output run took 52.6 seconds and cost $6.34 in API usage; the second used Haiku with empty setting sources and stream-JSON, but no measured time/cost is asserted here.

## Qualification next action

Run a safe, isolated host evaluation with plugin enabled and an otherwise identical **without-skill control**, disabling plan-mode file writes or sandboxing and verifying filesystem effects. Exercise the positive case and at least one irrelevant negative trigger, plus the accepted-pending and ambiguous/incomplete-inventory boundaries; capture actual tool events, output and side effects. Only after a real observed end-to-end dogfood cycle should `dogfood_status` change from `pending-first-cycle`. This report does not change the skill, template, changelog, or dogfood metadata.
