#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance: preflight-session.sh
# Purpose: SessionStart bootstrap (R0 + R1 + R2 of the `preflight` bundle).
#   R0 — ticket anchor (ZERO network): which ticket does this session belong to?
#        seed refs.ticket › branch › last-commit (via locus --density anchor). Infers
#        a candidate mode (continuation-candidate | unanchored) + nudges when no anchor.
#   R1 — detect the current branch / upstream / divergence / worktree-locks
#        non-interferingly (read-only).
#   R2 — safely heal the current branch from origin (fetch→classify→ff|rebase|DEFER).
#   R1.5 — (optional, capability-detected) detect OTHER live peer sessions writing
#        this SAME checkout; if any are active, DEFER R2 to avoid interfering.
#   Then inject a concise status as SessionStart additionalContext so the agent
#   wakes up oriented. NEVER blocks the session (always exit 0).
# Version: 1.2.0
# Protocol: C04 (Git Worktree Protocol v2.0), C06 (AI-Native Environment)
#
# Opt-out: PREFLIGHT_NO_AUTOHEAL=1 → report R1 only, do NOT pull (R2 downgraded to
#          a recommendation). Default = heal (per operator directive: heal at
#          session start). Healing is always safe (DEFERs on dirty/diverged/busy/peers).
# Opt-out: PREFLIGHT_NO_TICKET_ANCHOR=1 → skip R0 (no ticket anchor in context).
#          R0 is ZERO-network + deterministic + always degrades gracefully (no jq → grep
#          fallback; no locus → seed-only; no anchor → nudge). Never blocks the session.
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_DIR="$SCRIPT_DIR"   # stable copy — sourced libs below reset SCRIPT_DIR (R0 needs the hook's own dir)
LIB_DIR="${SCRIPT_DIR}/lib"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/git-branch-detect.sh"
source "${LIB_DIR}/git-safe-sync.sh"
# Optional cross-session layer (capability-detected; graceful no-op if absent).
[ -f "${LIB_DIR}/peer-session-detect.sh" ] && source "${LIB_DIR}/peer-session-detect.sh"

# Repo = project dir Claude Code starts in (fallback: cwd). Read-only probe first.
REPO="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Not a git repo → silently do nothing (vendor-neutral, never noisy off-git).
if ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    exit "${EXIT_SUCCESS:-0}"
fi

# ── R0: ticket anchor (ZERO network; deterministic) ───────────────────────────
# "Which ticket does this session belong to?" — seed refs.ticket › branch › last-commit.
# Coarse hook-level mode hint {continuation-candidate | anchored | unanchored}; the
# /maos:preflight skill does the full N-Tree walk + mode/work taxonomy (R0.b/R0.c).
TICKET_ANCHOR=""; TICKET_SRC="none"; SESSION_MODE="unanchored"; TICKET_NUDGE=""
if [ "${PREFLIGHT_NO_TICKET_ANCHOR:-0}" != "1" ]; then
    DEFAULT_TICKET_RE='[A-Z]{2,}-[0-9]+'
    TICKET_RE="${GEO_TICKET_RE:-$DEFAULT_TICKET_RE}"   # two-step: avoid {n,}-brace expansion truncation
    SEED="$REPO/.git/maos/continuation-seed.latest.json"
    # (1) continuation seed refs.ticket — explicit handoff linkage (jq → grep fallback)
    if [ -f "$SEED" ]; then
        if command -v jq >/dev/null 2>&1; then
            TICKET_ANCHOR="$(jq -r '.refs.ticket // .params.refs.ticket // empty' "$SEED" 2>/dev/null | grep -oE "^${TICKET_RE}$" 2>/dev/null | head -1)" || true
        fi
        if [ -z "$TICKET_ANCHOR" ]; then
            TICKET_ANCHOR="$(grep -oE "\"ticket\"[[:space:]]*:[[:space:]]*\"${TICKET_RE}\"" "$SEED" 2>/dev/null | grep -oE "$TICKET_RE" 2>/dev/null | head -1)" || true
        fi
        [ -n "$TICKET_ANCHOR" ] && { TICKET_SRC="seed"; SESSION_MODE="continuation-candidate"; }
    fi
    # (2)+(3) branch › last-commit via locus anchor density (ZERO network)
    if [ -z "$TICKET_ANCHOR" ]; then
        LOCUS="${HOOK_DIR}/../../bin/locus.sh"
        if [ -f "$LOCUS" ]; then
            LOCUS_OUT="$( cd "$REPO" 2>/dev/null && bash "$LOCUS" --density anchor 2>/dev/null )" || true
            case "$LOCUS_OUT" in
                none|'') : ;;
                *) TICKET_ANCHOR="${LOCUS_OUT%% *}"; TICKET_SRC="${LOCUS_OUT##* }"; SESSION_MODE="anchored" ;;
            esac
        fi
    fi
    [ -z "$TICKET_ANCHOR" ] && TICKET_NUDGE=" | No ticket anchor detected (mode=unanchored): run /maos:preflight ticket to walk the N-Tree + classify the session, or proceed (a ticket may be proposed at postflight)."
