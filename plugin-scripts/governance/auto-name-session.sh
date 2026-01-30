#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance: auto-name-session.sh
# Purpose: Automatically name sessions based on project + branch + worktree
# Version: 1.0.0
# Protocol: C05 (Session Report Standard)
#
# Naming patterns:
#   - Worktree: {worktree-name}
#   - Main repo: {project}/{branch}@{MMDD-HHMM}
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source common if available
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    source "${LIB_DIR}/common.sh"
fi

# =============================================================================
# MAIN LOGIC
# =============================================================================

# Read input from stdin
INPUT=$(cat)

# Extract session info from JSON
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")

# Early exit if missing required fields
if [[ -z "$SESSION_ID" ]] || [[ -z "$CWD" ]]; then
    exit 0
fi

# Registry file location
REGISTRY="${HOME}/.claude/session-registry.json"

# Initialize registry if needed
if [[ ! -f "$REGISTRY" ]]; then
    echo '{"sessions": {}}' > "$REGISTRY"
fi

# Check if session already registered
EXISTING=$(jq -r ".sessions[\"$SESSION_ID\"] // empty" "$REGISTRY" 2>/dev/null || echo "")
if [[ -n "$EXISTING" ]]; then
    exit 0  # Already registered
fi

# =============================================================================
# NAME GENERATION
# =============================================================================

# Get project name
PROJECT=$(basename "$CWD")

# Get current branch
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "no-git")

# Timestamp for uniqueness
TIMESTAMP=$(date +"%m%d-%H%M")

# Check if in worktree
WORKTREE=""
if [[ "$CWD" =~ \.worktrees/([^/]+) ]]; then
    WORKTREE="${BASH_REMATCH[1]}"
fi

# Build session name
if [[ -n "$WORKTREE" ]]; then
    # Worktree sessions use worktree name directly
    SESSION_NAME="${WORKTREE}"
else
    # Main repo sessions: project/branch@timestamp
    SHORT_PROJECT=$(echo "$PROJECT" | cut -c1-15)
    SESSION_NAME="${SHORT_PROJECT}/${BRANCH}@${TIMESTAMP}"
fi

# =============================================================================
# REGISTRATION
# =============================================================================

# Register session name
TMP_FILE=$(mktemp)
if jq ".sessions[\"$SESSION_ID\"] = \"$SESSION_NAME\"" "$REGISTRY" > "$TMP_FILE" 2>/dev/null; then
    mv "$TMP_FILE" "$REGISTRY"
else
    rm -f "$TMP_FILE"
fi

# Output for MAOS session tracking
cat << OUTPUT
{
  "status": "success",
  "action": "session_named",
  "session_id": "${SESSION_ID}",
  "session_name": "${SESSION_NAME}",
  "is_worktree": $([ -n "$WORKTREE" ] && echo "true" || echo "false")
}
OUTPUT

exit 0
