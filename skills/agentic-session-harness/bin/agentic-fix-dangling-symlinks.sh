#!/usr/bin/env bash
# agentic-fix-dangling-symlinks — Repair transcript symlinks created with the
# pre-fix encoding (only `/` → `-`, dots preserved) so existing sessions
# can be walked through retroactively. Idempotent: skips already-valid links.
# Companion to the encoding-bug fix in .claude/hooks/link.sh.
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$PROJECT_DIR" in /*) ;; *) echo "PROJECT_DIR must be absolute: $PROJECT_DIR" >&2; exit 1 ;; esac
[ -d "$PROJECT_DIR" ] || { echo "PROJECT_DIR not a directory: $PROJECT_DIR" >&2; exit 1; }

TRANSCRIPT_DIR="$PROJECT_DIR/.claude/transcripts"
[ -d "$TRANSCRIPT_DIR" ] || { echo "no transcript dir at $TRANSCRIPT_DIR — nothing to fix" >&2; exit 0; }

CORRECT_ENCODING=$(printf '%s' "$PROJECT_DIR" | sed 's|[/.]|-|g')
CORRECT_PARENT="$HOME/.claude/projects/${CORRECT_ENCODING}/"

[ -d "$CORRECT_PARENT" ] || { echo "correct transcript parent not found: $CORRECT_PARENT" >&2; exit 1; }

fixed=0
already_ok=0
target_missing=0
not_symlink=0
total=0

for link in "$TRANSCRIPT_DIR"/*.jsonl; do
  [ -e "$link" ] || [ -L "$link" ] || continue
  total=$((total + 1))

  if [ ! -L "$link" ]; then
    not_symlink=$((not_symlink + 1))
    continue
  fi

  target=$(readlink "$link")
  if [ -f "$target" ]; then
    already_ok=$((already_ok + 1))
    continue
  fi

  # Compute corrected target
  base=$(basename "$link")
  corrected="$CORRECT_PARENT$base"

  if [ -f "$corrected" ]; then
    ln -sfn "$corrected" "$link"
    fixed=$((fixed + 1))
  else
    target_missing=$((target_missing + 1))
  fi
done

cat <<EOF
agentic-fix-dangling-symlinks report
  total scanned:    $total
  already valid:    $already_ok
  fixed:            $fixed
  target missing:   $target_missing   (real transcript not found at corrected path)
  non-symlink file: $not_symlink     (left untouched)
EOF
