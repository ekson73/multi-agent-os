---
name: notebooklm
description: Route NotebookLM work between the notebooklm-py CLI, the notebooklm-mcp-cli MCP server, and the `@notebooklm-mcp` Claude Code toggle. Use when ingesting sources, generating podcasts/reports, or syncing docs into a notebook, and when deciding which client and which account (personal/work) to use.
version: 1.1.0
agnostic: [os, project]
---

# NotebookLM Operations

## Purpose

Route NotebookLM tasks to the correct interface (`@notebooklm-mcp`, `nlm` CLI, or `notebooklm` py CLI) with explicit profile safety (`personal`/`work`) and predictable operational flow. Two clients are installed, exposing three interfaces: the `notebooklm-mcp-cli` package provides both the `nlm` CLI and the `@notebooklm-mcp` MCP server; the `notebooklm-py` package provides the `notebooklm` CLI for pure-Python automation.

Do **not** enable `@notebooklm-mcp` unless this skill has been invoked first and the decision guide below points to it.

## Trigger Phrases

Invoke this skill when you receive any of the following:

- "ingest sources into NotebookLM"
- "generate a podcast / audio overview"
- "create a study guide / briefing doc / FAQ"
- "sync these docs to NotebookLM"
- "what notebooks do I have?"
- "create/delete/rename a notebook"

## Decision Guide

| Use Case | Tool | Why |
|----------|------|-----|
| Interactive chat, one-off notebook ops, query a notebook | `@notebooklm-mcp` (toggle on) | 35 MCP tools; real-time |
| Scripted / headless notebook ops, batch source upload | `nlm` CLI (notebooklm-mcp-cli) | Same API, no MCP server overhead |
| Pure-Python automation, CI pipelines | `notebooklm` CLI (notebooklm-py) | Lightweight Python API; no browser/Chrome |
| Discover notebooks, check source counts | `nlm notebook list --profile <p>` | Fastest read-only lookup |
| Auth troubleshooting, health check | `nlm doctor --verbose` | Covers both clients |

After finishing an `@notebooklm-mcp` session, toggle it back off to avoid bloating future sessions' tool lists.

## Profiles

Two accounts are configured. Always pass `--profile` explicitly; never mix sources across accounts. To inspect the actual email/account mapped to each profile in your local environment, run `nlm doctor --verbose` or `nlm profile list`.

| Profile | Account | Use for |
|---------|---------|---------|
| `personal` | `<personal-email>` | Personal research, open-source work |
| `work` | `<work-email>` | Vek/client projects, internal docs |

```bash
# List notebooks per profile
nlm notebook list --profile personal
nlm notebook list --profile work

# Inspect actual identity per profile
nlm doctor --verbose
```

## Pipelines

### 1. ingest → podcast

Add sources then request an audio overview.

```bash
# Create notebook (if new)
nlm notebook create --title "My Research" --profile personal

# Add sources (URLs, files, or Drive)
nlm source add <notebook-id> --url https://example.com/paper.pdf --profile personal
nlm source add <notebook-id> --file ./local-doc.md --profile personal

# Generate audio overview (async — poll for status)
nlm studio create <notebook-id> --type audio-overview --profile personal
nlm studio status <notebook-id> --profile personal
```

Via `@notebooklm-mcp` (toggle on):

```text
mcp__notebooklm-mcp__notebook_create  → create notebook
mcp__notebooklm-mcp__source_add       → add each source
mcp__notebooklm-mcp__studio_create    → request audio overview
mcp__notebooklm-mcp__studio_status    → poll until ready
mcp__notebooklm-mcp__download_artifact → download the mp3
```

### 2. research → report

Add sources then generate a study guide or briefing doc.

```bash
nlm notebook create --title "Topic Research" --profile work
nlm source add <notebook-id> --url https://... --profile work
nlm pipeline <notebook-id> study-guide --profile work
# or
nlm pipeline <notebook-id> briefing-doc --profile work
```

Via `@notebooklm-mcp`:

```text
mcp__notebooklm-mcp__notebook_create
mcp__notebooklm-mcp__source_add        (repeat per source)
mcp__notebooklm-mcp__pipeline          --type study-guide | briefing-doc | faq
mcp__notebooklm-mcp__export_artifact   → save output locally
```

### 3. multi-format batch

Mixed URL + local file sources into one notebook.

```bash
# Add URLs and files in one batch call
nlm batch add-sources <notebook-id> --profile personal \
  --urls "https://url1.com,https://url2.com" \
  --files "./doc1.md,./doc2.pdf"
```

Via `@notebooklm-mcp`:

```text
mcp__notebooklm-mcp__batch   → accepts mixed source list
```

## MCP Hygiene

`@notebooklm-mcp` exposes 35 tools. When it is enabled those tools appear in every tool invocation in the session, adding latency and context weight.

**Protocol:**
1. Toggle `@notebooklm-mcp` **on** at the start of a NotebookLM task (`/mcp` → enable `notebooklm-mcp`).
2. Complete all NotebookLM operations.
3. Toggle `@notebooklm-mcp` **off** before switching to unrelated work.

If `@notebooklm-mcp` is not listed in your Claude Code MCP panel, run:

```bash
nlm setup add claude-code
# then restart Claude Code
```

## Troubleshooting

Run `nlm doctor --verbose` first. It checks installation, auth cookies, CSRF token, Chrome profiles, and AI tool config in one pass.

| Symptom | Code | Recovery |
|---------|------|----------|
| Auth failure / 401 | `-32030` | `nlm login --profile <p>` or re-run `nlm setup add claude-code` |
| Notebook not found | `-32031` | Verify ID with `nlm notebook list --profile <p>` |
| Source limit reached (50 max) | `-32032` | Delete old sources before adding new ones |
| Unsupported format | `-32033` | Convert to PDF/MD/TXT first |
| Upload failed | `-32034` | Check file size (< 200 MB) and retry |
| API error | `-32035` | Check `nlm doctor --verbose`; retry after 60 s |

Error codes `-32030`–`-32039` are reserved for `sync-to-notebooklm`. Full registry: `docs/error-codes-registry.md`.

## Related Specs

- `docs/specs/sync-skill-interface.md` — standard interface all `sync-to-*` skills must implement
- `docs/error-codes-registry.md` — MCP-JSON-RPC error code registry; `-32030`–`-32039` reserved for NotebookLM
- **Phase 3 (deferred):** `sync-to-notebooklm` skill — automated doc sync using the reserved error range; tracked as Linear VKO-89 / VKO-90 (labels: `research`, `automation`)

---

*MAOS Community Skill v1.1.0 | OS-agnostic, project-agnostic*
