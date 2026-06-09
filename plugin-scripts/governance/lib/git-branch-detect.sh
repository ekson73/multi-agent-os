#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance Library: git-branch-detect.sh
# Purpose: Read-only branch/upstream/divergence/worktree-lock/tree-state detection
#          (R1 of the `preflight` bootstrap bundle). Pure git primitives — no
#          mutation, no host-specific signals (vendor-neutral / Layer-Pure).
# Version: 1.0.0
# Protocol: C04 (Git Worktree Protocol v2.0), C06 (AI-Native Environment)
#
# All functions are READ-ONLY. They never write to the index, refs, or worktree.
# Composes worktree-utils.sh (get_current_branch/is_in_worktree) where useful;
# implements the divergence + worktree-lock + tree-state primitives it lacks.
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_MAOS_GIT_BRANCH_DETECT_LOADED:-}" ]] && return 0
readonly _MAOS_GIT_BRANCH_DETECT_LOADED=1

# Source common utilities + worktree detection (idempotent guards inside)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/worktree-utils.sh"

# =============================================================================
# BRANCH / UPSTREAM / DIVERGENCE  (all read-only)
# =============================================================================

# /**
#  * Current branch name, or "detached@<short-sha>" when HEAD is detached.
#  * @param repo  Optional repo/worktree dir (default ".")
#  */
gbd_current_branch() {
    local repo="${1:-.}" b
    if b=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null); then
        echo "$b"
    else
        echo "detached@$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    fi
}

# /**
#  * Upstream tracking ref (e.g. origin/main), or "none" if unset.
#  * @param repo  Optional repo dir (default ".")
#  */
gbd_upstream() {
    local repo="${1:-.}"
    git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo "none"
}

# /**
#  * Commits the local branch is AHEAD of its upstream (HEAD not in @{u}).
#  * Echoes an integer, or "?" when no upstream / not computable.
#  */
gbd_ahead() {
    local repo="${1:-.}"
    git -C "$repo" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo "?"
}

# /**
#  * Commits the local branch is BEHIND its upstream (@{u} not in HEAD).
#  * Echoes an integer, or "?" when no upstream / not computable.
#  */
gbd_behind() {
    local repo="${1:-.}"
    git -C "$repo" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo "?"
}

# =============================================================================
# WORKTREE LOCK  (a branch checked out in ANOTHER worktree is git-locked)
# =============================================================================

# /**
#  * Branches currently checked out in OTHER worktrees (one per line).
#  * These are LOCKED by git — they cannot be checked out here. Read-only.
#  * @param repo  Optional repo dir (default ".")
#  */
gbd_locked_branches() {
    local repo="${1:-.}" self wt="" br=""
    self=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null) || return 0
    # Parse porcelain records; emit branch of every worktree that is not `self`.
    git -C "$repo" worktree list --porcelain 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            "worktree "*) wt="${line#worktree }"; br="" ;;
            "branch "*)
                br="${line#branch refs/heads/}"
                [ "$wt" != "$self" ] && [ -n "$br" ] && echo "$br"
                ;;
        esac
    done
}

# /**
#  * Is branch <target> checked out in another worktree (and thus locked)?
#  * @param target  Branch name to test
#  * @param repo    Optional repo dir (default ".")
#  * @return 0 if locked elsewhere, 1 otherwise
#  */
gbd_is_locked_elsewhere() {
    local target="$1" repo="${2:-.}"
    gbd_locked_branches "$repo" | grep -qxF "$target"
}

# =============================================================================
# WORKING-TREE STATE  (worktree-safe via git rev-parse --git-path)
# =============================================================================

# /**
#  * Classify HEAD + working-tree state (read-only). Most-blocking wins.
#  * @return one of: DETACHED | MID_REBASE | MID_MERGE | DIRTY | CLEAN
#  *   DIRTY  = uncommitted TRACKED changes (untracked-only stays CLEAN — safe to ff).
#  * @param repo  Optional repo dir (default ".")
#  */
gbd_tree_state() {
    local repo="${1:-.}" p
    # Detached HEAD
    git -C "$repo" symbolic-ref --quiet HEAD >/dev/null 2>&1 || { echo "DETACHED"; return 0; }
    # Mid-rebase (handles both rebase-merge and rebase-apply backends, worktree-safe)
    p=$(git -C "$repo" rev-parse --git-path rebase-merge 2>/dev/null); [ -n "$p" ] && [ -d "$p" ] && { echo "MID_REBASE"; return 0; }
    p=$(git -C "$repo" rev-parse --git-path rebase-apply 2>/dev/null); [ -n "$p" ] && [ -d "$p" ] && { echo "MID_REBASE"; return 0; }
    # Mid-merge / mid-cherry-pick|revert
    p=$(git -C "$repo" rev-parse --git-path MERGE_HEAD 2>/dev/null);  [ -n "$p" ] && [ -f "$p" ] && { echo "MID_MERGE"; return 0; }
    p=$(git -C "$repo" rev-parse --git-path CHERRY_PICK_HEAD 2>/dev/null); [ -n "$p" ] && [ -f "$p" ] && { echo "MID_MERGE"; return 0; }
    # Dirty = any TRACKED change (porcelain line not starting with "??").
    # Untracked-only stays CLEAN (safe to fast-forward). Empty output => CLEAN.
    if [ -n "$(git -C "$repo" status --porcelain 2>/dev/null | grep -vE '^\?\?')" ]; then
        echo "DIRTY"; return 0
    fi
    echo "CLEAN"
}

# =============================================================================
# REPORT  (structured, read-only — KEY=VALUE lines; safe to eval-free parse)
# =============================================================================

# /**
#  * Emit a read-only branch report as KEY=VALUE lines.
#  * @param repo  Optional repo dir (default ".")
#  */
gbd_report() {
    local repo="${1:-.}" cur up ahead behind state locked
    cur=$(gbd_current_branch "$repo")
    up=$(gbd_upstream "$repo")
    if [ "$up" = "none" ]; then ahead="?"; behind="?"; else ahead=$(gbd_ahead "$repo"); behind=$(gbd_behind "$repo"); fi
    state=$(gbd_tree_state "$repo")
    locked=$(gbd_locked_branches "$repo" | tr '\n' ',' | sed 's/,$//')
    printf 'CURRENT_BRANCH=%s\nUPSTREAM=%s\nAHEAD=%s\nBEHIND=%s\nTREE_STATE=%s\nLOCKED_ELSEWHERE=%s\n' \
        "$cur" "$up" "$ahead" "$behind" "$state" "$locked"
}
