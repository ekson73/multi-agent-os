#!/usr/bin/env bash
# Agentic Session Harness (ASH) — SessionStart context-injection hook
# Function: inject last 3-5 journal entries as context for amnesic agent
# Spec: docs/governance/ash-schema.md §1 Premissa + §7 Cultural loop
# Output: JSON {hookSpecificOutput: {hookEventName, additionalContext}} per Claude Code hook spec.
# Portability: AAIF cross-vendor compatible — output schema is Claude Code native; adaptable to other hosts via their SessionStart equivalents.
# No organization-specific content — promotion-eligible per Layer Purity Rule 2.
set -euo pipefail

# Entry-point sanity check — defense-in-depth on PROJECT_DIR (see link.sh §note)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$PROJECT_DIR" in /*) ;; *) echo '{}'; exit 0 ;; esac
[ -d "$PROJECT_DIR" ] || { echo '{}'; exit 0; }

AUDIT_DIR="$PROJECT_DIR/.claude/audit"

# No audit dir yet → first session ever → emit empty context (silent)
[ -d "$AUDIT_DIR" ] || { echo '{}'; exit 0; }

# Gather last 5 journal lines across all month dirs (newest-first).
# CWE-22 defense: -type f ! -type l rejects symlinks so attacker-planted links
# outside AUDIT_DIR cannot be followed.
LAST_ENTRIES=$(find "$AUDIT_DIR" -name '*.jsonl' -type f ! -type l 2>/dev/null \
  | xargs -I{} sh -c 'tail -n 5 "{}" 2>/dev/null' \
  | grep -v '^$' \
  | tail -n 5 || true)

[ -n "$LAST_ENTRIES" ] || { echo '{}'; exit 0; }

# Summarize each entry into a compact 1-2 line digest
SUMMARY=$(printf '%s\n' "$LAST_ENTRIES" | jq -r '
  "• \(.ts // "?") [\(.agent // "?")] goal=\(.goal // "?") | task=\(.task // "?")" +
  (if (.next_steps // [] | length) > 0 then "\n  next: \(.next_steps | join("; "))" else "" end) +
  (if (.compliance_flags // [] | map(select(.status == "violated" or .status == "ignored")) | length) > 0 then "\n  ⚠ flags: \(.compliance_flags | map(select(.status == "violated" or .status == "ignored")) | map("\(.spec_id)=\(.status)") | join(", "))" else "" end)
' 2>/dev/null || true)

[ -n "$SUMMARY" ] || { echo '{}'; exit 0; }

# Emit additionalContext (Claude Code prepends this to next user turn context)
jq -n --arg ctx "## ASH-lite recent session context (last $(echo "$LAST_ENTRIES" | wc -l | tr -d ' ') entries)

$SUMMARY

Reference: docs/governance/ash-schema.md · bin/agentic-walkthrough <session_id> for full timeline." '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
