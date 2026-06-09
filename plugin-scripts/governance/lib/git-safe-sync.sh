#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance Library: git-safe-sync.sh
# Purpose: Safely heal/harmonize the current branch from its origin (R2 of the
#          `preflight` bootstrap bundle): fetch → classify → act, where "act" is
#          ALWAYS the safe option for the classified state and DEFER otherwise.
# Version: 1.0.0
# Protocol: C04 (Git Worktree Protocol v2.0), C06 (AI-Native Environment)
#
# Safety invariants (never violated):
#   - Never `--force` / `--force-with-lease`.
#   - Never clobber uncommitted TRACKED work → DEFER on a dirty tree.
#   - Never touch a detached / mid-rebase / mid-merge HEAD → DEFER.
#   - Never act while another writer holds `.git/index.lock` → DEFER.
#   - On rebase conflict → `rebase --abort` (restore prior state) → DEFER.
#   - A branch checked out in another worktree is git-locked → not our concern here
#     (the current branch can never be locked elsewhere; gbd_locked_branches reports it).
# Vendor-neutral: pure git + `.git/index.lock`. No host-specific session signals.
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_MAOS_GIT_SAFE_SYNC_LOADED:-}" ]] && return 0
readonly _MAOS_GIT_SAFE_SYNC_LOADED=1

# Source common + branch detection (idempotent guards inside)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/git-branch-detect.sh"

# =============================================================================
# BUSY DETECTION (vendor-neutral: index.lock presence)
# =============================================================================

# /**
#  * Is a concurrent writer holding the git index lock?
#  * Read-only — NEVER removes the lock (a live writer's lock is not ours to steal;
#  * stale-lock recovery is intentionally out of scope — DEFER is the safe answer).
#  * @param repo  Optional repo dir (default ".")
#  * @return 0 if BUSY (lock present), 1 if QUIET
#  */
gss_busy() {
    local repo="${1:-.}" p
    p=$(git -C "$repo" rev-parse --git-path index.lock 2>/dev/null) || return 1
    [ -n "$p" ] && [ -e "$p" ]
}

# =============================================================================
# SAFE HEAL  (fetch → classify → act-safely-or-DEFER)
# =============================================================================

# /**
#  * Heal the current branch from its upstream, safely.
#  * Echoes a single-line verdict; return 0 = resolved (healed/up-to-date/ahead),
#  * return 1 = deferred (caller reports the reason; nothing was clobbered).
#  *
#  * Verdicts (echoed):
#  *   UP_TO_DATE | AHEAD_ONLY <ahead> | HEALED_FF <sha> | HEALED_REBASE <sha>
#  *   DEFERRED <reason>
#  * @param repo  Optional repo dir (default ".")
#  */
gss_heal() {
    local repo="${1:-.}" up remote state ahead behind sha
    # 0. Busy → defer (a live writer holds the index lock)
    if gss_busy "$repo"; then echo "DEFERRED busy(index.lock-held)"; return 1; fi
    # 1. Detached / mid-operation → defer (never sync a mid-op HEAD)
    state=$(gbd_tree_state "$repo")
    case "$state" in
        DETACHED)   echo "DEFERRED detached-HEAD"; return 1 ;;
        MID_REBASE) echo "DEFERRED mid-rebase"; return 1 ;;
        MID_MERGE)  echo "DEFERRED mid-merge"; return 1 ;;
    esac
    # 2. No upstream → nothing to heal from
    up=$(gbd_upstream "$repo")
    [ "$up" = "none" ] && { echo "DEFERRED no-upstream"; return 1; }
    remote="${up%%/*}"
    # 3. Fetch the upstream's remote (read-only; updates remote-tracking refs only)
    git -C "$repo" fetch --quiet "$remote" 2>/dev/null || { echo "DEFERRED fetch-failed($remote)"; return 1; }
    # 4. Dirty tracked tree → defer (never autostash/clobber someone's uncommitted work)
    [ "$(gbd_tree_state "$repo")" = "DIRTY" ] && { echo "DEFERRED dirty(uncommitted-tracked-changes)"; return 1; }
    # 5. Re-evaluate divergence after fetch
    ahead=$(gbd_ahead "$repo"); behind=$(gbd_behind "$repo")
    # Non-numeric (shouldn't happen post-fetch with an upstream) → defer
    case "$ahead$behind" in *[!0-9]*) echo "DEFERRED divergence-unknown"; return 1 ;; esac
    # 6. Act per state
    if [ "$behind" -eq 0 ] && [ "$ahead" -eq 0 ]; then
        echo "UP_TO_DATE"; return 0
    elif [ "$behind" -eq 0 ] && [ "$ahead" -gt 0 ]; then
        echo "AHEAD_ONLY $ahead"; return 0   # local ahead; pushing is not R2's job
    elif [ "$ahead" -eq 0 ] && [ "$behind" -gt 0 ]; then
        # Clean fast-forward
        if git -C "$repo" merge --ff-only --quiet '@{upstream}' 2>/dev/null; then
            sha=$(git -C "$repo" rev-parse --short HEAD 2>/dev/null)
            echo "HEALED_FF $sha"; return 0
        fi
        echo "DEFERRED ff-failed"; return 1
    else
        # Diverged (ahead>0 AND behind>0) → rebase local work onto upstream, autostash-guarded
        if git -C "$repo" rebase --autostash '@{upstream}' >/dev/null 2>&1; then
            sha=$(git -C "$repo" rev-parse --short HEAD 2>/dev/null)
            echo "HEALED_REBASE $sha"; return 0
        fi
        git -C "$repo" rebase --abort >/dev/null 2>&1 || true   # restore prior state
        echo "DEFERRED rebase-conflict(diverged; resolve manually)"; return 1
    fi
}
