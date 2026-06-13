# AWARENESS-REGISTRY.md — Claude-Code platform landscape (the concierge payload)

> **Companion to** `SKILL.md` (claude-code-concierge). This is the `--mode=explain` + `--mode=guide` + `--mode=research` lookup table.
> **Vendor-neutral** (MIT / AAIF cross-vendor). **Last verified**: 2026-06-13.
> **Convention**: this registry is *referenced*, not duplicated, by callers. Counts/paths are point-in-time — `--mode=doctor --health-check` re-derives from the live config and flags drift. The authoritative "how" is ALWAYS the current official docs (`--mode=research`), not this table — this orients; docs decide.

---

## Tier ladder (how to think about the platform)

```
Tier 0  The interaction surface  → the `claude` CLI · IDE/desktop/web hosts · sessions · context · memory
Tier 1  Agentic-tool TYPES       → MCP server · skill · command · agent/subagent · plugin · marketplace · hook · rule
Tier 2  The SCOPE model          → enterprise/managed > project > user > defaults (precedence)
Tier 3  The SOURCE model         → direct · plugin · marketplace · official (Claude/Anthropic)
Tier 4  Official knowledge        → code.claude.com/docs · docs.claude.com · anthropics/* · each tool's own docs
Tier 5  Lifecycle family         → preflight · postflight · auto-pilot · morning-briefing · pulse · auto-orchestrator · recap
Tier 6  Genesis pair             → agentic-tool-forge (+ anima naming) → agentic-tool-evaluator → agentic-tool-trainer
Tier 7  Sibling concierges       → maos-concierge · walkthrough-concierge · openclaw-concierge (route for THEIR domains)
```

## The agentic-tool TYPES (what can be installed/configured)

| Type | What it is | Lives at (typical) | Official mechanism |
|---|---|---|---|
| **MCP server** | external tools/resources via Model Context Protocol | user/project settings · `.mcp.json` | `claude mcp add` (`-s user|project|local`) |
| **skill** | a `SKILL.md` capability auto-loaded by description | `<scope>/skills/<name>/SKILL.md` | direct file · or via a plugin |
| **command** | a `/slash` command (markdown) | `<scope>/commands/<name>.md` | direct file · or via a plugin |
| **agent / subagent** | a delegatable specialized agent | `<scope>/agents/<name>.md` | direct file · or via a plugin |
| **plugin** | a bundle (skills+commands+agents+hooks+MCP) | installed from a marketplace | `claude plugin install` |
| **marketplace** | a catalog of plugins | registered source | `claude plugin marketplace add` |
| **hook** | lifecycle event handler (PreToolUse/Stop/…) | `<scope>/hooks/` + settings | direct file + settings wiring |
| **rule** | auto-loaded guidance (`~/.claude/rules/*.md`) | user/project | direct file (auto-load) |

## The SCOPE model (where a tool should live — precedence)

```
enterprise/managed  (organizationInstructions, managed settings)   ← highest precedence
        ▲
   project           (<repo>/.claude/, .mcp.json — committed, team-shared)
        ▲
   user              (~/.claude/ — personal, all your projects)
        ▲
   local             (settings.local.json, project-local, gitignored — just you, this repo)
        ▲
   defaults                                                          ← lowest precedence
```

| Scope | Use when | Visible to | Gotcha |
|---|---|---|---|
| **user** | personal tool, all your projects | only you, everywhere | a teammate WON'T see it (don't use for team-shared) |
| **project** | team-shared, versioned | everyone who clones the repo | commit `.claude/`/`.mcp.json`; secrets stay OUT |
| **local** | just you, just this repo, experimental | only you, this repo | gitignored; not portable |
| **enterprise/managed** | org policy, mandatory | everyone under the policy | operator/admin domain (HUMAN_DOMAIN) |

## The SOURCE model (where to install FROM — trust ladder)

```
official  (Claude / Anthropic marketplaces · anthropics/*)   ← highest trust
   ▲
known     (well-known maintainer, verified repo)
   ▲
plugin/marketplace (third-party — TRUST-TIER + pin a SHA before enable)
   ▲
direct    (you author/place the file yourself)               ← you own the trust
```

