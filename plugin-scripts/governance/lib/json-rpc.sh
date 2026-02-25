#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance Library: json-rpc.sh
# Purpose: MCP-JSON-RPC error emission helpers (C06 compliant)
# Version: 1.0.0
# Protocol: C06 (AI-Native Environment)
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_MAOS_JSONRPC_LOADED:-}" ]] && return 0
readonly _MAOS_JSONRPC_LOADED=1

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# =============================================================================
# JSON-RPC ERROR EMITTERS
# =============================================================================

# /**
#  * Emit MCP-JSON-RPC error to stderr
#  * @param code      Error code (e.g., -32000)
#  * @param message   Human-readable error message
#  * @param hook      Hook identifier (e.g., "PreToolUse:Bash")
#  * @param instructions  Recovery action for AI agent
#  * @param extra_data    Additional JSON object (optional)
#  */
json_error() {
    local code="$1"
    local message="$2"
    local hook="${3:-PreToolUse:Bash}"
    local instructions="${4:-}"
    local extra_data="${5:-}"

    local request_id
    request_id=$(generate_request_id)

    local timestamp
    timestamp=$(get_timestamp)

    # Build data object
    local data_json="{\"hook\":\"${hook}\",\"timestamp\":\"${timestamp}\""

    if [[ -n "$instructions" ]]; then
        data_json+=",\"instructions\":\"$(json_escape "$instructions")\""
    fi

    if [[ -n "$extra_data" ]]; then
        # Merge extra data (assumes it's valid JSON without outer braces)
        data_json+=",${extra_data}"
    fi

    data_json+="}"

    # Emit to stderr (C06: JSON errors to stderr)
    cat >&2 <<EOF
{
  "jsonrpc": "2.0",
  "error": {
    "code": ${code},
    "message": "$(json_escape "$message")",
    "data": ${data_json}
  },
  "id": "${request_id}"
}
EOF
}

# =============================================================================
# SPECIALIZED ERROR EMITTERS
# =============================================================================

# Emit commit blocked error (-32000)
error_commit_blocked() {
    local branch="$1"
    local command="${2:-git commit}"

    # Escape all user-controlled values for valid JSON
    local extra="\"branch\":\"$(json_escape "$branch")\",\"action\":\"$(json_escape "$command")\",\"protocol\":\"C04 - Git Worktree Protocol\""

    local instructions
    # Note: unquoted <<INSTRUCTIONS delimiter (not <<'INSTRUCTIONS') is intentional.
    # Apostrophes inside $(cat <<'...') break bash $() parsing (treated as string delimiters).
    # Content has no shell variables to expand, so unquoted delimiter is safe and equivalent.
    instructions="$(cat <<INSTRUCTIONS
MANDATORY WORKFLOW (do not skip any step):

1. CREATE WORKTREE + FEATURE BRANCH:
   git worktree add .worktrees/<feature> -b <type>/<feature>
   Then work inside the worktree directory.

2. COMMIT + PUSH inside the worktree:
   git add <files> && git commit -m "<type>(<scope>): <description>"
   git push -u origin <branch>

3. CREATE PULL REQUEST (MANDATORY — no direct merge allowed):
   Detect the git provider from the remote URL, then use the appropriate tool:
   - GitHub    (github.com):    gh pr create --title "..." --body "..."
   - Bitbucket (bitbucket.org): MCP bitbucket_create_pull_request, or BB REST API
   - GitLab    (gitlab.com):    glab mr create --title "..." --description "..."
   - Other:                     use the provider CLI, MCP tool, or REST API

4. CHECK REVIEW BOT COMMENTS (MANDATORY — do not skip):
   After PR is created, poll for automated review comments (CodeRabbitAI,
   Copilot, Qodo, Dependabot, etc.) using the provider tool.
   Poll every 60s — bots typically take 1-3 minutes to complete.
   - GitHub:    gh pr view <number> --json comments,reviews
   - Bitbucket: MCP bitbucket_get_pr_details or bitbucket_get_pull_requests
   - GitLab:    glab mr view <number> --comments
   - Other:     use the provider CLI, MCP tool, or REST API

   For EACH bot comment/suggestion:
   a) ACCEPT + IMPLEMENT: apply the fix -> commit -> push (PR updates automatically)
   b) REJECT: post a reply on the PR with the technical reason for rejection
      - GitHub:    gh pr comment <number> --body "Rejected: <reason>"
      - Bitbucket: MCP or REST API to post a PR comment
      - GitLab:    glab mr comment <number> --message "Rejected: <reason>"

5. MERGE only after: PR reviewed + all accepted items implemented + rejections documented.
INSTRUCTIONS
)"

    json_error \
        "$ERR_COMMIT_BLOCKED" \
        "Direct commits to $(json_escape "$branch") branch are not allowed" \
        "PreToolUse:Bash" \
        "$instructions" \
        "$extra"
}

# Emit branch creation blocked error (-32001)
error_branch_blocked() {
    local branch_name="$1"
    local command="$2"

    # Escape all user-controlled values for valid JSON
    local extra="\"branch\":\"$(json_escape "$branch_name")\",\"command\":\"$(json_escape "$command")\",\"protocol\":\"C04 - Git Worktree Protocol v2.0\""

    json_error \
        "$ERR_BRANCH_BLOCKED" \
        "Branch creation in main working directory is not allowed. Use git-worktree instead (C04)" \
        "PreToolUse:Bash" \
        "git worktree add .worktrees/${branch_name} -b ${branch_name}" \
        "$extra"
}

# Emit checkout blocked error (-32002)
error_checkout_blocked() {
    local target="$1"
    local command="$2"

    # Escape all user-controlled values for valid JSON
    local extra="\"target\":\"$(json_escape "$target")\",\"command\":\"$(json_escape "$command")\",\"protocol\":\"C04 - Git Worktree Protocol v2.0\""

    json_error \
        "$ERR_CHECKOUT_BLOCKED" \
        "Checkout in main working directory is not allowed. Use git-worktree for isolation (C04)" \
        "PreToolUse:Bash" \
        "git worktree add .worktrees/${target} ${target}" \
        "$extra"
}

# =============================================================================
# HUMAN-READABLE OUTPUT
# =============================================================================

# Print human-readable error message (for non-JSON mode)
human_error() {
    local title="$1"
    local message="$2"
    local suggestion="${3:-}"

    echo "═══════════════════════════════════════════════════════════════════" >&2
    echo "⛔ MAOS GOVERNANCE: ${title}" >&2
    echo "═══════════════════════════════════════════════════════════════════" >&2
    echo "" >&2
    echo "  ${message}" >&2
    echo "" >&2
    if [[ -n "$suggestion" ]]; then
        echo "  💡 Suggestion: ${suggestion}" >&2
        echo "" >&2
    fi
    echo "  📖 Protocol: C04 - Git Worktree Protocol v2.0" >&2
    echo "  📖 Documentation: ~/.claude/CLAUDE.md [C04]" >&2
    echo "═══════════════════════════════════════════════════════════════════" >&2
}
