# ADR-003: Plugin version SSOT in plugin.json (marketplaces float)

- **Status**: Accepted (⏳ re-validate by **2026-11-26** — 6-month TTL)
- **Date**: 2026-05-26
- **Deciders**: Operator (DevSecOps / AI-eng), via HITL directive

## Context

`maos` (this repo) is distributed via **two** marketplaces — `vek-claude-plugins` and `eko-claude-plugins`. Each pinned a commit `sha` plus a duplicated `version`, which drifted: the two marketplaces pinned **different** SHAs (`fe375bc` vs `be1737b`) and labelled a **stale** version (`1.5.0`) while `plugin.json` was already `1.5.2`. Hand-bumping pins is the friction (agents forget; desync results — cf. `vek-claude-plugins` PR #5). MVP / expansion phase: lean team, agility-critical, no production yet.

Anthropic's plugin-marketplace docs: omit the marketplace `version` and let `source.ref` default to the repo's default branch — the plugin's own `plugin.json` `version` becomes the canonical update discriminator.

## Decision

1. **`.claude-plugin/plugin.json` `version` is the single source of truth** for `maos` releases (currently `1.5.2`), bumped here as part of this repo's release PR.
2. **Both marketplaces float** to this repo's default branch (`source.ref: "main"`, no `sha`, no duplicate `version`) — companion ADRs in `vek-claude-plugins` + `eko-claude-plugins`.
3. Net effect: marketplaces are *set-and-forget*; the SHA divergence auto-resolves (both track `main`).

## Consequences

**Positive**
- One version SSOT (here) → no marketplace follow-up PRs; eliminates the cross-marketplace desync.
- Faster propagation green-PR → user.

**Negative / risks (accepted for MVP, TTL-boxed)**
- Reproducibility loss (users on different commits per refresh); supply-chain blast-radius from `main`.
- **Mitigation**: `main` is PR-gated + branch-protected (`[C18]`); user-side `/plugin marketplace update` + startup auto-update still gate propagation; **re-validate by 2026-11-26**; re-pin on any incident.

## Re-validation trigger (TTL)

| When | Action |
|---|---|
| **2026-11-26** (6 months) | Re-assess float vs re-pin; reconsider once production exists |
| Any supply-chain incident | Re-pin in both marketplaces immediately |

## References

- Anthropic plugin-marketplaces docs (version resolution)
- `vek-claude-plugins` PR #5 (desync prevented) + ADR-001 (companion)
- Companion ADRs: `eko-claude-plugins`, `vek-ai-toolkit`
- `[C12]` Plugin Provenance, `[C14]` External-Repo Integration (conscious MVP deviation, time-boxed)
