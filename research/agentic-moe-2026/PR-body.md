# feat(maos-hub): additive gating-seam + goal-loop closure (Loop 1–4)

> **PR-as-Documentation-Prompt** · base `main` · landing via worktree (C04) · gates C07 · merge = HITL.
> Consumed by `gh pr create --body-file`. Authored by Claude (Cowork); landed Mac-side by Claude Code / operator.

## Summary

Adds the **gating-seam** to the MAOS Hub gateway (the "teeth" the OODA-RECON/critical-analysis found
missing) — **additive and reversible**: `policy=None` ⇒ passthrough ⇒ **zero behaviour change** across
all 96 gateway actions. Plus the goal-loop research/decision trail (Loops 1–4) and the ADR-007 demotion.

This is the **WAVE-0 atomic core** of ADR-006 (MAOS Hub). It does **not** activate ADR-007 (platform
identity stays Draft-frozen) and does **not** ratify ADR-006 (that remains an operator HITL act).

## What changed

**Build — the gating-seam (`mcp-tools/maos-mcp-hub/lib/gateway/`)**
- `policy.py` *(new)* — `PolicyResolver` (dumb in-memory) + `PolicyDecision` + `load_conflicts()`. Default **allow-all** when no profile set.
- `conflicts.yaml` *(new)* — **16 curated structural incompatibility edges** from `20260627-02-ntree-moe.md` (ECC×base, spec-kit×openspec, gstack×ECC-browser-mcp, mem0×letta×cognee, …).
- `router.py` *(+33/−1)* — one pre-dispatch check after `operation` validation; on deny → structured error in the **existing `_agent_feedback` envelope**. Discovery levels 0–2 untouched. `policy=None` ⇒ passthrough.
- `tests/test_gateway_policy.py` *(new)* — **16 tests**: passthrough/0-regression + gating (handler-not-invoked via call-spy) + conflicts-load.

**Docs — goal-loop trail (`research/agentic-moe-2026/`)**
- `20260628-critical-analysis.md`, `20260628-solutions-debate.md`, `20260628-goal-loop-closure.md` (Loops 1–4), `20260629-demand-probe-post.md` (the R2 munition).
- `20260627-notebooklm-{exec,source-digest,tech}-prompt.md` — updated for the native-MAOS framing.

**Decision — `docs/adrs/ADR-007-…md`** demoted **North Star → Exploratory/Draft (frozen)** (SDP-stamped; reversible).

## Test evidence (0-regression — the merge gate)

- `test_gateway_router.py` + `test_gateway_feedback.py`: **24/24 PASS**
- `test_gateway_policy.py` *(new)*: **16/16 PASS**
- Full suite: **192 pass** / 3 pre-existing fails (inventory count-drift, **seam-independent — identical on pristine HEAD**)
- `bash tests/validate-plugin.sh`: **PASSED** (0 errors, 1 warning)
- `G1 ("real teeth") = TRUE` — call-spy proves the handler is **not invoked** on either deny path (disabled + conflict).

## Governance compliance

- **[C04]** landed from a **worktree** (not the root checkout — the v1 script was corrected after the 2026-06-28 lock incident).
- **[C07]** explicit stage (never `git add -A`); `gitleaks` + `openspec validate --specs` + `validate-plugin.sh` green **Mac-side** before commit; Conventional Commits + `Co-Authored-By`.
- **Merge = HITL** (ADR-004 GitHub Flow, `--squash --delete-branch`). **ADR-006 stays Proposed** until operator ratifies.
- Snyk `ERROR` ≠ finding (app-auth/infra); CodeRabbit `PENDING` (Free) ≠ blocker. Real convergence = Amazon Q + CI green.

## Residuals (NOT in this PR — carry-forward)

- **R2 — demand pull-signal** (HARD carve-out): run `20260629-demand-probe-post.md` from the operator's accounts; measure 2 weeks against the pre-registered kill-criterion. Decides ADR-007's fate; **ADR-006 stands regardless**.
- **R4 — supply-chain floor** (HARD/admin): flip Trivy `exit-code:1` + `gate_on:vuln,secret` + branch-protection `required` (needs repo-admin + a dry-run first).

## Reviewer checklist

- [ ] Confirm `policy=None` passthrough = 0 behaviour change (run the suite).
- [ ] Confirm the 16 `conflicts.yaml` edges trace to `02-ntree-moe.md`.
- [ ] Confirm ADR-006/007 remain **Proposed/Draft** (this PR records, does not activate).

---
*Loop 1→ESCALATE(0.75) · Loop 2 BUILD→0.87 · Loop 3 DEMAND→bifurcated(prior 0.68, pull HARD) · Loop 4 v3-canonical→agent-doable 0.79 / full-goal 0.71 (binding=certainty, HARD-capped). DEFER-at-n* on the carve-outs; the rest is closed.*
