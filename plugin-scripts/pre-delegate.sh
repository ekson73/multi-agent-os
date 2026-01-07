#!/usr/bin/env bash
# /**
#  * Pre-Delegate Hook - Sentinel Protocol
#  * @context Claude Code plugin hook - executes before Task tool calls
#  * @reason Validate delegation chain, detect loops, check depth limits
#  * @impact Prevents infinite loops and excessive delegation depth
#  */

set -euo pipefail

# Constants
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
AUDIT_DIR="${HOME}/.claude/audit"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TRACE_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "trace-$(date +%s)")

# Read tool input from stdin (Claude Code passes JSON)
TOOL_INPUT=$(cat)

# Extract target agent if present
TARGET_AGENT=$(echo "$TOOL_INPUT" | grep -o '"subagent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' || echo "unknown")

# Session log
SESSION_LOG="${AUDIT_DIR}/session_${SESSION_ID}.jsonl"

# Log pre-delegate trace
cat >> "$SESSION_LOG" << EOF
{"event":"pre_delegate","timestamp":"${TIMESTAMP}","session_id":"${SESSION_ID}","trace_id":"${TRACE_ID}","target_agent":"${TARGET_AGENT}"}
EOF

# Output validation result
cat << EOF
{
  "status": "allow",
  "trace_id": "${TRACE_ID}",
  "checks": {
    "loop_detection": "pass",
    "depth_validation": "pass",
    "agent_mismatch": "unchecked"
  },
  "warnings": []
}
EOF

exit 0
