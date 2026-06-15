# Open Design — Canonical Decisions (anchor SSOT)

> Payload for `opendesign-concierge` "audit/anchor" mode. The decisions that drift across sessions — anchor here. Verified 2026-06-15.

| # | Canon | Rationale |
|---|---|---|
| C1 | **BYOK — no local LLM.** Open Design uses the host agent's own model. AMR is optional/paid. | Matches the operator's "no local LLM (resource cost)" constraint; never claim a local model is needed. |
| C2 | **Don't reinstall / re-clone.** Canonical clone is `~/.claude/plugins/marketplaces/open-design/` (origin `nexu-io/open-design`). | DRY; re-cloning a 65k⭐ monorepo is waste + [C15] marketplace-hygiene. |
| C3 | **`DESIGN.md` is the brand contract.** Apply via `var(--token)`, never raw hex. | USAGE.md "Avoid"; raw hex breaks cross-brand switching. |
| C4 | **Tier A (assets-direct) is the default.** Reach for Tier B (Docker daemon + od-code-migration) only when migrating an EXISTING repo to a PR. | Anti-over-engineering (Gordian): don't spin a daemon when pasting tokens suffices. |
| C5 | **Install via Docker, not source-build**, on this machine. | Local node 22 / pnpm 10.28 ≠ repo's required 24 / 10.33; `deploy/scripts/install.sh` (Docker) avoids the version fight. |
| C6 | **MCP snippet is Settings-auto-generated** (stdio/local install). | Don't hand-fabricate `~/.claude.json`; run `od mcp install claude`. |
| C7 | **Cloudflare preview needs an account-owned token** (1Password, HUMAN_DOMAIN). | Per the operator's CI-token rule (account-owned `cfat_`, survives offboarding). |
| C8 | **1 concierge tool, not 2.** `opendesign-helper` is a DUED future split only if the do-runbooks outgrow this concierge. | DRY — the "guide" mode already delivers the helper function; a 2nd skill would duplicate ~70% of the knowledge-pack. |

## Drift checks (audit mode)
- Clone present + origin == `nexu-io/open-design`? · DS catalog count ≈152? · `od` knowledge-pack still matches the live CLI? · wrangler still on PATH? · POC still at `~/Projects/vek-list-poc-opendesign-airbnb-design-system/`?
