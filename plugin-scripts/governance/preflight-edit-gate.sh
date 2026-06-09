#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance: preflight-edit-gate.sh
# Purpose: R3 of the `preflight` bundle — the mutation-gated worktree safety-net.
#   Fires on PreToolUse:Edit|Write|MultiEdit. When the agent is about to
#   create/update a file in the MAIN checkout (not a worktree), it recommends
#   isolating the work in a git worktree first (per C04). WARN by default
#   (surfaces guidance, never blocks); hard-block is opt-in.
# Version: 1.0.0
# Protocol: C04 (Git Worktree Protocol v2.0), C06 (AI-Native Environment)
#
# Mode: PREFLIGHT_EDIT_GATE=warn (default) → exit 0 + additionalContext guidance.
#       PREFLIGHT_EDIT_GATE=block          → exit 2 + JSON-RPC error (-32003).
# Bypass (matches the repo convention): --force-no-worktree / --maos-bypass in env
#       PREFLIGHT_EDIT_GATE=off            → disabled entirely.
# Exempt (never warns): files under a `.worktrees/` dir; append-only coordination
#       files (tasks.md, sessions.json) per C04 exception; non-git / outside-repo.
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/json-rpc.sh"
source "${LIB_DIR}/worktree-utils.sh"

# Disabled entirely?
[ "${PREFLIGHT_EDIT_GATE:-warn}" = "off" ] && exit "$EXIT_SUCCESS"

# Nested json path → jq is a hard requirement here (fail-safe handled by require_jq).
require_jq

TOOL_INPUT=$(cat)
FILE_PATH=$(json_get "$TOOL_INPUT" '.tool_input.file_path')

# No file path (nothing to gate) → allow.
[ -z "$FILE_PATH" ] && exit "$EXIT_SUCCESS"

# File inside a worktree → already isolated → allow.
case "$FILE_PATH" in */.worktrees/*) exit "$EXIT_SUCCESS" ;; esac

# Append-only coordination files (C04 exception) → allow.
case "$(basename "$FILE_PATH")" in tasks.md|sessions.json) exit "$EXIT_SUCCESS" ;; esac

# Not in a git repo, or in a worktree (cwd) → allow. Only the MAIN checkout warns.
if ! is_in_main_repo; then
    exit "$EXIT_SUCCESS"
fi

# Only gate files that actually live inside this (main) repo's toplevel.
TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$TOPLEVEL" ]; then
    case "$FILE_PATH" in
        "$TOPLEVEL"/*) : ;;          # inside the main checkout → gate it
        /*) exit "$EXIT_SUCCESS" ;;   # absolute path outside the repo → not our concern
    esac
fi

BRANCH=$(get_current_branch)
SLUG=$(basename "$FILE_PATH" | tr '.' '-')
SUGGEST="git worktree add .worktrees/${SLUG} -b <type>/<scope>   # then edit inside the worktree (or run /maos:preflight)"

case "${PREFLIGHT_EDIT_GATE:-warn}" in
    block)
        log_audit "preflight_edit_blocked" "{\"file\":\"$(json_escape "$FILE_PATH")\",\"branch\":\"$(json_escape "$BRANCH")\"}" || true
        json_error \
            "-32003" \
            "Editing files in the main working directory is discouraged. Isolate in a git worktree first (C04)." \
            "PreToolUse:Edit" \
            "$SUGGEST" \
            "\"file\":\"$(json_escape "$FILE_PATH")\",\"branch\":\"$(json_escape "$BRANCH")\",\"protocol\":\"C04 - Git Worktree Protocol v2.0\""
        if is_interactive; then
            human_error "Edit in Main Checkout Blocked" \
                "About to modify '${FILE_PATH}' in the main checkout on '${BRANCH}'." "$SUGGEST"
        fi
        exit "$EXIT_BLOCKED"
        ;;
    *)
        # WARN (default): surface guidance to the agent, do NOT block.
        log_audit "preflight_edit_warn" "{\"file\":\"$(json_escape "$FILE_PATH")\",\"branch\":\"$(json_escape "$BRANCH")\"}" || true
        CTX="preflight: about to modify '${FILE_PATH}' in the MAIN checkout on '${BRANCH}' (not a worktree). Per C04, isolate file changes in a worktree: ${SUGGEST}. (Exempt: .worktrees/* edits, tasks.md/sessions.json. Set PREFLIGHT_EDIT_GATE=off to silence, =block to enforce.)"
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$(json_escape "$CTX")"
        exit "$EXIT_SUCCESS"
        ;;
esac
