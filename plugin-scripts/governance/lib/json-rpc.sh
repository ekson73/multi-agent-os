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

    # Detect git provider: SCM_PROVIDER env var takes precedence, then URL pattern matching.
    # URL matching uses broad patterns (*github*, *bitbucket*, *gitlab*) to cover
    # both public SaaS (github.com) and enterprise/self-hosted instances (github.mycompany.com).
    local remote_url provider scm_hostname create_pr_cmd view_comments_cmd post_comment_cmd
    remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "unknown")

    # Extract hostname from remote URL (supports both https and git@host:org/repo formats)
    scm_hostname=$(echo "$remote_url" | sed -E 's|https?://([^/:]+).*|\1|; s|git@([^:]+):.*|\1|' 2>/dev/null || echo "")

    # Provider resolution: explicit env var > URL pattern
    if [[ -n "${SCM_PROVIDER:-}" ]]; then
        provider="$SCM_PROVIDER"
    elif [[ "$remote_url" == *"github"* ]]; then
        provider="github"
    elif [[ "$remote_url" == *"bitbucket"* ]]; then
        provider="bitbucket"
    elif [[ "$remote_url" == *"gitlab"* ]]; then
        provider="gitlab"
    else
        provider="other"
    fi

    # Enterprise host flags: only added when hostname differs from the public SaaS host
    local gh_flag="" glab_flag=""
    [[ "$provider" == "github"    && "$scm_hostname" != "github.com"    && -n "$scm_hostname" ]] && gh_flag=" --hostname $scm_hostname"
    [[ "$provider" == "gitlab"    && "$scm_hostname" != "gitlab.com"    && -n "$scm_hostname" ]] && glab_flag=" --server https://$scm_hostname"

    case "$provider" in
        github)
            create_pr_cmd="gh pr create${gh_flag} --title \"<title>\" --body \"<body>\""
            view_comments_cmd="gh pr view${gh_flag} <number> --json comments,reviews"
            post_comment_cmd="gh pr comment${gh_flag} <number> --body \"<message>\""
            ;;
        bitbucket)
            create_pr_cmd='MCP atlassian_bitbucket({resource:"pull_request", operation:"create", params:{...}}) (or BB REST API)'
            view_comments_cmd='MCP atlassian_bitbucket({resource:"pull_request", operation:"get" | "get_comments"}) (or BB REST API)'
            post_comment_cmd='MCP atlassian_bitbucket or BB REST API to post a PR comment'
            ;;
        gitlab)
            create_pr_cmd="glab mr create${glab_flag} --title \"<title>\" --description \"<body>\""
            view_comments_cmd="glab mr view${glab_flag} <number> --comments"
            post_comment_cmd="glab mr comment${glab_flag} <number> --message \"<message>\""
            ;;
        *)
            create_pr_cmd='use the provider CLI, MCP tool, or REST API to open a PR'
            view_comments_cmd='use the provider CLI, MCP tool, or REST API to list PR comments'
            post_comment_cmd='use the provider CLI, MCP tool, or REST API to post a PR comment'
            ;;
    esac

    # Note: unquoted <<INSTRUCTIONS so provider variables expand correctly.
    # Angle-bracket placeholders (<feature>, <title>) are not shell variables and are unaffected.
    local instructions
    instructions="$(cat <<INSTRUCTIONS
MANDATORY WORKFLOW (do not skip any step):

1. CREATE WORKTREE + FEATURE BRANCH:
   git worktree add .worktrees/<feature> -b <type>/<feature>
   Then work inside the worktree directory.

2. COMMIT + PUSH inside the worktree:
   git add <files> && git commit -m "<type>(<scope>): <description>"
   git push -u origin <branch>

3. CREATE PULL REQUEST (MANDATORY — no direct merge allowed):
   $create_pr_cmd

4. CHECK REVIEW BOT COMMENTS (MANDATORY — do not skip):
   After PR is created, poll for automated review comments (CodeRabbitAI,
   Copilot, Qodo, Dependabot, etc.). Poll every 60s (bots take 1-3 min).
   $view_comments_cmd

   For EACH bot comment/suggestion:
   a) ACCEPT + IMPLEMENT: apply the fix -> commit -> push (PR updates automatically)
   b) REJECT: post a reply on the PR with the technical reason for rejection
      $post_comment_cmd

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
