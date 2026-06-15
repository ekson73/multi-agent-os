---
name: opendesign-concierge
description: Front-desk concierge for the Open Design platform (`nexu-io/open-design`) — onboard · teach the platform (od CLI, 152 design-systems, MCP) · guide an intent to the right integration tier + exact `od` invocation · audit whether Open Design is installed/configured. Thin wrapper over the `opendesign-concierge` skill. Routes to the od CLI / design-system runbooks — reimplements nothing, never re-clones Open Design.
argument-hint: "[intent] | [--mode explain|onboard|guide|audit] [--help]"
allowed-tools: [Read, Glob, Grep, Bash, WebFetch, WebSearch, Skill]
---

# /opendesign-concierge

Invoke the **`opendesign-concierge`** skill (Claude Code: `Skill` tool with `skill: "opendesign-concierge"`; other hosts: equivalent skill-activation), passing the arguments below.

**Arguments**: `$ARGUMENTS`

## Parsing
- Empty `$ARGUMENTS` OR `--help` → `--mode=explain` (teach the platform; do NOT guess an intent).
- `--mode=<explain|onboard|guide|audit>` → run that mode.
- A bare intent string ("apply the airbnb design system", "od vs figma", "is it installed") → `--mode=guide` (default).

## What it does (skill — 4 modes)
`explain` (teach Open Design: BYOK/no-local-LLM · `od` CLI · 152 design-systems · the 2 integration tiers) · `onboard` (capability-detect → pick tier → first command) · `guide` (intent → exact tier + `od` invocation + runbook section — the "helper" surface) · `audit` (read-only: is OD installed? config drift vs CANON?).

## Routes to (never reimplements — DRY)
- the `od` CLI (apply/migrate/mcp) · the design-system apply runbook (Tier A assets / Tier B daemon) · Cloudflare `wrangler` for previews · OpenSpec/Spec-Kit for the spec-driven legs.

## Family
Member of the cross-vendor **concierge family**: `maos-concierge` · `claude-code-concierge` · `walkthrough-concierge` · **`opendesign-concierge`** (this — the Open Design platform front-desk). Companions: `skills/opendesign-concierge/{AWARENESS-REGISTRY,CANON}.md` · `references/{od-knowledge-pack,apply-design-system-runbook}.md`.
