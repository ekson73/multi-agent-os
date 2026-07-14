#!/usr/bin/env sh
# resolve-session.sh — M2: map a session <id> → its persisted-artifact path.
#
# The M1 gap this closes: `dormancy-score.sh` takes a filesystem PATH, but the
# skill's `--session` flag accepts an id OR a path. This thin resolver turns an
# <id> into the path the rest of the pipeline consumes — so `--session <id>` works.
# It COMPOSES the existing session-artifact convention (Claude Code lays sessions
# at <root>/<encoded-cwd>/<id>.jsonl); it reinvents no primitive — the same "one
# thin deterministic helper" philosophy as dormancy-score (Strata / Gordian).
#
# Faithfulness (anti-theater R4): on no match it exits non-zero with an honest
# message — it NEVER fabricates a path. Deterministic: same tree → same result
# (LC_ALL=C lexical ordering, exact-match preferred).
#
# Usage:
#   resolve-session.sh <id|path> [--root <dir>]
#   --root : session-artifact root (default: $CLAUDE_SESSION_ROOT or ~/.claude/projects)
#
# Output: the resolved artifact path (a *.jsonl file, or the arg itself if it is
#         already an existing path) on stdout.
# Exit:   0 resolved · 2 usage error / not found.
# License: MIT (matches multi-agent-os repo LICENSE).
set -eu

ARG=""; ROOT="${CLAUDE_SESSION_ROOT:-$HOME/.claude/projects}"
while [ $# -gt 0 ]; do
  case "$1" in
    --root)    [ $# -ge 2 ] || { echo "[resolve-session] --root needs a dir value" >&2; exit 2; }; ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*)       echo "[resolve-session] unknown flag: $1" >&2; exit 2 ;;
    *)         [ -z "$ARG" ] || { echo "[resolve-session] too many positional args: '$1'" >&2; exit 2; }; ARG="$1"; shift ;;
  esac
done
[ -n "$ARG" ] || { echo "[resolve-session] missing <id|path>" >&2; exit 2; }

# 1) already an existing path → passthrough (the flag accepts id OR path).
if [ -e "$ARG" ]; then printf '%s\n' "$ARG"; exit 0; fi

# 2) resolve <id> → artifact under ROOT. Prefer an exact <id>.jsonl; else the
#    lexically-first <id>*.jsonl (deterministic — not mtime, which drifts).
[ -d "$ROOT" ] || { echo "[resolve-session] root not found: $ROOT (pass --root)" >&2; exit 2; }
exact="$(find "$ROOT" -type f -name "${ARG}.jsonl" 2>/dev/null | LC_ALL=C sort | head -1)"
if [ -n "$exact" ]; then printf '%s\n' "$exact"; exit 0; fi
match="$(find "$ROOT" -type f -name "${ARG}*.jsonl" 2>/dev/null | LC_ALL=C sort | head -1)"
[ -n "$match" ] || { echo "[resolve-session] no artifact for id '$ARG' under $ROOT" >&2; exit 2; }
printf '%s\n' "$match"