**Trust-tier rule** (provenance): official > known-maintainer > individual-unverified. For an unverified marketplace/plugin → provenance note + pin a SHA + operator gate before enable.

## Official surfaces (where `--mode=research` looks)

| Surface | URL / locus | For |
|---|---|---|
| **Claude-Code docs** | `code.claude.com/docs` | the authoritative how for skills/MCP/plugins/marketplaces/hooks/settings/CLI |
| **Claude/Anthropic docs** | `docs.claude.com` · `docs.anthropic.com` | Agent SDK · API · models |
| **Official repos** | `github.com/anthropics/*` | reference implementations, official plugins |
| **A tool's own docs** | its repo README / docs site (via `find-docs`/Context7/ref-tools) | the tool-specific install/config |
| **`claude-code-guide`** | the Q&A agent (route, don't duplicate) | "how does feature X work" |

## Lifecycle family (cross-ref — never reimplemented; the concierge ROUTES here)

| Tool | When the concierge routes to it |
|---|---|
| `preflight` | session/workspace orient + heal + isolate BEFORE work |
| `postflight` | end-of-session sweep + debrief + handoff |
| `morning-briefing` | cold-start state recap · `--dashboard`/`--next-actions` lean on it |
| `pulse` | mid-session re-orient · `--next-actions` |
| `auto-pilot` | drive a goal end-to-end across sub-agents |
| `auto-orchestrator` | autonomous multi-phase backlog work |
| `quiesce` | drive the session to a clean/green/converged steady state |
| `recap` | end-of-session recap |

## Genesis pair (cross-ref — the concierge ROUTES here for CREATION)

| Tool | When |
|---|---|
| `agentic-tool-forge` | "turn this into a tool" / "build me a skill" — research-first DRY genesis |
| `anima` | name a new tool/anything (the forge delegates here) |
| `agentic-tool-evaluator` | "is this tool any good / does it trigger" |
| `agentic-tool-trainer` | "improve/tune this tool from eval results" |

## Sibling concierges (route for THEIR domain — DRY)

| Concierge | Scopes |
|---|---|
| `maos-concierge` | the MAOS framework (agents/skills/commands/protocols/governances) |
| `walkthrough-concierge` | ASH (Agentic Session Harness — journals/decisions/drift) |
| `openclaw-concierge` | OpenClaw (multi-channel personal-AI gateway, MIT) |
| **`claude-code-concierge`** (this) | the **Claude-Code platform itself** (install/scope/source/docs-research) |

## Core concepts (vocabulary the concierge teaches)

- **Scope precedence** — enterprise > project > user > defaults; a higher scope overrides a lower one.
- **Source trust-tier** — official > known > individual; trust-tier a marketplace/plugin BEFORE enable.
- **Official-docs-first** — never answer install/config "how" from memory; hit the CURRENT official docs.
- **Capability-detect, never fabricate** — every command is verified-present or doc-sourced.
- **Secrets never inline** — MCP/config secrets to env/1Password, never committed.
- **Orient, don't reimplement** — the concierge routes to `claude-code-guide`/`find-docs`/`forge`/lifecycle; it never re-exposes them.

## What to SKIP (anti-bloat — the concierge tells you what NOT to reach for)

- Don't user-scope a team-shared tool (teammates won't see it) → use project scope.
- Don't answer "how do I configure X" from memory → `--mode=research` the current docs.
- Don't enable an unverified marketplace without a provenance/trust-tier check → pin a SHA + operator gate.
- Don't ask the concierge to *build* a tool → route to `agentic-tool-forge`.
- Don't ask the concierge a deep "how does feature X work internally" → route to `claude-code-guide`.
- Don't inline a secret into a committed `.mcp.json`/settings → env/1Password.

## Refs

- Official: `code.claude.com/docs` · `docs.claude.com` · `github.com/anthropics/*`
- Companions: `CANON.md` (canonical decisions) · `references/socratic-33q.md` (this concierge's spec) · `dashboard.html`
- Sibling registries: `maos-concierge/AWARENESS-REGISTRY.md`
