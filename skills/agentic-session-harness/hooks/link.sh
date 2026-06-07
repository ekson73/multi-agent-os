#!/usr/bin/env bash
# Agentic Session Harness (ASH) — SessionStart hook
# Function: symlink Claude Code native transcript into .claude/transcripts/
# Spec: docs/governance/ash-schema.md §4 Storage layout
# Idempotent: re-creating an existing symlink with same target is safe.
# Portability: AAIF cross-vendor compatible (Claude Code primary; adaptable to Cursor / Copilot / Aider via equivalent SessionStart equivalents).
# No organization-specific content — promotion-eligible per Layer Purity Rule 2.
set -euo pipefail

# Entry-point sanity check — CLAUDE_PROJECT_DIR is Claude-Code-supplied (trusted in our
# threat model: operator-controlled environment) but we defensively require it to be an
# existing absolute path. Refuses bizarre values that could shape downstream behavior.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$PROJECT_DIR" in /*) ;; *) echo '{}'; exit 0 ;; esac
[ -d "$PROJECT_DIR" ] || { echo '{}'; exit 0; }

# Claude Code provides session metadata via stdin JSON (SessionStart hook spec)
INPUT=$(cat 2>/dev/null || echo '{}')
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
[ -n "$SID" ] || { echo '{}'; exit 0; }  # silent skip if no session_id (Claude Code <0.5)

# Validate SID format (Claude Code session_id is UUID — alnum + hyphens only).
# Rejects path-traversal payloads and shell metacharacters.
case "$SID" in
  *[!a-zA-Z0-9-]*|""|.|..) echo '{}'; exit 0 ;;
esac

# Compute encoded-cwd per Claude Code convention.
# Claude Code replaces BOTH `/` AND `.` with `-` when materializing the project
# transcript dir under ~/.claude/projects/. Replacing only `/` (prior behavior)
# left literal dots in usernames/paths and produced dangling symlinks
# (e.g. /Users/emilson.moraes/... → -Users-emilson.moraes-... instead of the
#  correct -Users-emilson-moraes-...). Replace both classes.
ENCODED_CWD=$(printf '%s' "$PROJECT_DIR" | sed 's|[/.]|-|g')
SRC="$HOME/.claude/projects/${ENCODED_CWD}/${SID}.jsonl"
DST_DIR="$PROJECT_DIR/.claude/transcripts"
DST="$DST_DIR/${SID}.jsonl"

mkdir -p "$DST_DIR"
# CWE-59 defense via path constraint: SRC is ALWAYS within $HOME/.claude/projects/<encoded-cwd>/
# (composed from validated SID + sed-encoded path). Create dangling symlink if needed
# (POSIX-safe; resolves once transcript appears — Claude Code may create it post-SessionStart).
# ln -sfn replaces stale link safely.
SRC_PARENT="$HOME/.claude/projects/${ENCODED_CWD}/"
case "$SRC" in
  "$SRC_PARENT"*) ln -sfn "$SRC" "$DST" ;;
  *) ;;  # refuse — SRC escapes expected parent
esac

echo '{}'
