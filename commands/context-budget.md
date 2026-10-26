---
name: context-budget
description: Measure how much each source (rules, CLAUDE.md, MEMORY.md, skill/agent listings, deferred MCP tools, hooks) takes of the always-loaded context, in bytes and estimated tokens. Read-only.
---

# /maos:context-budget Command

Show which sources fill the context Claude Code loads before the first reply, ranked by size.
Use it to find what to trim, and re-run after each trim to measure the gain.

## Usage

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/context-budget"                 # auto: latest transcript of this cwd, else disk
"${CLAUDE_PLUGIN_ROOT}/bin/context-budget" --json          # machine-readable report
"${CLAUDE_PLUGIN_ROOT}/bin/context-budget" --top 20        # show more rows
"${CLAUDE_PLUGIN_ROOT}/bin/context-budget" --mode disk     # estimate from files only
"${CLAUDE_PLUGIN_ROOT}/bin/context-budget" --mode transcript --transcript <path.jsonl>
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
- `status`: `measured` · `estimated` · `not_measured` · `skipped`.
- An attachment type the tool does not recognise is reported as `unknown:<type>`
  (category `unknown`, status `estimated`, size of the serialized JSON, `count` = occurrences).
- `skipped non-object records` counts transcript lines that are valid JSON but not an object
  (or an attachment that is not an object). Lines that are not JSON are dropped and not counted.
- `ignored malformed plugin config records` (disk mode) counts plugin settings entries of the
  wrong type; they are skipped, not fatal.
- Hook names and the executable basename are redacted: `*TOKEN*`, `*KEY*`, `*SECRET*`,
  `*PASSWORD*`, `*PASSWD*` assignments, and `PASS`/`PWD`/`AUTH` as a whole `_`/`-` segment
  (so `BYPASS=` stays), plus bearer tokens and URLs with userinfo or a query string.
- Hook stdout and stderr are never counted or printed; only the text the harness injected into
  the model's context: `content`, or `response.hookSpecificOutput.additionalContext` for
  `async_hook_response`. `hook_non_blocking_error` injects nothing, so it adds no row.

Exit codes:
- `0` ok — including `auto` with no `latest` transcript, which falls back to disk.
- `1` error, JSON-RPC on stderr — `--mode transcript` with no transcript found, an explicit
  `--transcript PATH` that does not exist (in any mode), or a read failure.
- `2` warning — the transcript used had no injected-context attachments (a transcript holding
  only skipped records still exits `0`).
