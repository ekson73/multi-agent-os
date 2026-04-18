#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance: worktree-gate.sh
# Purpose: Unified gatekeeper for git worktree protocol enforcement
# Version: 1.0.0
# Protocol: C04 (Git Worktree Protocol v2.0), C06 (AI-Native Environment)
#
# Enforces:
#   RF01: Block branch creation outside worktree
#   RF02: Block checkout in main repo
#   RF03: Block commits to main/master branches
#
# Exit Codes:
#   0 = Allow (command proceeds)
#   2 = Block (command prevented)
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source libraries
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/json-rpc.sh"
source "${LIB_DIR}/worktree-utils.sh"

# Enforce jq as hard requirement — worktree-gate uses json_get with nested
# paths (.tool_input.command) that the fallback cannot parse reliably.
require_jq

# =============================================================================
# MAIN GATE LOGIC
# =============================================================================

# Read tool input from stdin (Claude passes JSON)
TOOL_INPUT=$(cat)

# Extract command from tool input
COMMAND=$(json_get "$TOOL_INPUT" '.tool_input.command')

# Early exit if no command or not a git command
if [[ -z "$COMMAND" ]] || [[ ! "$COMMAND" =~ ^git[[:space:]] ]]; then
    exit "$EXIT_SUCCESS"
fi

# Check for bypass flag
if has_bypass_flag "$COMMAND"; then
    log_audit "bypass_used" "{\"command\":\"$(json_escape "$COMMAND")\"}"
    # Output warning but allow
    if is_interactive; then
        echo "⚠️  MAOS: Bypass flag detected. Proceeding with worktree policy override." >&2
    fi
    exit "$EXIT_SUCCESS"
fi

# =============================================================================
# RF01: BRANCH CREATION GATE
# =============================================================================

if is_branch_creation "$COMMAND"; then
    if is_in_main_repo; then
        BRANCH_NAME=$(extract_branch_name "$COMMAND")

        # Log blocked action (escape all user-controlled values)
        log_audit "branch_blocked" "{\"branch\":\"$(json_escape "$BRANCH_NAME")\",\"command\":\"$(json_escape "$COMMAND")\"}"

        # Emit JSON-RPC error (always, for AI agent)
        error_branch_blocked "$BRANCH_NAME" "$COMMAND"

        # Also emit human-readable if interactive
        if is_interactive; then
            human_error \
                "Branch Creation Blocked" \
                "Cannot create branch '${BRANCH_NAME}' in main working directory." \
                "git worktree add .worktrees/${BRANCH_NAME} -b ${BRANCH_NAME}"
        fi

        exit "$EXIT_BLOCKED"
    fi
fi

# =============================================================================
# RF02: CHECKOUT GATE
# =============================================================================

if is_checkout_command "$COMMAND"; then
    if is_in_main_repo; then
        TARGET=$(extract_checkout_target "$COMMAND")

        # Log blocked action (escape all user-controlled values)
        log_audit "checkout_blocked" "{\"target\":\"$(json_escape "$TARGET")\",\"command\":\"$(json_escape "$COMMAND")\"}"

        # Emit JSON-RPC error
        error_checkout_blocked "$TARGET" "$COMMAND"

        # Human-readable output
        if is_interactive; then
            human_error \
                "Checkout Blocked" \
                "Cannot checkout '${TARGET}' in main working directory." \
                "git worktree add .worktrees/${TARGET} ${TARGET}"
        fi

        exit "$EXIT_BLOCKED"
    fi
fi

# =============================================================================
# RF03: COMMIT ON PROTECTED BRANCH GATE
# =============================================================================

if is_commit_command "$COMMAND"; then
    CURRENT_BRANCH=$(get_current_branch)

    if [[ "$CURRENT_BRANCH" =~ $PROTECTED_BRANCHES ]]; then
        # Log blocked action (escape all user-controlled values)
        log_audit "commit_blocked" "{\"branch\":\"$(json_escape "$CURRENT_BRANCH")\",\"command\":\"$(json_escape "$COMMAND")\"}"

        # Emit JSON-RPC error
        error_commit_blocked "$CURRENT_BRANCH" "$COMMAND"

        # Human-readable output
        if is_interactive; then
            human_error \
                "Commit Blocked" \
                "Cannot commit directly to '${CURRENT_BRANCH}' branch." \
                "Create a feature branch: git worktree add .worktrees/feature -b feature/your-change"
        fi

        exit "$EXIT_BLOCKED"
    fi
fi

# =============================================================================
# ALLOW COMMAND
# =============================================================================

exit "$EXIT_SUCCESS"
