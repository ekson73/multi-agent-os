---
name: context-budget
description: Measure how much each source (rules, CLAUDE.md, MEMORY.md, skill/agent listings, deferred MCP tools, hooks) takes of the always-loaded context, in bytes and estimated tokens. Read-only.
---

# /maos:context-budget Command

Show which sources fill the context Claude Code loads before the first reply, ranked by size.
Use it to find what to trim, and re-run after each trim to measure the gain.

## Usage

```bash
bin/context-budget                 # auto: latest transcript of this cwd, else disk
bin/context-budget --json          # machine-readable report
bin/context-budget --top 20        # show more rows
bin/context-budget --mode disk     # estimate from files only
bin/context-budget --mode transcript --transcript <path.jsonl>
```

## Modes

| Mode | Source | What is measured |
|---|---|---|
| `transcript` | the session `.jsonl` under `~/.claude/projects/<cwd>/` | what was really injected before the first reply: system prompt, instruction files, skill/agent listings, deferred tool names, MCP server instructions, SessionStart/UserPromptSubmit hook content |
| `disk` | files on disk | rules, CLAUDE.md chain, MEMORY.md (measured); skill/agent/command listings (estimated); MCP, deferred tools and hooks reported `not_measured` |

`auto` (default) uses the newest transcript when one exists. Transcript mode is the reference
measurement; disk mode over-estimates listings because the harness truncates descriptions.

## Labels

- Tokens are `bytes/4`, an **estimate**, not a tokenizer count.
- `status`: `measured` · `estimated` · `not_measured`.
- Hook stdout is never counted or printed; only the `content` the harness injected.

Exit codes: `0` ok · `1` error (JSON-RPC on stderr) · `2` warning (transcript had no attachments).
