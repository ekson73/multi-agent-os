#!/usr/bin/env bash
# /**
#  * reap-sessions.sh — safely prune STALE/ORPHAN git worktrees + merged orphan branches.
#  * @context  work-compass DETECTS stale/orphan; nothing REAPS. This closes the anti-theater loop.
#  * @reason   abandoned worktrees/branches accumulate in shared repos; manual cleanup never happens.
#  * @impact   dry-run DEFAULT · NEVER --force · NEVER -D · NEVER touches WIP or the main worktree ·
#  *           idempotent · good-neighbor (defers on index.lock) · session transcripts out of scope.
#  * @usage    reap-sessions.sh [--repo-dir DIR] [--stale-days N] [--apply] [--json]
#  * Stdlib + git only. AAIF cross-vendor. Layer-pure (no akasha/Vek deps). bash 3.2 safe. LF.
#  */
set -euo pipefail

REPO_DIR="$PWD"; STALE_DAYS=7; APPLY=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-dir)   REPO_DIR="$2"; shift 2;;
    --stale-days) STALE_DAYS="$2"; shift 2;;
    --apply)      APPLY=1; shift;;
    --json)       JSON=1; shift;;
    -h|--help)    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "reap-sessions: unknown arg: $1" >&2; exit 2;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "reap-sessions: git not available" >&2; exit 1; }
git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "reap-sessions: not a git repo: $REPO_DIR" >&2; exit 1; }

# ── good-neighbor: defer if a peer holds the index lock (never fight a concurrent writer) ──
COMMON="$(cd "$REPO_DIR" && git rev-parse --git-common-dir)"
case "$COMMON" in /*) ;; *) COMMON="$REPO_DIR/$COMMON";; esac
if [ -e "$COMMON/index.lock" ]; then
  if [ "$JSON" -eq 1 ]; then
    printf '{"deferred":true,"busy":true,"reason":"index.lock present — peer mutating; reaper yields"}\n'
  else
    echo "reap-sessions: defer — $COMMON/index.lock present (peer mutating); yielding (good-neighbor)"
  fi
  exit 0
fi

MAIN_TOP="$(git -C "$REPO_DIR" rev-parse --show-toplevel)"
NOW="$(date +%s)"
DEFAULT_BRANCH="$(git -C "$REPO_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
[ -n "$DEFAULT_BRANCH" ] || DEFAULT_BRANCH="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)"

reaped_wt=(); skipped_wip=(); would_wt=(); reaped_br=(); would_br=()

# ── worktrees: eligible = (detached/orphan) OR (last-commit age > stale-days); reaped only if CLEAN ──
emit_wt() {
  local p="$1" b="$2" det="$3"
  [ -n "$p" ] || return 0
  [ "$p" = "$MAIN_TOP" ] && return 0          # NEVER the main worktree
  [ -d "$p" ] || return 0                      # admin-stale entry → handled by `worktree prune`
  local ts age elig=0 reason=""
  ts="$(git -C "$p" log -1 --format=%ct 2>/dev/null || echo 0)"
  age=$(( (NOW - ts) / 86400 ))
  if [ "$det" -eq 1 ] || [ -z "$b" ]; then elig=1; reason="orphan-detached"; fi
  if [ "$age" -gt "$STALE_DAYS" ]; then elig=1; reason="${reason:+$reason,}stale-${age}d"; fi
  [ "$elig" -eq 1 ] || return 0
  if [ -n "$(git -C "$p" status --porcelain 2>/dev/null)" ]; then   # WIP guard — never reap dirty
    skipped_wip+=("$p"); return 0
  fi
  if [ "$APPLY" -eq 0 ]; then would_wt+=("$p ($reason)"); return 0; fi
  if git -C "$REPO_DIR" worktree remove "$p" >/dev/null 2>&1; then   # NO --force (belt-and-suspenders)
    reaped_wt+=("$p")
  else
    skipped_wip+=("$p")   # remove refused (e.g. became dirty mid-run) → keep, never force
  fi
}
_wp=""; _wb=""; _wd=0
while IFS= read -r line; do
  case "$line" in
    "worktree "*) [ -n "$_wp" ] && emit_wt "$_wp" "$_wb" "$_wd"; _wp="${line#worktree }"; _wb=""; _wd=0;;
    "branch "*)   _wb="${line#branch }"; _wb="${_wb#refs/heads/}";;
    "detached")   _wd=1;;
  esac
done < <(git -C "$REPO_DIR" worktree list --porcelain)
[ -n "$_wp" ] && emit_wt "$_wp" "$_wb" "$_wd"

[ "$APPLY" -eq 1 ] && git -C "$REPO_DIR" worktree prune >/dev/null 2>&1 || true

# ── branches: merged into default, not protected, not checked-out anywhere → safe `-d` ──
used_branches="$(git -C "$REPO_DIR" worktree list --porcelain | sed -n 's#^branch refs/heads/##p')"
while IFS= read -r b; do
  [ -n "$b" ] || continue
  case "$b" in main|master|develop) continue;; esac
  printf '%s\n' "$used_branches" | grep -qxF "$b" && continue
  if [ "$APPLY" -eq 0 ]; then would_br+=("$b"); continue; fi
  git -C "$REPO_DIR" branch -d "$b" >/dev/null 2>&1 && reaped_br+=("$b") || true   # -d refuses unmerged
done < <(git -C "$REPO_DIR" branch --merged "$DEFAULT_BRANCH" --format='%(refname:short)')

# ── output ──
jarr() {  # bash-3.2-safe JSON array from "$@"
  [ "$#" -eq 0 ] && { printf '[]'; return; }
  local out="" x; for x in "$@"; do out="$out\"$x\","; done; printf '[%s]' "${out%,}"
}
if [ "$JSON" -eq 1 ]; then
  printf '{"dry_run":%s,"repo":"%s","stale_days":%s,"reaped_worktrees":%s,"skipped_wip":%s,"would_reap_worktrees":%s,"reaped_branches":%s,"would_reap_branches":%s}\n' \
    "$([ "$APPLY" -eq 0 ] && echo true || echo false)" "$MAIN_TOP" "$STALE_DAYS" \
    "$(jarr "${reaped_wt[@]+"${reaped_wt[@]}"}")" \
    "$(jarr "${skipped_wip[@]+"${skipped_wip[@]}"}")" \
    "$(jarr "${would_wt[@]+"${would_wt[@]}"}")" \
    "$(jarr "${reaped_br[@]+"${reaped_br[@]}"}")" \
    "$(jarr "${would_br[@]+"${would_br[@]}"}")"
else
  echo "reap-sessions ($([ "$APPLY" -eq 0 ] && echo DRY-RUN || echo APPLY)) repo=$MAIN_TOP stale>${STALE_DAYS}d"
  if [ "$APPLY" -eq 0 ]; then
    printf '  would reap worktrees: %s\n' "${would_wt[*]:-(none)}"
    printf '  would reap branches : %s\n' "${would_br[*]:-(none)}"
    printf '  skip (WIP)          : %s\n' "${skipped_wip[*]:-(none)}"
    echo   "  → re-run with --apply to execute (WIP + main always preserved)"
  else
    printf '  reaped worktrees: %s\n' "${reaped_wt[*]:-(none)}"
    printf '  reaped branches : %s\n' "${reaped_br[*]:-(none)}"
    printf '  skip (WIP)      : %s\n' "${skipped_wip[*]:-(none)}"
  fi
fi
