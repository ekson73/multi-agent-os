# ADR-004: GitHub Flow branching model (Class B — library/marketplace)

- **Status**: Accepted
- **Date**: 2026-05-26
- **Deciders**: Operator (DevSecOps / AI-eng), via HITL directive
- **Scope**: This repo (Class B: **consumed, not deployed**). **Companion to ADR-003** (`version-ssot-float`): ADR-003 governs how *consumers* pin sources; **this ADR governs how *maintainers/agents* branch.**

## Context

Vek repos split into two classes:

- **Class A — apps that DEPLOY** (`vek-sales`, `vek-list`, new ai-driven apps): GitLab-Flow-Lite + environment branches (`main` / `homolog` / `prod`) + canary ring.
- **Class B — libraries/marketplaces that are CONSUMED** (this repo): there is **no environment to deploy to**, so environment branches are meaningless.

This repo already had branch-naming (`CLAUDE.md`) and a PR/merge workflow (`CONTRIBUTING.md`), but **no NAMED branching model in the agent-facing SSOT (`AGENTS.md`)** — causing ambiguity for humans and agents moving across repos.

## Decision

Adopt **GitHub Flow + SemVer** for this Class-B repo:

1. Single trunk `main`, always releasable.
2. Short-lived `feature/<id>-slug` · `fix/<id>-slug` · `hotfix/<id>-slug` · `docs/` · `chore/` branches → PR → **squash-merge** → **delete branch**.
3. **No environment branches** (`homolog`/`ppe`/`prd` do not exist here — they belong to Class A deployed apps only).
4. **Versioning + consumer source-pin are governed by the companion ADR-003 (float, version SSOT in `plugin.json`, TTL'd)** — explicitly **not** re-decided here.
5. Agents MUST: never commit to `main` directly · always open a PR · never create env-branches here · treat tagging/release as a human/operator gate.
6. Because PRs are squash-merged, a version delta MUST use a separate, rebased, linear PR titled `chore(release): ...`. The release artifact is the PR-level net delta that survives on `main`: only the monotonic `plugin.json` version field plus one matching additive changelog section. README/CLAUDE versions are derived post-merge; feature code and release metadata do not share a PR. The gate runs from trusted base code and treats the head only as Git data.

## Consequences

- **Positive**: one named model across all Class-B repos → zero human/agent confusion; `AGENTS.md` becomes the discoverable SSOT.
- **Negative (mitigated)**: one more ADR to maintain — kept short and as a *companion* that references ADR-003 rather than duplicating it.
- **Negative (mitigated)**: releases require a small follow-up PR after feature convergence; deterministic CI checks protect trunk provenance and keep the final squash event auditable.

## References

- **Companion**: `ADR-003-version-ssot-float.md` (source/version strategy) + Jira ticket
- `AGENTS.md` §"Branching & Release Model"
- Class A counterpart: `vek-sales` / `vek-list` GitLab-Flow-Lite (deployed apps)
