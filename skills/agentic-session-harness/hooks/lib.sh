#!/usr/bin/env bash
# Agentic Session Harness (ASH) — shared helper library (sourced, NOT executed)
# Function: pure helpers reused by stop-fallback.sh (Stop hook) and bin/agentic-reindex
#   (backfill/migrate CLI). Extracting them keeps the two write-paths DRY (ADR-014).
# Spec: SPEC.md (Layer-1 frozen-17, in-repo) — §2 schema + §17 decision-audit (optional extension)
# Portability: AAIF cross-vendor — POSIX-portable Bash 3.2 + jq only; no host-specific primitives,
#   no associative arrays, no ${var^^}. Functions echo results; callers own `set -euo pipefail`.
# No organization-specific content — promotion-eligible per Layer Purity Rule 2.
#
# Idempotency contract: every function is side-effect-free EXCEPT it reads files. Safe to source
# multiple times (guard below prevents re-definition cost).

[ -n "${ASH_LIB_SOURCED:-}" ] && return 0
ASH_LIB_SOURCED=1

# Current ASH journal-row schema version — stamps each Layer-1 row (SPEC.md §2 frozen-17).
# The community Layer-1 contract is "1.0.0". The §17 decision-audit fields
# (decisions[].spec_alignment / .confidence, sources[].influence) are an ADDITIVE OPTIONAL
# extension carried INSIDE the `decisions[]` array — they do NOT bump the row schema_version.
# (Entries stamped below this are migration candidates: agentic-reindex --migrate.)
ASH_SCHEMA_CURRENT="1.0.0"

# --- timestamp shims (BSD/macOS `date` lacks %N) ---
ash_iso_ms() {
  if command -v gdate >/dev/null 2>&1; then
    gdate -u +"%Y-%m-%dT%H:%M:%S.%3NZ"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00','Z'))"
  else
    date -u +"%Y-%m-%dT%H:%M:%S.000Z"
  fi
}
ash_epoch_ms() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import time; print(int(time.time()*1000))"
  else
    echo "$(date -u +%s)000"
  fi
}

# ash_resolve_tenant <project_dir> — §3 fallback chain: ASH_TENANT env → .claude/ash-tenant
#   → package.json name → git toplevel basename → "unknown".
ash_resolve_tenant() {
  local project_dir="$1" tenant="${ASH_TENANT:-}"
  if [ -z "$tenant" ] && [ -f "$project_dir/.claude/ash-tenant" ]; then
    tenant=$(head -n1 "$project_dir/.claude/ash-tenant" | tr -d '[:space:]')
  fi
  if [ -z "$tenant" ] && [ -f "$project_dir/package.json" ]; then
    tenant=$(jq -r '.name // empty' "$project_dir/package.json" 2>/dev/null || true)
  fi
  [ -n "$tenant" ] || tenant=$(basename "$(git -C "$project_dir" rev-parse --show-toplevel 2>/dev/null || echo unknown)")
  printf '%s' "$tenant"
}

# ash_locate_transcript <project_dir> <sid> — echo the relative transcript path (symlink under
#   .claude/transcripts/). Caller resolves abs via "$project_dir/$rel".
ash_locate_transcript_rel() {
  printf '.claude/transcripts/%s.jsonl' "$2"
}

# ash_sha256 <file> — sha256 hex of file, or empty string if unreadable.
ash_sha256() {
  [ -r "$1" ] || { printf ''; return 0; }
  shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' || printf ''
}

# ash_extract_goal <transcript_abs> — first operator-typed user message (the goal), collapsed to a
#   single line, capped 240 chars. Empty if none / unparseable.
#   Handles BOTH content shapes Claude Code emits: string content AND array-of-blocks content
#   (operator prose is frequently an array text block, not a bare string). Skips injected
#   non-goal artifacts: ANY block opening with an XML-ish tag (^<tag — covers <local-command-caveat>,
#   <command-name>/<command-message> from /clear//compact//model, <local-command-stdout>,
#   <system-reminder>, <task-notification>, future tags), skill-injection context ("Base directory
#   for this skill:"), and interrupt markers ("[Request interrupted by user]").
#   NOTE: heuristic best-effort — high-fidelity goal reconstruction is the opt-in LLM enrich path
#   (ASH_ENRICH_CMD); residual artifacts (e.g. an /enhance skill body opening with "#") may remain.
ash_extract_goal() {
  local f="$1"
  [ -r "$f" ] || { printf ''; return 0; }
  jq -rn '[ inputs
            | select(.type=="user")
            | .message.content
            | if type=="string" then [.]
              elif type=="array" then [ .[] | select(.type=="text") | .text ]
              else [] end
            | .[]
            | select(type=="string")
            | gsub("^[[:space:]]+";"")
            | select(. != "")
            | select(test("^<[A-Za-z]") | not)
            | select(test("^Base directory for this skill:") | not)
            | select(test("^\\[Request interrupted by user\\]") | not)
          ] | first // ""' "$f" 2>/dev/null \
    | tr '\n\r\t' '   ' \
    | tr -s ' ' \
    | cut -c -240 \
    || printf ''
}

