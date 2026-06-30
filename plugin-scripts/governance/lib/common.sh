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
    local audit_dir="${CLAUDE_AUDIT_DIR:-}"
    local session_id="${CLAUDE_SESSION_ID:-unknown}"

    # HOME-safe under `set -u`: only fall back to ~/.claude/audit when HOME is
    # set; otherwise no-op (an unbound $HOME must never abort a `set -u` caller).
    if [[ -z "$audit_dir" ]]; then
        [[ -n "${HOME:-}" ]] || return 0
        audit_dir="${HOME}/.claude/audit"
    fi

    if [[ -d "$audit_dir" ]]; then
        local log_file="${audit_dir}/governance_$(date +%Y%m%d).jsonl"
        # Escape event and session_id for valid JSON
        printf '{"timestamp":"%s","event":"%s","session":"%s","data":%s}\n' \
            "$(get_timestamp)" "$(json_escape "$event")" "$(json_escape "$session_id")" "$data" >> "$log_file"
    fi
}

# =============================================================================
# STRING UTILITIES
# =============================================================================

# Escape string for JSON (handles common control characters)
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Extract value from JSON using jq or fallback
#
# IMPORTANT: The fallback (when jq is absent) only supports top-level paths
# like '.field'. Nested paths like '.parent.child' silently return empty.
# For hooks using nested paths, call require_jq() at script top to fail-fast.
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
# JQ DEPENDENCY ENFORCEMENT
# Governance hooks MUST have jq available. The fallback in json_get is
# top-level-only and cannot reliably parse nested paths. Call require_jq
# at the top of any hook that uses json_get with nested paths.
#
# Emits a valid JSON object on stdout (preserving the hook contract that
# upstream agents consume stdout) plus a human-readable message on stderr,
# then exits with EXIT_ERROR (C06 contract — not shell's 127).
# =============================================================================
require_jq() {
    if ! command -v jq &>/dev/null; then
        # JSON on stdout — keeps the hook contract intact for upstream agents
        printf '{"decision":"allow","reason":"governance-hook: jq not available — hook degraded to no-op. Install jq (brew install jq / apt-get install jq). Base image jdxcode/mise:latest ships jq by default."}\n'
        # Human-readable on stderr
        echo "ERROR: jq is required for governance hooks but was not found." >&2
        echo "Install: brew install jq (macOS) / apt-get install jq (Debian/Ubuntu)" >&2
        echo "Base image jdxcode/mise:latest ships jq by default." >&2
        exit "$EXIT_ERROR"
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
