#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance Library: seed-io.sh
# Purpose: Shared continuation-seed I/O for the worktree-lifecycle SAVE-side hooks
#   (postflight-precompact.sh writes the skeleton; postflight-postcompact.sh merges
#   the harness compact_summary). Both target the SAME cross-session seed file in the
#   COMMON git-dir — several sessions/worktrees of one repo share it — so writes MUST be
#   lock-serialized + atomic, and BOTH producers MUST resolve the identical path.
#   Sourced best-effort; a caller that cannot source it degrades safely (the precompact
#   falls back to a lockless skeleton write; the postcompact no-ops its merge).
# Version: 1.0.0
# Protocol: C04 (Git Worktree), C06 (AI-Native)
# ═══════════════════════════════════════════════════════════════════════════════

# Prevent multiple sourcing (mirrors common.sh — return BEFORE any readonly re-declare).
[[ -n "${_MAOS_SEED_IO_LOADED:-}" ]] && return 0
readonly _MAOS_SEED_IO_LOADED=1

# seed_dir <repo> → absolute dir that holds the seed file.
#   Honors POSTFLIGHT_SEED_DIR (override). Else the per-worktree absolute git-dir + /maos —
#   INTENTIONALLY `--absolute-git-dir` (NOT --git-common-dir) so this agrees byte-for-byte with
#   the existing precompact producer (postflight-precompact.sh) and preflight's FIRST reader
#   probe; a session's precompact-write and postcompact-merge thus land on the same file, and
#   the 199 existing seeds keep their location (zero migration).
seed_dir() {
  local repo="$1" gd
  if [ -n "${POSTFLIGHT_SEED_DIR:-}" ]; then printf '%s' "$POSTFLIGHT_SEED_DIR"; return 0; fi
  gd="$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null || echo "${repo}/.git")"
  printf '%s/maos' "$gd"
}

# seed_is_rich <file> → 0 (true) if the seed is a rich synthesis, 1 otherwise.
#   Rich = params.kind == "rich-synthesis" OR (defensive, for pre-1.3 rich seeds that predate
#   the `kind` enum) the presence of params.goal / params.mission. This gate IS the upgrade-only
#   LYNCHPIN: the skeleton PreCompact producer calls `seed_is_rich || seed_write_atomic`, so a
#   FALSE "not rich" verdict CLOBBERS a rich /maos:postflight seed (irreversible synthesis loss).
#   With jq → authoritative. Without jq → grep fallback keyed on the literal marker P3 always
#   writes (`"kind": "rich-synthesis"`) + the pre-1.3 `"goal"`/`"mission"` keys. A rich seed
#   reliably MATCHES that grep, so it is preserved; a skeleton matches nothing, so the (cheap)
#   refresh proceeds. (Prior behavior returned "not rich" whenever jq was absent — which silently
#   clobbered rich seeds in any jq-less env; jq is NOT guaranteed at PreCompact time even though
#   the reader side needs it, so the destroy could still happen before any reader existed.)
seed_is_rich() {
  local f="$1"
  [ -f "$f" ] || return 1
  if command -v jq >/dev/null 2>&1; then
    jq -e '(.params.kind == "rich-synthesis") or ((.params.goal // .params.mission) != null)' \
      "$f" >/dev/null 2>&1
    return
  fi
  # jq-absent fallback — bias toward PRESERVE (a false positive only skips a cheap skeleton
  # refresh; a false negative destroys the synthesis). Grep's exit IS the verdict.
  grep -Eq '"kind"[[:space:]]*:[[:space:]]*"rich-synthesis"|"(goal|mission)"[[:space:]]*:' "$f" 2>/dev/null
}

# seed_lock <dir> → acquire "$dir/.lock-seed" (mkdir-lock + epoch-marker stale reclaim, bounded
#   spin ~3s). Returns 0 if acquired, 1 if it GAVE UP — the caller MUST then skip the write and
#   move on (NEVER block a compaction/never-blocks hook). Idiom mirrors bin/dogfood-mark:
#   POSIX-atomic mkdir; a writer killed by an uncatchable SIGKILL leaves the lock, reclaimed via
#   a numeric-guarded epoch marker + POSIX-atomic `mv` (only one racer wins the rename).
seed_lock() {
  local d="$1" lock="$1/.lock-seed" stale=30 i=0 now lock_ts dead
  mkdir -p "$d" 2>/dev/null || true
  while ! mkdir "$lock" 2>/dev/null; do
    if [ -f "$lock/ts" ]; then
      lock_ts=$(cat "$lock/ts" 2>/dev/null || echo 0); case "$lock_ts" in ''|*[!0-9]*) lock_ts=0 ;; esac
      now=$(date +%s 2>/dev/null || echo 0);           case "$now"     in ''|*[!0-9]*) now=0 ;; esac
      if [ "$((now - lock_ts))" -gt "$stale" ]; then
        dead="$lock.stale.$$"
        mv "$lock" "$dead" 2>/dev/null && rm -rf "$dead" 2>/dev/null || true
        continue
      fi
    fi
    i=$((i + 1)); [ "$i" -ge 30 ] && return 1   # ~3s → give up (a hook must never hang)
    sleep 0.1
  done
  date +%s > "$lock/ts" 2>/dev/null || true
  _SEED_LOCK_HELD="$lock"
  return 0
}

# seed_unlock → release the lock acquired by the most recent seed_lock (idempotent).
seed_unlock() {
  [ -n "${_SEED_LOCK_HELD:-}" ] || return 0
  rm -f "${_SEED_LOCK_HELD}/ts" 2>/dev/null || true
  rmdir "${_SEED_LOCK_HELD}" 2>/dev/null || true
  _SEED_LOCK_HELD=""
}

# seed_write_atomic <file> <content> → tmp→mv atomic write (a partial file is never observed).
#   Returns 0 on success, 1 on failure (caller decides; a hook swallows failure + exits 0).
seed_write_atomic() {
  local f="$1" content="$2" tmp="$1.tmp.$$"
  if printf '%s\n' "$content" > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$f" 2>/dev/null && return 0
    rm -f "$tmp" 2>/dev/null || true
    return 1
  fi
  return 1
}
