#!/usr/bin/env bash
# /**
#  * Session End Hook - Sentinel Protocol
#  * @context Claude Code plugin hook - executes at session termination
#  * @reason Calculate final health score, generate session summary, cleanup
#  * @impact Provides session audit trail and health metrics
#  */

set -euo pipefail

# Constants
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
AUDIT_DIR="${HOME}/.claude/audit"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Session log
SESSION_LOG="${AUDIT_DIR}/session_${SESSION_ID}.jsonl"

# Calculate basic health score
HEALTH_SCORE=100
ERROR_COUNT=$(grep -c '"success":false' "$SESSION_LOG" 2>/dev/null || echo 0)
HEALTH_SCORE=$((HEALTH_SCORE - (ERROR_COUNT * 10)))
[ $HEALTH_SCORE -lt 0 ] && HEALTH_SCORE=0

# Log session end
cat >> "$SESSION_LOG" << EOF
{"event":"session_end","timestamp":"${TIMESTAMP}","session_id":"${SESSION_ID}","health_score":${HEALTH_SCORE}}
EOF

# Output session summary
cat << EOF
{
  "status": "success",
  "session_id": "${SESSION_ID}",
  "summary": {
    "health_score": ${HEALTH_SCORE},
    "errors": ${ERROR_COUNT},
    "status": "$([ $HEALTH_SCORE -ge 70 ] && echo 'healthy' || echo 'degraded')"
  },
  "audit_log": "${SESSION_LOG}"
}
EOF

exit 0
