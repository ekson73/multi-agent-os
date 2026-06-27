---
name: bitbucket-pipeline-watch
description: Use when an agent needs to WAIT for a Bitbucket Cloud pipeline/build to finish and act on the outcome — instead of fixed-interval polling. Backgrounds a poll-until-done loop that exits the instant the build COMPLETES, so the harness re-invokes the agent on the real event; on FAILURE it returns the redacted failure diagnosis (failed steps + error-relevant log tail) already baked in. Pairs with the maos-mcp-hub atlassian_bitbucket gateway.
triggers:
  - "watch this bitbucket pipeline"
  - "wait for the build to finish"
  - "tell me when the pipeline completes"
  - "diagnose the pipeline failure"
  - "wake me when the build is done"
version: 1.0.0
---

# Bitbucket Pipeline Watch — wake-on-completion, diagnosis-in-hand

## §0 — BEING > Rules
Serves the operator's intent: stop burning context-cache on `ScheduleWakeup` polling and stop the 3-call failure dance (`get_steps` → `auto_diagnose` → fetch log). If it obstructs delivering value NOW, skip it and proceed. ⛔ The API token is **never** echoed — secret-safety is non-negotiable.

## The problem it solves
An agent that wants to "act when the pipeline finishes" has two bad options:
1. **Fixed-interval `ScheduleWakeup`** — wakes every N seconds, pays a context cache-miss each time, and still has to go fetch the failure details.
2. **A true inbound webhook** — impossible: a local agent has no public HTTP endpoint, and the harness has no "inbound POST → re-invoke agent" bridge.

The viable equivalent: **a backgrounded poll-until-done loop**. The harness re-invokes the agent when a backgrounded `Bash` command exits. So a script that blocks until the build ends — and prints the verdict + (on failure) the diagnosis before exiting — gives event-driven wake-on-completion with the answer already in hand. No public endpoint, no cache-miss spam, no follow-up calls.

## When to use
- You triggered/pushed a Bitbucket pipeline and need to act on green/red (merge gate, PDCA iterate, hand-off).
- You are in a `/quiesce`/auto-pilot loop monitoring a CI run.
- You want the failure logs **automatically** if it fails, not just a status bit.

**When NOT to use**: you only need a one-shot current status → call `mcp__maos-mcp-hub__atlassian_bitbucket` `pipeline get`/`get_steps` directly (synchronous, no wait). The build is already done → just read it.

## How to use
```bash
# Background it — the harness wakes you when it exits (on COMPLETED or timeout):
bin/bb-pipeline-watch.sh --build 1363 --repo vks-jss-sales-api &   # run_in_background:true
# or watch the latest build on a branch:
bin/bb-pipeline-watch.sh --latest --branch feature/x --repo vks-jss-sales-api
# one-shot sanity check (no loop):
bin/bb-pipeline-watch.sh --build 1363 --repo vks-jss-sales-api --once
```
On wake, read the command's output file:
- `=== BUILD <n> COMPLETED: SUCCESSFUL ===` → act on green.
- `=== BUILD <n> COMPLETED: FAILED ===` followed by `FAILURE DIAGNOSIS (redacted)` → the failed step(s) + the error-relevant log tail are already there; decide the fix without extra calls.

## Contract
- **Creds**: read from the maos-mcp-hub `.env` (`BITBUCKET_API_TOKEN`, Bearer) in a subshell; override with `--env-file` / `BB_WATCH_ENV_FILE`. The token is used only in an `Authorization` header and **never printed**.
- **Redaction**: all log output passes through `redact()` (masks `ASIA…`/`AKIA…` keys, long base64 secrets, `*_token`/`*secret*`/`password` values). Anti-theater: a leaked secret in a "helpful" log is worse than no log.
- **Exit**: `0` on a reached verdict OR timeout (clean background completion → harness wake); non-zero only on setup error (missing token / bad args).
- **Bounds**: `--interval` (default 45s), `--max-polls` (default 80 ≈ 60min). Deterministic — no model judgment in the loop.

## Anti-patterns
- ❌ Fixed-interval `ScheduleWakeup` polling for a build the harness could wake you on. ❌ Calling `get_steps`→`diagnose`→`fetch log` by hand on every failure (this bakes it in). ❌ Echoing the token or an un-redacted log. ❌ Using it for a one-shot status (use the MCP gateway directly).

## Refs
- Pairs with `mcp-tools/maos-mcp-hub` `atlassian_bitbucket` gateway (`pipeline get`/`get_steps`/`auto_diagnose`).
- Pattern origin: `vks-jss-sales-api` PR#85 (build 1362 FAILED → needed get_steps+diagnose+log by hand; this skill collapses that into one backgrounded wait). Cross-link `[[bitbucket-pipeline-watch]]`.
- Mechanism: Claude Code re-invokes the agent on backgrounded-`Bash` exit (the "wake me when it finishes" equivalent of a webhook).
