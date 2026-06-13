---
name: claude-code-concierge
description: Front-desk concierge for the Claude-Code platform itself — onboard · route an intent to the best scope+source · research the OFFICIAL+CURRENT docs (Claude-Code's AND the tool's) before acting · render a control-panel dashboard · health-check/self-test · guarded install of MCP/plugin/marketplace. Thin wrapper over the `claude-code-concierge` skill (soul-name Cicerone). Routes to claude-code-guide/find-docs/agentic-tool-forge/lifecycle/sibling-concierges — reimplements nothing.
argument-hint: "[intent] | [--mode explain|onboard|guide|research|install|dashboard|doctor|anchor] [--help] [--onboard] [--research-tools <tool|intent>] [--dashboard[=sessions|context|memory|status|mcps|plugins|marketplaces|worktrees|tasks]] [--sessions] [--context] [--worktrees] [--tasks] [--next-actions] [--install-mcp <name>] [--install-plugin <name>] [--install-marketplace <src>] [--self-test] [--health-check] [--format n-tree|json|scorecard|continuity|md]"
allowed-tools: [Read, Glob, Grep, Bash, WebFetch, WebSearch, Skill, Task]
---

# /claude-code-concierge

Invoke the **`claude-code-concierge`** skill (Claude Code: `Skill` tool with `skill: "claude-code-concierge"`; other hosts: the equivalent skill-activation mechanism), passing the arguments below.

**Arguments**: `$ARGUMENTS`

## Parsing
- Empty `$ARGUMENTS` OR `--help` → run `--mode=explain` focused on the flag/feature surface (usage); do NOT guess an intent.
- A `--mode=<…>` flag → run that mode.
- A flag-alias maps to its mode: `--onboard`→onboard · `--research-tools`→research · `--install-mcp|--install-plugin|--install-marketplace`→install · `--dashboard|--sessions|--context|--worktrees|--tasks|--next-actions`→dashboard · `--self-test|--health-check`→doctor.
- A bare intent string → `--mode=guide` over that intent (default).
- `--format=<n-tree|json|scorecard|continuity|md>` applies across modes (default `md`); `--json` ⇒ machine envelope for agent-to-agent use.

## What it does (skill — 8 modes)
`explain` (teach the platform: scopes·sources·tool-types·official-surfaces·family + what to SKIP) · `onboard` (guided ramp: research→scope→source→install→verify) · `guide` (intent → best scope + best source + exact capability-detected command + governing rule + cited official-doc) · **`research`** (the core: fetch OFFICIAL+CURRENT Claude-Code docs AND the tool's own docs → reconcile → recommend scope+source+steps, cited — never from memory) · `install` (**guarded**: research→present command+rationale+provenance→confirm-gate→run→verify→audit-line; never fabricates a command; secrets→env/1Password) · `dashboard` (ASCII/HTML control-panel: sessions·context·memory·status·MCPs·plugins·marketplaces·worktrees·tasks·next-actions) · `doctor` (`--health-check` read-only config audit with evidence+criterion+fix · `--self-test` the tool verifies itself) · `anchor` (surface canonical platform decisions + flag drift).

## Routes to (never reimplements — DRY)
- feature Q&A → `claude-code-guide` (agent) · official docs → `find-docs`/Context7/ref-tools
- create a tool → `agentic-tool-forge` → name → `anima` → eval/tune → `agentic-tool-evaluator`/`-trainer`
- session lifecycle → `preflight`·`postflight`·`auto-pilot`·`morning-briefing`·`pulse`·`quiesce`·`recap`
- other frameworks → `maos-concierge` (MAOS) · `walkthrough-concierge` (ASH) · `openclaw-concierge` (OpenClaw/OpenClaw)
- Atlassian → `maos-mcp-hub`

## Family
4th member of the cross-vendor **concierge family**: `maos-concierge` · `walkthrough-concierge` · `openclaw-concierge` · **`claude-code-concierge`** (this — the Claude-Code platform front-desk). Companions: `skills/claude-code-concierge/{AWARENESS-REGISTRY,CANON}.md` · `references/socratic-33q.md` · `dashboard.html`.
