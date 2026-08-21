#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance Library: seed-io.sh
# Purpose: Shared continuation-seed I/O for the worktree-lifecycle SAVE-side hooks
#   (postflight-precompact.sh writes the skeleton; postflight-postcompact.sh merges
#   the harness compact_summary). Both target the SAME seed file in the PER-WORKTREE
#   absolute git-dir (intentional — see seed_dir(); the reload reader additionally
#   probes the common git-dir) — concurrent sessions of one checkout share it, so
#   writes MUST be lock-serialized + atomic, and BOTH producers MUST resolve the
#   identical path.
#   Sourced best-effort; a caller that cannot source it degrades safely (the precompact
#   falls back to a lockless skeleton write; the postcompact no-ops its merge).
# Version: 1.1.2
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

# seed_active_world <repo> → "personal" | "work" | "unknown" — the Two-Worlds boundary
#   (continuation-seed-contract.md v1.4.0 `active_world`). Parses the `origin` remote's
#   GitHub org against a VERIFIED identity map (multi-identity-git-ssh-governance.md §0.5).
#   NEVER guesses: any org that does not positively match yields "unknown" — never a silent
#   default to "personal" (that would assign a credential-boundary classification with no
#   evidence, exactly the failure this contract's Best-practice #2 forbids). Pure/read-only;
#   safe to call from a hook that must never block (no network, plain string parsing).
seed_active_world() {
  local repo="$1" remote org
  # `git remote get-url` EXPANDS this machine's own `url.<x>.insteadOf` rewrites by default —
  # so a personal repo cloned the normal way (`git@github.com:ekson73/X.git`) reports back as
  # the operator's OWN personal-identity SSH alias `git@github.com-ekson73:ekson73/X.git`
  # (multi-identity-git-ssh-governance.md §3.3's blessed zero-friction routing). Caught live by
  # this file's own regression test (tests/governance/test-postflight-active-world.sh) against
  # a synthetic repo — the v1.1.1 pattern only matched the vanilla host and silently fell to
  # "unknown" for that alias. `github.com-vek-im` is deliberately NOT special-cased: that rule
  # marks it "LEGACY … residual personal GH leftovers only — never present it to vek-im/*", so
  # trusting it as a `work` signal would itself be an unverified guess; it correctly falls
  # through to "unknown" below.
  remote="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
  # Anchored, not "contains github.com anywhere": require the remote to literally START with
  # a genuine github.com SSH/HTTPS form, OR the operator's own personal-identity SSH alias
  # above. An unanchored `.*github\.com.*` match (the v1.1.0 first draft) could be fooled by a
  # non-GitHub host that merely CONTAINS the substring somewhere in its path/query — fail-closed
  # instead (`unknown`).
  case "$remote" in
    git@github.com:*/*|https://github.com/*/*|http://github.com/*/*|git@github.com-ekson73:*/*) : ;;
    *) printf 'unknown'; return 0 ;;
  esac
  org="$(printf '%s' "$remote" | sed -E 's#^(git@github\.com:|git@github\.com-ekson73:|https?://github\.com/)([^/]+)/.*#\2#')"
  # GitHub ORG is the verified unit (not repo-name prefixes — those (vks-/vkl-/vek-) all live
  # under the SAME `vek-im` org per multi-identity-git-ssh-governance.md §0.5). Bitbucket-only
  # legacy orgs (e.g. vek-servicos) are intentionally NOT matched here (this parser is
  # github.com-specific) — they fall through to "unknown", never guessed.
  case "$org" in
    ekson73) printf 'personal' ;;
    vek-im)  printf 'work' ;;
    *)       printf 'unknown' ;;
  esac
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
