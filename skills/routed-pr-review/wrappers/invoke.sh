#!/usr/bin/env sh
# Generic caller-side wrapper for any harness that can shell out.
#
# Auto-detects the calling harness from the environment so the independence
# invariant (verifier != generator) holds without the caller remembering to set
# ROUTED_REVIEW_CALLER by hand. Detection is best-effort and NEVER fabricates:
# if no signal is found, the variable stays unset and the dispatcher applies no
# exclusion — a weaker but honest gate.
#
# Usage: wrappers/invoke.sh --pr 42 [--post] [--json] [any dispatcher flag]
set -u

DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DISPATCH="$DIR/bin/routed-review.sh"
[ -x "$DISPATCH" ] || { printf 'invoke: %s not executable\n' "$DISPATCH" >&2; exit 1; }

detect_caller() {
  # Order matters: most specific env signal first. Each line is a real variable
  # exported by that harness, not a guess about one.
  [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && { echo claude; return; }
  [ -n "${CLAUDECODE:-}" ]             && { echo claude; return; }
  [ -n "${CODEX_SANDBOX:-}" ]          && { echo codex;  return; }
  [ -n "${GEMINI_CLI:-}" ]             && { echo gemini; return; }
  [ -n "${OPENCODE:-}" ]               && { echo opencode; return; }
  [ -n "${KIRO_IDE:-}" ]               && { echo kiro; return; }
  # $TERM_PROGRAM / parent-process sniffing deliberately omitted: it misfires
  # inside tmux and under any wrapper shell, and a WRONG caller name is worse
  # than none (it would exclude an innocent reviewer and admit the real one).
  echo ""
}

CALLER="${ROUTED_REVIEW_CALLER:-$(detect_caller)}"
if [ -n "$CALLER" ]; then
  ROUTED_REVIEW_CALLER="$CALLER" exec "$DISPATCH" "$@"
else
  printf 'invoke: caller harness not detected — no vendor exclusion will be applied.\n' >&2
  printf 'invoke: set ROUTED_REVIEW_CALLER=<harness> to restore verifier!=generator.\n' >&2
  exec "$DISPATCH" "$@"
fi
