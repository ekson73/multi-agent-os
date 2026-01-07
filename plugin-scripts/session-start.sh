#!/usr/bin/env bash
# /**
#  * Session Start Hook - Sentinel Protocol
#  * @context Claude Code plugin hook - executes at session initialization
#  * @reason Initialize audit logging, validate environment, load protocols
#  * @impact Ensures all multi-agent protocols are active from session start
#  */

set -euo pipefail

# Constants
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
AUDIT_DIR="${HOME}/.claude/audit"
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%Y%m%d)-$(openssl rand -hex 2)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Ensure audit directory exists
mkdir -p "$AUDIT_DIR"

# Initialize session audit log
SESSION_LOG="${AUDIT_DIR}/session_${SESSION_ID}.jsonl"

# Log session start
cat >> "$SESSION_LOG" << EOF
{"event":"session_start","timestamp":"${TIMESTAMP}","session_id":"${SESSION_ID}","plugin":"multi-agent-os","version":"1.0.0"}
EOF

# Output to Claude Code (optional context injection)
cat << EOF
{
  "status": "success",
  "message": "Multi-Agent OS initialized",
  "session_id": "${SESSION_ID}",
  "protocols": {
    "sentinel": "v1.0.0",
    "worktree_policy": "v1.1",
    "anti_conflict": "v3.2",
    "hierarchical_merge": "v1.0"
  },
  "instructions": "Follow Anti-Conflict Protocol phases. Use git worktrees for file modifications. Check tasks.md before editing shared files."
}
EOF

exit 0
