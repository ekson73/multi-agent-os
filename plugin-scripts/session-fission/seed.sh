#!/usr/bin/env bash
# /**
#  * session-fission · seed.sh
#  * @context MAOS plugin script — emits a Ticket-as-Prompt seed SCAFFOLD for one atomic context.
#  * @reason Deterministic scaffold only. The AGENT (per the session-fission skill) fills the
#  *         distilled context — the cognitive step a script cannot do. Keeps the seed LIGHT.
#  * @impact Writes a markdown seed file under the seed dir. Touches no session transcript.
#  * @version 0.1.0
#  */

set -euo pipefail

# JSON-escape a string for safe interpolation into the stdout envelope.
json_escape() {
  local s="$1"
  s=${s//\\/\\\\}; s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}; s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

CLUSTER_ID="${1:?usage: seed.sh <cluster_id> [label] [seed_dir]}"
LABEL="${2:-$CLUSTER_ID}"
SEED_DIR="${3:-${SESSION_FISSION_SEED_DIR:-./.session-fission/seeds}}"

# Path-traversal guard: CLUSTER_ID becomes a filename — strip everything but
# [A-Za-z0-9._-] and any leading dots, so values like '../x' or 'a/b' cannot
# escape SEED_DIR or overwrite arbitrary files.
SAFE_ID="$(printf '%s' "$CLUSTER_ID" | tr -cd 'A-Za-z0-9._-' | sed 's/^\.*//')"
if [ -z "$SAFE_ID" ]; then
  printf '{"status":"error","error":"cluster_id has no filesystem-safe characters: %s"}\n' "$(json_escape "$CLUSTER_ID")"
  exit 1
fi

mkdir -p "$SEED_DIR"
SEED="$SEED_DIR/${SAFE_ID}.md"
NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$SEED" <<MD
# Seed — ${LABEL}

> session-fission atomic-context seed · cluster: \`${CLUSTER_ID}\` · generated: ${NOW_UTC}
> FILL every TODO with the DISTILLED context for THIS atomic task only. A fresh amnesic agent
> must be able to resume with ZERO prior context. Keep it minimal-sufficient (light nucleus).

## Context
TODO — state of the world preceding this task (what exists, what was decided, where we are).

## Objective
TODO — the single measurable outcome for this atomic context.

## Tasks / subtasks / steps
- [ ] TODO

## Files touched
- TODO (paths)

## Decisions made
- TODO

## Open question / next step
TODO — exactly what to do next.

## Acceptance criteria
- [ ] TODO

## Cross-links (traceability)
- ticket/backlog: TODO
- branch: TODO
- worktree: TODO
- origin session (archived, recoverable via /resume): TODO

## Relation in N-Tree
TODO — sequential → / recursive ↻ / independent ∥ / parallel ‖ (relative to sibling seeds)
MD

printf '{"status":"ok","cluster_id":"%s","label":"%s","seed_path":"%s","next":"fill the TODOs with distilled context, then reseed (ccpanes/launch_task | claude -n | /branch+/compact)"}\n' \
  "$(json_escape "$SAFE_ID")" "$(json_escape "$LABEL")" "$(json_escape "$SEED")"
