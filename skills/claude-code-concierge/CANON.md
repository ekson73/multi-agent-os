# CANON.md — Canonical Claude-Code platform decisions (anchor-mode SSOT)

> **Companion to** `SKILL.md` (claude-code-concierge). This is the `--mode=anchor` source-of-truth.
> **Why repo-local:** a fresh-amnesic agent or new teammate must re-find the binding platform rules instead of re-deriving (or contradicting) them.
> **Vendor-neutral** (MIT / AAIF). **Last verified**: 2026-06-13. Entries dated + sunsettable (DUED, qualitative — anti-drift applies to this file too; the authoritative "how" is always the CURRENT official docs).
> **How `--mode=anchor` uses this:** surface the relevant decision on demand; if a project artifact contradicts a decision here, emit `decision + contradiction + corrective pointer`.

---

## C1 — Official-docs-first (anti-staleness)

The authoritative "how to install/configure/use" is the **CURRENT official docs** — Claude-Code's (`code.claude.com/docs`) AND the tool's own — never training memory. `--mode=research` MUST hit current docs and cite them before recommending a "how".

**Drift flag:** an install/config "how" asserted from memory without a current-docs citation = contradiction (staleness risk).

## C2 — Scope precedence (enterprise > project > user > defaults)

A tool's SCOPE determines visibility + precedence: enterprise/managed overrides project overrides user overrides defaults. Choose the scope by *who must see it*: personal+all-projects → `user`; team-shared+versioned → `project` (committed `.claude/`/`.mcp.json`); just-you-this-repo → `local`; org-mandatory → enterprise/managed.

**Drift flag:** a team-shared tool placed at `user` scope (teammates can't see it), or a personal experiment committed to `project` = contradiction.

## C3 — Source trust-tier before enable

Install FROM the highest-trust source available: official (Claude/Anthropic) > known-maintainer > individual-unverified. An unverified marketplace/plugin requires a provenance note + a pinned SHA + operator gate BEFORE enable.

**Drift flag:** enabling a third-party marketplace/plugin with no provenance/trust-tier check, or floating (un-pinned) an unverified source = contradiction.

## C4 — Secrets never inline

MCP/config secrets (tokens, API keys) go to env vars / 1Password — never committed, never inline in `.mcp.json`/settings that are versioned. Secret handling is HUMAN_DOMAIN (operator ratify).

**Drift flag:** a secret literal in a committed `.mcp.json`/settings file = contradiction (and a leak — escalate immediately).

## C5 — Capability-detect, never fabricate a command

Every command the concierge hands is either capability-detected as present (`command -v` / `claude mcp list` / `claude plugin …`) OR sourced from current docs. An absent surface → "not found" + the documented fallback, never an invented/guessed command.

**Drift flag:** handing a `claude …`/install command without verifying the surface exists (or citing the doc) = contradiction (fabrication risk, anti-theater R4).

## C6 — Guarded operation (install is confirm-gated)

`--mode=install` is the ONLY mutating mode, and it is confirm-gated: research → present exact command + scope/source rationale + provenance note → operator confirm → run → verify → audit line. Irreversible/destructive/secret/cross-org/enterprise-managed changes → escalate, the concierge orients, it does not authorize.

**Drift flag:** an install/config mutation applied without a confirm-gate, or an irreversible change auto-applied = contradiction.

## C7 — Orient, don't reimplement (DRY)

The concierge ROUTES to `claude-code-guide` (Q&A), `find-docs`/Context7/ref-tools (docs muscle), `agentic-tool-forge`+`anima` (creation/naming), the lifecycle skills (preflight/postflight/auto-pilot/morning-briefing/pulse/quiesce/recap), and the sibling concierges (maos/walkthrough/openclaw). It never re-exposes or reimplements them.

**Drift flag:** the concierge answering a deep feature-Q&A itself (instead of routing to `claude-code-guide`), or building/naming a tool itself (instead of `forge`/`anima`) = contradiction (DRY miss).

## C8 — Frontmatter + ISO-8601 + community-clean (layer purity)

This skill (and anything it places) carries frontmatter; dates are ISO-8601; content is MIT/AAIF universal — **no Eko/Vek/corporate-specific content** in this community repo.

**Drift flag:** corporate/operator-personal content leaking into this community skill, a relative date, or missing frontmatter = contradiction.

## C9 — Refs + sunset
- Canonical sources: `code.claude.com/docs` · `docs.claude.com` · `github.com/anthropics/*` · the repo's `README.md`/`AGENTS.md` · `docs/framework-consumption.md`.
- Companion: `AWARENESS-REGISTRY.md` (landscape) · `references/socratic-33q.md` (this concierge's spec).
- **Sunset (DUED, qualitative):** supersede an entry when the official docs change the mechanism (e.g. a new CLI verb, a changed scope model, a new plugin/marketplace primitive), or operator retraction. No counter-based expiry — `--mode=doctor`/`research` re-derives against current docs.