# ash_extract_decisions <transcript_abs> [ts] — best-effort STRUCTURAL extraction of agent
#   decisions from the session transcript at Stop time, emitting a COMPACT JSON array in the
#   §17.1 decisions[] shape (or "[]"). Uses the XDEC-<n> id namespace (eXtracted; never collides
#   with explicit DEC-<n> from bin/agentic-decide — decide-merge.sh §17.3 keeps both, deduped).
#   WHY here (not the Stop type:agent step-10): the type:agent path empirically NEVER wrote an
#   entry (0/N real sessions — agent field only ever 'fallback'/'reindex'); this helper runs on
#   the always-firing fallback path, making capture reliable + deterministic + amnesia-proof.
#   Signals (highest-fidelity / lowest-fragility): git-commit subjects (conventional-commit =
#   what+scope+often why), gh pr create titles, gh pr merge ops — each a Bash tool_use whose full
#   rationale lives in the referenced commit/PR; the manual agentic-decide ceiling adds nuanced "why"
#   for high-stakes calls. Anti-hallucination: no signal => "[]" (never fabricate). Order-preserving
#   dedup; cap ASH_XDEC_CAP (default 15). Bash 3.2 + jq only; recursive-descent robust to nesting.
ash_extract_decisions() {
  local f="$1" ts="${2:-}"
  [ -r "$f" ] || { printf '[]'; return 0; }
  [ -n "$ts" ] || ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local cap="${ASH_XDEC_CAP:-15}"
  case "$cap" in ''|*[!0-9]*) cap=15 ;; esac
  jq -cn --arg ts "$ts" --argjson cap "$cap" '
    [ inputs | .. | objects
      | select(.type=="tool_use" and .name=="Bash")
      | (.input.command // "") ] as $cmds
    | ( [ $cmds[] | select(test("git commit"))
          | (capture("git commit(?:[^\"]*)-[A-Za-z]*m[[:space:]]*\"(?<m>[^\"\\n]+)") | .m) // empty ]
        + [ $cmds[] | select(test("gh pr create"))
          | (capture("--title[[:space:]]*\"(?<t>[^\"\\n]+)") | .t) // "PR created" ]
        + [ $cmds[] | select(test("gh pr merge[[:space:]]+[0-9]"))
          | "merged PR #" + (capture("gh pr merge[[:space:]]+(?<n>[0-9]+)") | .n) ]
      )
    | map(select(. != null and . != ""))
    | reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end)
    | .[0:$cap]
    | to_entries
    | map({
        id: ("XDEC-" + ((.key+1)|tostring)),
        ts: $ts,
        decision: .value,
        rationale: "structural extraction (conventional-commit / gh-pr signal at session-end); full reasoning in the referenced commit/PR",
        sources: [ {type:"transcript", ref:"git/gh tool_use", influence:"cited"} ],
        spec_refs: ( [ .value | scan("ADR-[A-Za-z0-9-]+|VKS-[0-9]+|#[0-9]+") ] ),
        spec_alignment: "unverified",
        confidence: "medium"
      })
  ' "$f" 2>/dev/null || printf '[]'
}

# ash_transcript_first_ts <transcript_abs> — earliest ISO-8601 .timestamp present in the
#   transcript (Claude Code stamps top-level .timestamp per entry). Empty if none.
#   Used to bucket backfilled entries by their REAL date (not "today").
ash_transcript_first_ts() {
  local f="$1"
  [ -r "$f" ] || { printf ''; return 0; }
  jq -rn 'first(inputs | .timestamp? // empty)' "$f" 2>/dev/null || printf ''
}

# ash_journal_path_for_ts <project_dir> <iso_ts> — echo absolute journal day-file path
#   $project_dir/.claude/audit/<YYYY-MM>/<DD>.jsonl derived from an ISO timestamp.
#   Returns non-zero (and echoes nothing) if the timestamp is not parseable.
ash_journal_path_for_ts() {
  local project_dir="$1" iso="$2"
  local ym="${iso:0:7}" dd="${iso:8:2}"
  case "$ym" in [0-9][0-9][0-9][0-9]-[0-9][0-9]) ;; *) return 1 ;; esac
  case "$dd" in [0-9][0-9]) ;; *) return 1 ;; esac
  printf '%s/.claude/audit/%s/%s.jsonl' "$project_dir" "$ym" "$dd"
}

# ash_version_lt <a> <b> — return 0 (true) if semver a < b, else 1. Field-split numeric
#   compare (no `sort -V` dependency; bash-3.2-safe). Treats missing components as 0.
ash_version_lt() {
  local a="$1" b="$2" i a_i b_i
  local IFS=.
  # shellcheck disable=SC2206
  local aa=($a) bb=($b)
  for i in 0 1 2; do
    a_i=${aa[$i]:-0}; b_i=${bb[$i]:-0}
    # strip non-digits defensively
    a_i=${a_i//[!0-9]/}; b_i=${b_i//[!0-9]/}
    a_i=${a_i:-0}; b_i=${b_i:-0}
    if [ "$a_i" -lt "$b_i" ]; then return 0; fi
    if [ "$a_i" -gt "$b_i" ]; then return 1; fi
  done
  return 1
}
