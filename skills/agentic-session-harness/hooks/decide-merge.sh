#!/usr/bin/env bash
# Agentic Session Harness (ASH) — Stop hook: merge staged decisions → journal entry.decisions[]
# Function: deterministically fold in-session captures (bin/agentic-decide → staging) into the
#   session's finalized journal entry, then delete the staging file. Runs LAST in the Stop chain
#   (after the Stop subagent + stop-fallback.sh have written the entry).
# Why deterministic (not LLM-merged): agent reasoning capture must be reliable; a shell merge is
#   idempotent + auditable, where an LLM subagent merge is best-effort. Staged decisions WIN over
#   any subagent-emitted decisions of the same id (self-declared-at-decision-time > post-hoc).
# Spec: docs/governance/ash-schema.md §17 (v1.6.0 decision-audit extension, Layer-2 Vek).
# Portability: AAIF cross-vendor — Bash 3.2 + jq only; no associative arrays. Atomic via tmp+mv.
# No organization-specific content — promotion-eligible per Layer Purity Rule 2.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
[ -n "$SID" ] || { echo '{}'; exit 0; }
# CWE-78 defense: session id must be UUID-like (alnum + hyphens only).
case "$SID" in *[!a-zA-Z0-9-]*|""|.|..) echo '{}'; exit 0 ;; esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$PROJECT_DIR" in /*) ;; *) echo '{}'; exit 0 ;; esac
[ -d "$PROJECT_DIR" ] || { echo '{}'; exit 0; }

AUDIT_DIR="$PROJECT_DIR/.claude/audit"
STAGING="$AUDIT_DIR/staging/$SID.decisions.jsonl"
# Nothing staged → nothing to do (idempotent).
[ -s "$STAGING" ] || { echo '{}'; exit 0; }

# Locate the journal day-file that holds this session's entry (exclude staging; reject symlinks).
TARGET=""
while IFS= read -r f; do
  if jq -se --arg s "$SID" 'any(.[]; .session? == $s)' "$f" >/dev/null 2>&1; then TARGET="$f"; break; fi
done <<EOF
$(find "$AUDIT_DIR" -path "$AUDIT_DIR/staging" -prune -o -name '*.jsonl' -type f ! -type l -print 2>/dev/null)
EOF

# No entry yet (subagent + fallback both produced nothing) → leave staging for a later Stop/reindex.
[ -n "$TARGET" ] || { echo '{}'; exit 0; }

# Merge: staged decisions win on id collision; result deduped by id, sorted by id.
TMP="$TARGET.merge.tmp"
if jq -c --slurpfile staged "$STAGING" --arg s "$SID" '
      if .session == $s
      then .decisions = (($staged + (.decisions // [])) | unique_by(.id) | sort_by(.id))
      else . end' "$TARGET" > "$TMP" 2>/dev/null; then
  mv "$TMP" "$TARGET"
  rm -f "$STAGING"
else
  rm -f "$TMP" 2>/dev/null || true
  # Leave staging intact on failure (no data loss); emit sanitized diagnostic.
  echo "decide-merge: merge failed for session ${SID%%-*}; staging retained" >&2
fi

echo '{}'
