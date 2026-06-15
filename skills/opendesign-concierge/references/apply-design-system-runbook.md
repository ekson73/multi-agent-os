# Apply a Design System with Open Design — Runbook (2 tiers)

> Payload for `opendesign-concierge` "guide" mode. Worked example = Airbnb → vek-list POC.

## Choose the tier
- **Tier A — assets-direct** (KISS default): you have a NEW artifact/prototype/page and want the brand look. Zero build, zero Docker. Use the DS package files directly.
- **Tier B — daemon + od-code-migration** (agentic): you have an EXISTING repo and want it repaginated to a brand as a PR. Needs Docker + the repo. Heavier.

## Tier A — assets-direct (recommended start)
Read-order (from the DS package `USAGE.md`):
1. `USAGE.md` (package contract) → 2. `DESIGN.md` (visual intent + anti-patterns) → 3. `tokens.css` → 4. `components.manifest.json` (compact inventory) → 5. `components.html` (exact selectors/states) → 6. `preview/` (sanity check).

Steps:
1. Copy / link the DS package from `~/.claude/plugins/marketplaces/open-design/design-systems/<slug>/` into your project (Apache-2.0 bundled-fixture — copy keeps the project self-contained).
2. `<link rel="stylesheet" href="design-system/tokens.css">` **first** (defines the `:root{}` vars).
3. Write component CSS using **only `var(--token)`** — never raw hex (USAGE.md "Avoid"; raw hex breaks cross-brand switching).
4. Reuse component recipes from `components.manifest.json`/`components.html` before inventing controls.
5. Validate: every `var(--x)` you use resolves to a declaration in `tokens.css` (catch token typos).

### Worked example — Airbnb → vek-list (this session, 2026-06-15)
- POC scaffold: `~/Projects/vek-list-poc-opendesign-airbnb-design-system/` (DS embedded in `design-system/`, render proof `src/index.html`, **34/34 tokens validated** against `tokens.css`).
- Key Airbnb tokens: `--accent #ff385c` (Rausch — primary CTA/search/active only), `--fg #222`, `--surface-warm #f7f7f7`, `--border #ddd`, `--radius-md 14px`/`--radius-lg 20px`/`--radius-pill`, `--font-body` (Airbnb Cereal VF — **proprietary, NOT bundled** → falls back to system stack; honest: token-faithful, font-approximate).
- Method demonstrated: top-nav + `search-pill` + category tabs + a listings card grid (the vek-list analog) — all from token vars + documented recipes.

## Tier B — daemon + od-code-migration (agentic PR)
1. Install the daemon (Docker, no node build): `cd ~/.claude/plugins/marketplaces/open-design && bash deploy/scripts/install.sh`.
2. (optional) wire the host agent: `od mcp install claude`.
3. Run the migration: `od plugin apply od-code-migration --input repo=<path-to-repo> --input brand=<slug>` → produces a PR refreshing the repo to the brand spec.
4. Review the PR via the normal pr-review convergence (CodeRabbit/Amazon Q/Qodo).

## Deploy a dev-preview (Cloudflare Pages) — gated
- `wrangler` 4.x ready (`which wrangler`). Deploy: `wrangler pages deploy ./src --project-name <name>`.
- ⚠️ **Gate**: needs a Cloudflare **account-owned** token (`cfat_`, Super-Admin-created — survives offboarding) stored in 1Password. Token = HUMAN_DOMAIN (operator provides). wrangler is unauthenticated until then.

## Gates summary (when the real work is blocked)
- **Existing-repo repagination** → needs the target repo locally (e.g. `vek-list`/poc-reveng vs `vkl-rct-list-web`).
- **Preview deploy** → account-owned Cloudflare token (1Password).
- **Spec-driven legs** (design→spec→prototype→src) → OpenSpec + Spec-Kit `specify` (already installed). Tracker: VKS-2204.
