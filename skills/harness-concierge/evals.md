# EVAL-REPORT — harness-concierge (skill) + bin/harness-mcp-sync (executor) — 2026-09-24

- Evaluator: `agentic-tool-evaluator` method (behavioral; executor cases run for real; skill routing scored statically — no with/without sub-agent control was run, flagged below).
- Baseline: none (new tool). Golden cases: 8 (A–H, curated by operator) + repo suite.
- Isolation: `HOME=$(mktemp -d)`, `--state-dir` + `--registry` in a temp dir, fixture registry = {codex (toml), cursor (json), jcode (json, `headers: false`)}, dummy resolver returning a fake secret. Real HOME never touched in apply mode.

## Cases

| # | Case | Result | Evidence |
|---|---|---|---|
| A | Routing: "install a Claude Code plugin marketplace at project scope" → claude-code-concierge | PASS | harness-concierge `should_not_trigger[0]` routes it; claude-code-concierge gains the reverse hand-off row (routing table) + `should_not_trigger` entry for non-Claude harness MCP. Mutually consistent. Static check only. |
| B | `--harness nonexistent-tool` | PASS | exit 2, `error: unknown harness id(s): nonexistent-tool`; Protocol §1 mandates research → add YAML with `confidence: low`, never recall paths. |
| C | Dry-run never writes | PASS | sha of every file under temp HOME identical before/after `plan`; state-dir empty. |
| D | 2nd apply = empty plan | PASS | all servers `unchanged`, `apply: nothing-to-do`, `backup_ts: -`; `verify: clean`. |
| E | Malformed TOML aborts pre-write | PASS | `error malformed toml config (TOMLDecodeError)`, rc=1, file sha unchanged, no backup taken. |
| F | No-header harness + remote w/ headers | PASS | jcode: `skip remote-x — warn: harness lacks header support…`; stdio server still added. |
| G | Zero secrets in output | PASS | fake secret grepped across plan/apply/verify/explain/inventory/doctor/update (text + `--json`) and error paths → 0 hits; values shown as the opaque `«secret»` (no digest); secret present only in the (mode 600) config files. |
| H | Hand-written keys preserved | PASS | TOML: top-level key, comment, `[projects]` and `[mcp_servers.handwritten]` byte-for-byte; JSON: `handwritten` entry + `otherKey` kept. |

Repo suite `bash bin/tests/harness-mcp-sync.test.sh`: **86 passed, 0 failed** at eval time (pre red-team fixes). The suite grew with the red-team fixes; the current tally is recorded in the PR description for the head commit.

## Rubric (0–5)

| Dimension | Score | Note |
|---|---|---|
| Clarity | 5 | Layer table, 7-step tiered protocol, audit-able safety rules. |
| Triggerability | 4 | Good should/should-not sets; description also lists "skills/plugins/marketplace surfaces", overlapping claude-code-concierge's lexical territory; no `/slash` wrapper (`commands/harness-concierge.md` absent). |
| DRY | 5 | Facts in registry YAML, shapes in one `STYLES` table, routes out instead of duplicating. |
| Safety | 5 | Plan-first, backups, atomic, 600, conflict-not-overwrite, comment-refusal, secret masking all verified. |

**Verdict: PASS (FLAG-level improvements below).** Average 4.75/5.

## Top improvements (→ agentic-tool-trainer)

1. ✅ DONE (red-team round) — Unknown-harness error should name the next step (`add harnesses/<id>.yaml with confidence: low after research`) so the executor output mirrors Protocol §1.
2. ✅ description tightened (slash wrapper deferred — skills are invocable directly) — Tighten the description: say "non-Claude-Code harnesses' skills/plugin surfaces" to reduce collision with claude-code-concierge on marketplace/plugin queries; add a `/harness-concierge` command wrapper if human slash invocation is intended.
3. PARTIAL — `--adopt` conflict and `restore` round-trip tests now exist; still open: run a true with/without sub-agent trigger eval (case A was static), and add explicit test cases for `--adopt` conflict and `restore` round-trip to the fixture set.
