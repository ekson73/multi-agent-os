#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance Library: worktree-utils.sh
# Purpose: Git worktree detection and validation utilities
# Version: 1.0.0
# Protocol: C04 (Git Worktree Protocol v2.0)
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_MAOS_WORKTREE_UTILS_LOADED:-}" ]] && return 0
readonly _MAOS_WORKTREE_UTILS_LOADED=1

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# =============================================================================
# WORKTREE DETECTION
# =============================================================================

# /**
#  * Check if current directory is inside a git worktree (not main repo)
#  * @return 0 if in worktree, 1 if in main repo, 2 if not in git repo
#  */
is_in_worktree() {
    local git_dir
    local git_common_dir
    local toplevel

    # Check if we're in a git repo at all
    toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || return 2
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || return 2
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || return 2

    # In a worktree, .git is a file (not directory) pointing to the real .git
    if [[ -f "${toplevel}/.git" ]]; then
        return 0  # In worktree
    fi

    # Alternative check: git-dir differs from git-common-dir
    if [[ "$git_dir" != "$git_common_dir" ]]; then
        return 0  # In worktree
    fi

    return 1  # In main working directory
}

# /**
#  * Check if current directory is in the main working directory (not worktree)
#  * @return 0 if in main repo, 1 otherwise
#  */
is_in_main_repo() {
    local toplevel
    local git_dir

    toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || return 1

    # Main repo has .git as directory
    [[ -d "${toplevel}/.git" ]] && [[ "$git_dir" == ".git" ]]
}

# =============================================================================
# BRANCH DETECTION
# =============================================================================

# /**
#  * Get current branch name
#  * @return Branch name or empty string
#  */
get_current_branch() {
    git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
}

# /**
#  * Check if current branch is protected (main/master)
#  * @return 0 if protected, 1 otherwise
#  */
is_protected_branch() {
    local branch
    branch=$(get_current_branch)
    [[ "$branch" =~ $PROTECTED_BRANCHES ]]
}

# =============================================================================
# COMMAND DETECTION
# =============================================================================

# /**
#  * Check if command is a branch creation command
#  * @param command  The git command to check
#  * @return 0 if branch creation, 1 otherwise
#  */
is_branch_creation() {
    local command="$1"

    # Match: git checkout -b, git switch -c, git branch <name>
    [[ "$command" =~ git[[:space:]]+checkout[[:space:]]+-b ]] ||
    [[ "$command" =~ git[[:space:]]+switch[[:space:]]+-c ]] ||
    [[ "$command" =~ git[[:space:]]+branch[[:space:]]+[^-] ]]
}

# /**
#  * Check if command is a checkout/switch command (not creating)
#  * @param command  The git command to check
#  * @return 0 if checkout, 1 otherwise
#  */
is_checkout_command() {
    local command="$1"

    # Match checkout/switch without -b/-c (not creation)
    if [[ "$command" =~ git[[:space:]]+(checkout|switch)[[:space:]]+ ]]; then
        # Exclude branch creation
        ! is_branch_creation "$command"
        return $?
    fi
    return 1
}

# /**
#  * Check if command is a commit command
#  * @param command  The git command to check
#  * @return 0 if commit, 1 otherwise
#  */
is_commit_command() {
    local command="$1"
    [[ "$command" =~ git[[:space:]]+commit ]]
}

# /**
#  * Extract branch name from branch creation command
#  * @param command  The git command
#  * @return Branch name or "unknown"
#  */
extract_branch_name() {
    local command="$1"
    local branch=""

    # Try to extract from -b/-c flag
    if [[ "$command" =~ (-b|-c)[[:space:]]+([^[:space:]]+) ]]; then
        branch="${BASH_REMATCH[2]}"
    # Try to extract from 'git branch <name>'
    elif [[ "$command" =~ git[[:space:]]+branch[[:space:]]+([^-][^[:space:]]*) ]]; then
        branch="${BASH_REMATCH[1]}"
    fi

    echo "${branch:-unknown}"
}

# /**
#  * Extract checkout target from checkout command
#  * @param command  The git command
#  * @return Target branch/ref or "unknown"
#  */
extract_checkout_target() {
    local command="$1"
    local target=""

    # Extract last argument (typically the branch name)
    if [[ "$command" =~ git[[:space:]]+(checkout|switch)[[:space:]]+([^[:space:]]+)$ ]]; then
        target="${BASH_REMATCH[2]}"
    fi

    echo "${target:-unknown}"
}

# =============================================================================
# WORKTREE INFO
# =============================================================================

# /**
#  * Get worktree name from path
#  * @param path  Optional path (defaults to pwd)
#  * @return Worktree name or empty
#  */
get_worktree_name() {
    local path="${1:-$(pwd)}"

    if [[ "$path" =~ \.worktrees/([^/]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

# /**
#  * Get main repo path from worktree
#  * @return Main repo path or current toplevel
#  */
get_main_repo_path() {
    local git_common_dir
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || return 1

    # git-common-dir returns path to main .git
    dirname "$git_common_dir"
}
