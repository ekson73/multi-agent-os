---
name: status
description: "[DEPRECATED v1.5.1 → removed v1.6.0] Alias for /agentic-status. Renamed to avoid collision with Claude Code built-in /status."
---

# /status Command — ⚠️ DEPRECATED ALIAS

> **⚠️ DEPRECATION NOTICE**
>
> This command was renamed to **`/agentic-status`** in v1.5.1 to avoid collision with the Claude Code built-in `/status` (which shows session/model/auth metadata, unrelated to agentic-system status).
>
> **Action required**: update muscle-memory + tooling to use `/agentic-status` instead.
>
> **Removal**: this alias will be **hard-removed in v1.6.0**. Re-target now to avoid disruption.

## Why the rename?

Per empirical observation 2026-05-21, the plugin command `/status` collided with Claude Code's built-in `/status`. The runtime resolution was ambiguous (built-in vs plugin), making UX unpredictable.

The fix follows the **Sandwich Namespacing 5-layer pattern** documented in:
- `~/.claude/docs/vendor-reserved-words.md` v1.0.0 (Layer 2 — vendor-reserved audit)
- `multi-agent-os/AGENTS.md` §34/§73 refined (Layer 3 — function-specific filename)

## Equivalent invocation (use this instead)

```
/agentic-status              # COMPACT template (default) — RECOMMENDED
/agentic-status pulse        # 1-line status
/agentic-status full         # Full audit report
/agentic-status debug        # Debug view
/agentic-status pre          # Pre-commit validation
/agentic-status end          # Session handoff
```

See `/agentic-status` command documentation for full template reference + ASCII output examples.

## Refs

- Plan PR-2 of 5: `~/.claude/plans/jaunty-riding-knuth.md`
- CHANGELOG.md v1.5.1 entry
- `~/.claude/docs/vendor-reserved-words.md` (origin of Sandwich Namespacing pattern)
