#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance Library: common.sh
# Purpose: Shared constants, utilities, and logging functions
# Version: 1.0.0
# Protocol: C04 (Git Worktree), C06 (AI-Native)
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_MAOS_COMMON_LOADED:-}" ]] && return 0
readonly _MAOS_COMMON_LOADED=1

# =============================================================================
# CONSTANTS
# =============================================================================

# Exit codes (C06 compliant)
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_BLOCKED=2  # Hook blocked action

# JSON-RPC error codes (MCP standard)
readonly ERR_COMMIT_BLOCKED=-32000    # Commit on protected branch
readonly ERR_BRANCH_BLOCKED=-32001    # Branch creation in main repo
readonly ERR_CHECKOUT_BLOCKED=-32002  # Checkout in main repo

# Protected branches
readonly PROTECTED_BRANCHES="^(main|master)$"

# Governance version
readonly GOVERNANCE_VERSION="1.0.0"

# =============================================================================
# ENVIRONMENT DETECTION
# =============================================================================

# Check if running in CI/non-interactive mode
is_interactive() {
    [[ -t 0 ]] && [[ -t 1 ]]
}

# Check if JSON output is requested
wants_json() {
    [[ "${MAOS_JSON_OUTPUT:-}" == "true" ]] || [[ "${JSON_OUTPUT:-}" == "true" ]]
}

# =============================================================================
# LOGGING UTILITIES
# =============================================================================

# Generate unique request ID for JSON-RPC
generate_request_id() {
    if command -v uuidgen &>/dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        echo "hook-$(date +%s)-$$"
    fi
}

# Get ISO 8601 timestamp
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Log to audit file (if configured)
log_audit() {
    local event="$1"
    local data="${2:-{}}"
    local audit_dir="${CLAUDE_AUDIT_DIR:-${HOME}/.claude/audit}"
    local session_id="${CLAUDE_SESSION_ID:-unknown}"

    if [[ -d "$audit_dir" ]]; then
        local log_file="${audit_dir}/governance_$(date +%Y%m%d).jsonl"
        printf '{"timestamp":"%s","event":"%s","session":"%s","data":%s}\n' \
            "$(get_timestamp)" "$event" "$session_id" "$data" >> "$log_file"
    fi
}

# =============================================================================
# STRING UTILITIES
# =============================================================================

# Escape string for JSON
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Extract value from JSON using jq or fallback
json_get() {
    local json="$1"
    local path="$2"

    if command -v jq &>/dev/null; then
        echo "$json" | jq -r "$path // empty" 2>/dev/null
    else
        # Fallback: simple grep/sed for basic paths like .field
        local field="${path#.}"
        field="${field%% *}"
        echo "$json" | grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | \
            sed 's/.*"'$field'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1
    fi
}

# =============================================================================
# BYPASS FLAG DETECTION
# =============================================================================

# Check if bypass flag is present in command
has_bypass_flag() {
    local command="$1"
    [[ "$command" =~ --force-no-worktree ]] || [[ "$command" =~ --maos-bypass ]]
}

# Remove bypass flags from command for execution
strip_bypass_flags() {
    local command="$1"
    echo "$command" | sed -E 's/--force-no-worktree//g; s/--maos-bypass//g' | tr -s ' '
}
