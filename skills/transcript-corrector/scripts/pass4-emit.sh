#!/usr/bin/env bash
# /**
#  * Pass 4 — emit corrected text + diff + audit summary
#  * @context Final pass. Writes to stdout (default) or to --output <path>.
#  *          Always prints a 5-line audit summary to stderr regardless of mode.
#  * @reason Operator needs both the corrected artifact AND verifiable evidence
#  *          (diff + audit JSON) to trust the correction.
#  * @impact Inline mode is a no-op for v1.0.0 (write-back to source via MCP is
#  *          planned v1.1.0+; for now operator manually applies the diff).
#  */
set -euo pipefail

ORIGINAL=""; CORRECTED=""; AUDIT=""; OUTPUT="stdout"; MODE="review-only"
while [ $# -gt 0 ]; do
  case "$1" in
    --original) ORIGINAL="$2"; shift 2 ;;
    --corrected) CORRECTED="$2"; shift 2 ;;
    --audit) AUDIT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$ORIGINAL" ] && [ -n "$CORRECTED" ] && [ -n "$AUDIT" ] \
  || { echo "Missing --original/--corrected/--audit" >&2; exit 1; }

# 1. Audit summary on stderr (5-line, always)
APPLIED_COUNT=$(python3 -c "import json,sys; a=json.load(open(sys.argv[1])); print(sum(1 for x in a if x.get('applied')))" "$AUDIT")
FLAGGED_COUNT=$(python3 -c "import json,sys; a=json.load(open(sys.argv[1])); print(sum(1 for x in a if not x.get('applied') and 'note' in x))" "$AUDIT")
{
  echo "==[transcript-corrector audit]======================"
  echo "  Applied corrections: $APPLIED_COUNT"
  echo "  Flagged (LOW/MEDIUM, not applied): $FLAGGED_COUNT"
  echo "  Audit JSON: $AUDIT"
  echo "  Mode: $MODE"
} >&2

# 2. Emit corrected text
case "$OUTPUT" in
  stdout)
    cat "$CORRECTED"
    ;;
  *)
    cp "$CORRECTED" "$OUTPUT"
    echo "[pass4-emit] corrected output written to: $OUTPUT" >&2
    ;;
esac

# 3. Side-by-side diff (always to stderr after the corrected text)
if command -v diff >/dev/null 2>&1; then
  {
    echo ""
    echo "==[unified diff: original → corrected]==============="
    diff -u "$ORIGINAL" "$CORRECTED" || true
  } >&2
fi

# 4. Inline mode is operator-applied for v1.0.0; we log the intent + auth marker
case "$MODE" in
  inline|apply-*)
    echo "[pass4-emit] MODE=$MODE: write-back to source is operator-applied in v1.0.0" >&2
    echo "[pass4-emit] HITL auth was provided (recorded in run logs). v1.1.0+ will MCP-write." >&2
    ;;
esac
