# EVAL-REPORT — eisenhower-matrix (skill+command) — 2026-08-18

- Baseline: v0.1.1 (spec-only, PR #367) vs **v0.3.0** (executable, PR #371) · Golden cases: **6 (smoke-set, low-confidence flagged per evaluator contract)** — all cases RAN for real against the executable surface (`bin/work-compass-aggregate.py`), no fabricated traces.
- Control: structural WITHOUT — a baseline agent has no known mapping (skill params → `--pendency-scope`/`--sort` CLI) nor the reap-route contract; WITH = the skill-induced mapping executed. (True A/B with live LLM sub-agents not run — flagged; the CLI evidence is deterministic, so the behavioral delta is measured at the tool's terminal surface.)

## Cases (all REAL runs, read-only)

| # | Case | Method | Result |
|---|---|---|---|
| C1 | Canonical ask `pendencias --scope=current --sort=Eisenhower` → quadrants envelope | `--sort=Eisenhower --pendency-scope=current --include=pending --json` | rc=0, quadrants Q1–Q4 + next_action present ✅ |
| C2 | Scope mapping: `--scope=session` → session-family ids only | `--pendency-scope=session --json` | all ids ∈ {session, codex-session, job, plan} prefixes ✅ |
| C3 | Contract case-insensitivity (`Eisenhower` capitalized per skill contract) | `--sort=Eisenhower` + `--sort=eisenhower` | both rc=0 ✅ |
| C4 | Q4 Eliminate loop: stale/orphaned session → reap dry-run, never executes | `--route <real Q4 session>` | `tool=reap-sessions`, `execute:false`, `--apply only after review` ✅ |
| C5 | vault degrade: honest `unavailable`, never fabricated | `--pendency-scope=vault --json` | count=0 + `vault:` diag ✅ |
| C6 | Backward compat: default invocation unchanged (N-Tree) | no flags | byte-shape N-Tree render ✅ |

## Scores (0–5)

| Case | Trigger | TaskCompl | ToolCorr | Effic | ScopeFit | Regression |
|------|---------|-----------|----------|-------|----------|------------|
| C1 | 5 | 5 | 5 | 4 | 0 | 5 |
| C2 | 5 | 5 | 5 | 5 | 0 | 5 |
| C3 | 5 | 5 | 5 | 5 | 0 | 5 |
| C4 | 5 | 5 | 5 | 5 | 0 | 5 |
| C5 | 5 | 5 | 5 | 5 | 0 | 5 |
| C6 | 5 | 5 | 5 | 5 | 0 | 5 |

- **Triggering 5** — structural: trigger-rich `description` (pendencias/eisenhower/pending queue/triple-A queue/AAA pendency) + `commands/eisenhower-matrix.md` wrapper present (invocation-surface gate satisfied — `/slash` fires) + "Not use" cases documented. LLM-trigger *precision* unmeasured without live A/B (flagged, low-confidence).
- **Efficiency 4** — collectors fan out sequentially (timeouts bound the worst case); a landscape scan is seconds-scale, acceptable, but parallelism is the obvious future optimization (not a defect).
- **ScopeFit 0 (perfect)** — thin classifier + alias over work-compass SSOT; composes, reimplements nothing.
- **Regression 5 (none)** — vs v0.1.1 baseline (spec-only): strictly better (v0.2.0 made it executable; v0.3.0 wired Q4 + documented Q3 signal-starvation honestly). Default work-compass path byte-identical (C6, test-enforced).

## Verdict: **PASS** (flags noted)

## Strengths

- Executable + honest: every claim in the SKILL maps to running code + 97 stdlib tests.
- Anti-theater by construction: Q3 signal-starvation documented instead of masked (v0.3.0); vault degrades honestly (C5); read-only contract (C4).
- Dogfood evidence structured: `dogfood-tally eisenhower-matrix` = 3 COMPLETE / ELIGIBLE.
- Triple-AAA rows: probe-backed source + quadrant + disposition per row.

## Weaknesses (→ trainer, optional)

1. Efficiency: sequential collector fan-out (parallelize).
2. Triggering precision: no live LLM A/B golden-run (20–50 curated cases remain the CI-grade target — smoke-set was 6).
3. C4 depends on live data containing a stale Q4 row (vacuous-case guard needed if corpus dries up).

## Recommendation

**Promote `lifecycle-stage: forge → operate`.** Evaluate=PASS, no FAILs → training not required. The two remaining promotion inputs are already satisfied: dogfood ≥2 ratified cycles (ledger: 3/ELIGIBLE) and behavioral eval PASS (this report). Optional trainer handoff for the 3 weaknesses above — none blocking.

---
*Evaluator: `agentic-tool-evaluator` v1.1.0 method · rubric `protocols/agentic-tool-lifecycle.md` §4 · gitleaks/PII: report contains no secrets or PII.*
