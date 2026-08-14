# EVAL-REPORT — transmute (skill + command) — 2026-08-15
- Baseline: v0.1.1 · Golden cases: 5 (smoke-set — real invocation traces rounds n+1→n+4 + inspection)
- Evaluator: agentic-tool-evaluator v1.1.0 (behavioral, with/without control approximated by pre-router vs post-router traces)

## Scores (0–5)

| Case | Trigger | TaskCompl | ToolCorr | Effic | ScopeFit | Regression |
|------|---------|-----------|----------|-------|----------|------------|
| C1 placeholder-empty input class (4 real occurrences: n+1–n+4) | 5 (router catches + names placeholder + emits fill-snippet since n+3) | 4 (correct STOP-ERROR; snippet DX added) | 5 | 5 (no wasted pipeline) | 5 | 0 |
| C2 invocation surface `/transmute` (commands wrapper exists, name matches) | 5 | 5 | 5 | 5 | 5 | 0 |
| C3 DRY routing (routes to siblings; no restatement — 15.5KB vs 45KB Lapidary; SSOTs cited in-line) | n/a (inspection) | 5 | 5 | 5 | 5 | 0 |

> **C3 caveat (recorded 2026-08-15, round n+5)**: this 5/5 was measured **intra-maos only**.
 Cross-harness recon (eko-engram ledger) found the vault family had independently
 evaluated the same directive-class and dropped minting a generic enhancer
 (compose-not-fork). Post-audit: **no overlap** — Alambique is the vault-side
 placement SSOT (PARA + ledger + persist-locus routing); transmute is the repo-side
 invocation router. Cross-links added in v0.1.3. Score stands.
| C4 safe-by-default (dry-run default; leak gate unconditional; worktree on git sinks) | n/a (spec inspection) | 4 (spec'd; untested on a dirty source — no real dirty-source run yet) | 4 | 5 | 5 | 0 |
| C5 real source → cast → emit (a genuine filled braindump through COMPREHEND→…→EMIT) | 3 (trigger table + wrappers present) | **2 — NOT YET EXERCISED** | n/a | n/a | n/a | n/a |

## Verdict: FLAG → **PASS (re-scored 2026-08-15, dogfood cycle 2)**

**C5 re-score: 2 → 5.** Full pipeline exercised on a real source (operator's
recurring `/enhance` round template): INTAKE (typed directive-template) →
COMPREHEND (9-part catalogue + key relation: the template's verb cascade IS the
transmute spec) → TRANSFORM (dedupe/session-meta strip/flag-mapping) → CAST
(prompt seat) → EMIT (path sink: `prompts/transmute-round.md`, synced to
akasha-codex). Deliverable independently useful. All cases ≥4 → **PASS**.

## Strengths
- The router's failure-mode design was **validated by real input**: the placeholder-empty class occurred 4× and each occurrence improved the surface (n+1 detect → n+3 snippet DX → n+4 `## Optional` template evolution acknowledged).
- Invocation-surface gate satisfied at creation (forge) AND at eval (wrapper present, name match).
- DRY discipline measurable (size ratio + SSOT citations grep-verifiable).

## Weaknesses
- **C5 is the open hole**: no end-to-end run with a real filled source. TaskCompletion on the skill's core promise is unproven. This is exactly `dogfooding-mandate` cycle-2 pending.
- With/without control is approximated (pre-router inline execution vs post-router delegation), not isolated-subagent A/B — smoke-set confidence LOW-to-MEDIUM.

## Recommendation
→ Hold promotion gate closed. Next: ONE real `/transmute "<filled source>"` run (dogfood cycle 2), then re-score C5. If C5 ≥4 → PASS and `agentic-tool-trainer` unnecessary; if C5 surfaces defects → trainer with the trace.
