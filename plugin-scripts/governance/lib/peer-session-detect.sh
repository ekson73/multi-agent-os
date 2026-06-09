#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance Library: peer-session-detect.sh
# Purpose: OPTIONAL, capability-detected detection of OTHER live agent sessions
#          (peers) working in the SAME git checkout — the cross-session layer of
#          the `preflight` bootstrap bundle. Lets a session-start hook DEFER the
#          R2 heal/pull while a peer is actively writing the same working tree
#          (avoid interfering with other agents/sessions/threads). Composes WITH
#          the pure-git libs (git-branch-detect.sh, git-safe-sync.sh) at the
#          orchestration layer; it is deliberately NOT named `git-*` because it
#          is a HOST-concurrency signal, not a git primitive (git-safe-sync.sh
#          explicitly excludes host-specific session signals — this lib is where
#          they live, kept separate so the pure-git libs stay pure).
# Version: 1.0.0
# Protocol: C04 (Git Worktree Protocol v2.0), C06 (AI-Native Environment)
#
# Capability-detected + graceful degradation (vendor-neutral):
#   The peer signal is a host's agent-session activity. ONE optional backend ships:
#   agent-session transcript files (`<session-id>.jsonl`) keyed by the repo's
#   working-tree path, whose mtime within a freshness window = "live". When no
#   backend resolves (host writes no such transcripts, OR the dir can't be found),
#   detection returns UNKNOWN — callers MUST treat UNKNOWN as "cannot tell → do
#   NOT over-defer" (report-only). So off-host (Cursor/Codex/Copilot/Aider) the
#   tool stays useful: git-native protections (worktree-locks, index.lock) remain.
#
# Scope = SAME checkout (this working tree's path). Peers in OTHER worktrees are a
#   DIFFERENT working tree on a git-LOCKED branch → already covered by R1
#   (gbd_locked_branches). This lib closes the complementary gap: TWO sessions in
#   the SAME cwd on the SAME branch — which index.lock only catches at the instant
#   of a write. Honest limitation: a peer that started in a SUBDIR of the repo
#   (cwd != toplevel) may not be seen; the override seam MAOS_PEER_SESSION_DIR
#   handles that, and missing a peer only means fewer defers — never a false block.
#
# Safety: READ-ONLY. Never mutates refs/index/worktree. Never blocks (the caller
#   decides to DEFER, never to fail). Self-excludes the current session.
#
# Env seams (production defaults shown):
#   MAOS_PEER_SESSION_DIR    explicit session-transcript dir for THIS repo
#                            (the portability seam; overrides auto-resolution)
#   MAOS_PEER_PROJECTS_DIR   transcripts root for auto-resolution (default
#                            $HOME/.claude/projects)
#   MAOS_PEER_FRESH_SECS     "live" window in seconds (default 90)
#   MAOS_SELF_SESSION_ID     own session id to exclude (default: $CLAUDE_CODE_SESSION_ID)
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${_MAOS_PEER_SESSION_DETECT_LOADED:-}" ]] && return 0
readonly _MAOS_PEER_SESSION_DETECT_LOADED=1

# Self-sufficient: portable epoch mtime (GNU stat -c first, BSD/macOS stat -f fallback).
# (No common.sh dependency — this lib is a pure, dependency-free detector, matching
#  the dependency-free shape of its detection logic; logging lives at the hook layer.)
psd_mtime() { stat -c '%Y' "$1" 2>/dev/null || stat -f '%m' "$1" 2>/dev/null || echo 0; }

# /**
#  * Encode an absolute path the way the agent host keys its per-project session dir.
#  * Mirrors the convention "replace every non-alphanumeric char with '-'", e.g.
#  *   /Users/x/Projects/repo  ->  -Users-x-Projects-repo
#  * @param abspath  Absolute path
#  */
_psd_encode_path() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