fi

# ── R1: read-only detection ──────────────────────────────────────────────────
CUR="$(gbd_current_branch "$REPO")"
UP="$(gbd_upstream "$REPO")"
if [ "$UP" = "none" ]; then AHEAD="?"; BEHIND="?"; else AHEAD="$(gbd_ahead "$REPO")"; BEHIND="$(gbd_behind "$REPO")"; fi
STATE="$(gbd_tree_state "$REPO")"
LOCKED="$(gbd_locked_branches "$REPO" | tr '\n' ',' | sed 's/,$//')"

# ── R1.5: cross-session peer detection (optional; capability-detected) ─────────
# UNKNOWN (off-host / dir unresolved) → report-only, never over-defer.
PEERS="unknown"; PEERS_BUSY=0
if command -v psd_status >/dev/null 2>&1; then
    PEER_STATUS="$(psd_status "$REPO" 2>/dev/null || echo UNKNOWN)"
    case "$PEER_STATUS" in
        "BUSY_PEERS "*) PEERS="${PEER_STATUS#BUSY_PEERS }"; PEERS_BUSY=1 ;;
        QUIET)          PEERS="0" ;;
        *)              PEERS="unknown" ;;
    esac
fi

# ── R2: safe heal (default on; opt-out via PREFLIGHT_NO_AUTOHEAL=1) ───────────
if [ "${PREFLIGHT_NO_AUTOHEAL:-0}" = "1" ]; then
    HEAL="SKIPPED (PREFLIGHT_NO_AUTOHEAL=1)"
elif [ "$PEERS_BUSY" = "1" ]; then
    # A peer session is actively writing this checkout → DEFER (never interfere).
    HEAL="DEFERRED peers-active(${PEERS})"
else
    # gss_heal returns non-zero on DEFER; that is a normal, safe outcome — never fail the hook.
    HEAL="$(gss_heal "$REPO" 2>/dev/null || true)"
    [ -z "$HEAL" ] && HEAL="DEFERRED unknown"
fi

# In the main checkout on a protected branch → nudge toward a worktree for mutations.
NUDGE=""
if is_in_main_repo 2>/dev/null && [ -n "$(git -C "$REPO" branch --show-current 2>/dev/null)" ]; then
    case "$CUR" in
        main|master)
            NUDGE=" | In the main checkout on '${CUR}': create a worktree before creating/updating files (/maos:preflight, or git worktree add .worktrees/<slug> -b <type>/<scope>)."
            ;;
    esac
fi

# Audit (no-op unless an audit dir exists).
log_audit "preflight_session" "{\"branch\":\"$(json_escape "$CUR")\",\"upstream\":\"$(json_escape "$UP")\",\"ahead\":\"$(json_escape "$AHEAD")\",\"behind\":\"$(json_escape "$BEHIND")\",\"tree\":\"$(json_escape "$STATE")\",\"peers\":\"$(json_escape "$PEERS")\",\"heal\":\"$(json_escape "$HEAL")\",\"ticket\":\"$(json_escape "${TICKET_ANCHOR:-none}")\",\"ticket_src\":\"$(json_escape "$TICKET_SRC")\",\"mode\":\"$(json_escape "$SESSION_MODE")\"}" || true

# Human summary → stderr (visible, non-blocking).
TICKET_HUMAN="${TICKET_ANCHOR:+ticket=${TICKET_ANCHOR}(${TICKET_SRC}) mode=${SESSION_MODE};}"
echo "🧭 preflight: ${TICKET_HUMAN}branch=${CUR} upstream=${UP} ahead=${AHEAD} behind=${BEHIND} tree=${STATE} peers=${PEERS}; heal=${HEAL}${LOCKED:+; locked-elsewhere=${LOCKED}}" >&2

# Machine context → stdout as SessionStart additionalContext (surfaced to the agent).
TICKET_CTX="${TICKET_ANCHOR:+ ticket=${TICKET_ANCHOR} (source=${TICKET_SRC}, mode=${SESSION_MODE}).}"
CTX="preflight bootstrap —${TICKET_CTX} branch=${CUR}, upstream=${UP}, ahead=${AHEAD}, behind=${BEHIND}, tree-state=${STATE}, peers=${PEERS}, heal=${HEAL}.${LOCKED:+ Branches locked by other worktrees (do NOT switch to them): ${LOCKED}.}${TICKET_NUDGE}${NUDGE}"
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$(json_escape "$CTX")"

exit "${EXIT_SUCCESS:-0}"
