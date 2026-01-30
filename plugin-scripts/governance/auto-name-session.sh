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

# Source common if available (provides json_escape)
if [[ -f "${LIB_DIR}/common.sh" ]]; then
    source "${LIB_DIR}/common.sh"
else
    # Minimal json_escape fallback if common.sh not available
    json_escape() {
        local str="$1"
        str="${str//\\/\\\\}"
        str="${str//\"/\\\"}"
        echo "$str"
    }
fi

# Verify jq is available (required for registry operations)
if ! command -v jq &>/dev/null; then
    echo '{"status":"error","message":"jq is required but not installed"}' >&2
    exit 0  # Exit gracefully, don't block session
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

# Security: Validate registry is not a symlink (prevent symlink attack)
if [[ -L "$REGISTRY" ]]; then
    echo '{"status":"error","message":"Registry file is a symlink, refusing to write"}' >&2
    exit 1
fi

# Initialize registry if needed
if [[ ! -f "$REGISTRY" ]]; then
    # Ensure parent directory exists
    mkdir -p "$(dirname "$REGISTRY")"
    echo '{"sessions": {}}' > "$REGISTRY"
fi

# Check if session already registered (using --arg to prevent jq injection)
EXISTING=$(jq -r --arg sid "$SESSION_ID" '.sessions[$sid] // empty' "$REGISTRY" 2>/dev/null || echo "")
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

# Register session name (using --arg to prevent jq injection)
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT
if jq --arg sid "$SESSION_ID" --arg name "$SESSION_NAME" '.sessions[$sid] = $name' "$REGISTRY" > "$TMP_FILE" 2>/dev/null; then
    # Security: Final symlink check before overwrite
    if [[ -L "$REGISTRY" ]]; then
        echo '{"status":"error","message":"Registry became symlink during operation"}' >&2
        exit 1
    fi
    mv "$TMP_FILE" "$REGISTRY"
fi

# Output for MAOS session tracking (escape user-controlled values)
cat << OUTPUT
{
  "status": "success",
  "action": "session_named",
  "session_id": "$(json_escape "$SESSION_ID")",
  "session_name": "$(json_escape "$SESSION_NAME")",
  "is_worktree": $([ -n "$WORKTREE" ] && echo "true" || echo "false")
}
OUTPUT

exit 0