# /**
#  * Resolve THIS repo's peer-session transcript dir (capability-detected).
#  * Echoes the dir on success; returns 1 (no echo) when no backend resolves.
#  * Order: explicit MAOS_PEER_SESSION_DIR seam → auto (projects-root + encoded
#  * working-tree toplevel). Auto returns 1 unless the encoded dir actually exists
#  * (never guesses a non-existent dir → UNKNOWN instead of a wrong count).
#  * @param repo  Optional repo/worktree dir (default ".")
#  */
psd_session_dir() {
    local repo="${1:-.}" top projects enc dir
    # Explicit override seam (vendor-neutral; the portability point).
    if [ -n "${MAOS_PEER_SESSION_DIR:-}" ]; then
        [ -d "$MAOS_PEER_SESSION_DIR" ] && { printf '%s\n' "$MAOS_PEER_SESSION_DIR"; return 0; }
        return 1
    fi
    # Auto backend: transcripts keyed by this working tree's toplevel abs path.
    top="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || return 1
    # ${HOME:-} guard: never trip `set -u` if HOME is unset (cron/minimal env) →
    # unresolved projects dir → return 1 (UNKNOWN), preserving the never-blocks contract.
    projects="${MAOS_PEER_PROJECTS_DIR:-${HOME:-}/.claude/projects}"
    [ -d "$projects" ] || return 1
    enc="$(_psd_encode_path "$top")"
    dir="$projects/$enc"
    [ -d "$dir" ] && { printf '%s\n' "$dir"; return 0; }
    return 1
}

# /**
#  * Count OTHER live peer sessions writing THIS repo's working tree, within the
#  * freshness window, excluding this session. Echoes an integer, or "UNKNOWN" when
#  * no detector backend resolves (off-host, or the dir can't be found). READ-ONLY.
#  * @param repo  Optional repo dir (default ".")
#  */
psd_peer_sessions() {
    local repo="${1:-.}" dir fresh own now n=0 f base sid m
    dir="$(psd_session_dir "$repo")" || { printf 'UNKNOWN\n'; return 0; }
    fresh="${MAOS_PEER_FRESH_SECS:-90}"
    # Coerce to a non-negative integer; a non-numeric value (e.g. "90s") must not
    # break the `-le` arithmetic under `set -e`. Fall back to the default.
    case "$fresh" in ''|*[!0-9]*) fresh=90 ;; esac
    own="${MAOS_SELF_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"
    now="$(date +%s 2>/dev/null || echo 0)"
    [ "$now" -gt 0 ] 2>/dev/null || { printf 'UNKNOWN\n'; return 0; }
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        base="$(basename "$f")"; sid="${base%.jsonl}"
        [ -n "$own" ] && [ "$sid" = "$own" ] && continue
        m="$(psd_mtime "$f")"; [ "$m" = "0" ] && continue
        [ "$((now - m))" -le "$fresh" ] && n=$((n + 1))
    done <<EOF
$(find "$dir" -maxdepth 1 -name '*.jsonl' -type f 2>/dev/null)
EOF
    printf '%s\n' "$n"
}

# /**
#  * Orchestration-layer status string (what preflight composes against).
#  * @return one of:  BUSY_PEERS <n>  |  QUIET  |  UNKNOWN
#  * @param repo  Optional repo dir (default ".")
#  */
psd_status() {
    local repo="${1:-.}" p
    p="$(psd_peer_sessions "$repo")"
    case "$p" in
        UNKNOWN)  printf 'UNKNOWN\n' ;;
        0)        printf 'QUIET\n' ;;
        *[!0-9]*) printf 'UNKNOWN\n' ;;   # defensive: non-numeric, non-UNKNOWN
        *)        printf 'BUSY_PEERS %s\n' "$p" ;;
    esac
}

# /**
#  * Convenience predicate for callers that prefer exit codes.
#  * @return 0 = BUSY (peers active → DEFER) | 1 = QUIET | 2 = UNKNOWN
#  * @param repo  Optional repo dir (default ".")
#  */
psd_repo_busy_by_peers() {
    local repo="${1:-.}" s
    s="$(psd_status "$repo")"
    case "$s" in
        BUSY_PEERS*) return 0 ;;
        QUIET)       return 1 ;;
        *)           return 2 ;;
    esac
}

# ── direct-execution guard (library — sourcing is the contract) ────────────────
if [ "${BASH_SOURCE[0]:-}" = "${0:-}" ]; then
    printf 'peer-session-detect.sh is a library — source it, do not execute.\n' >&2
    printf 'Exposes: psd_peer_sessions <repo> · psd_status <repo> · psd_repo_busy_by_peers <repo>\n' >&2
    # Convenience: when run directly, print a one-line live read of the cwd repo.
    printf 'state: %s\n' "$(psd_status "${1:-.}")"
    exit 0
fi
