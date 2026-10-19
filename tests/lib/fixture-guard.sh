#!/usr/bin/env bash
# fixture-guard.sh — fail closed BEFORE any Git mutation in a disposable test fixture (#495).
#
# A fixture that fails to allocate or enter its directory must never fall through to
# `git init/config/add/commit` in the caller's checkout. Two traps make that easy:
# `cd ""` succeeds in bash (stays put), and errexit is ignored inside `&&` chains and
# conditionals. These helpers return non-zero instead of relying on errexit, so they
# compose in `fx_enter "$d" && git init` chains.
#
#   fx_reject_git_env          inherited GIT_DIR & co. would redirect fixture git calls → fail
#   fx_mktemp_dir              allocate a fresh, physical, absolute temp dir outside any repo
#   fx_mkdir <dir>             mkdir -p, then verify it is a directory
#   fx_enter <dir>             cd into <dir> and verify the physical cwd IS <dir>
#   fx_enter_fresh <dir>       fx_enter, and refuse if <dir> is already inside a repo (pre-init)
#   fx_assert_root <dir>       after `git init`: verify <dir> is its own repo toplevel
#
# Source it; do not execute it.

fx_err() { echo "fixture-guard: $*" >&2; return 1; }

fx_reject_git_env() {
  local v
  for v in GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
           GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE; do
    if [ -n "${!v+x}" ]; then fx_err "refusing to run: inherited $v would redirect fixture git"; return 1; fi
  done
}

fx_phys() { ( cd -P -- "$1" 2>/dev/null && pwd -P ); }

fx_mktemp_dir() {
  local d p
  d="$(mktemp -d 2>/dev/null)" || { fx_err "mktemp -d failed"; return 1; }
  [ -n "$d" ] || { fx_err "mktemp -d returned an empty path"; return 1; }
  [ -d "$d" ] || { fx_err "mktemp -d path is not a directory: $d"; return 1; }
  p="$(fx_phys "$d")" || { fx_err "cannot resolve $d"; return 1; }
  case "$p" in /*) ;; *) fx_err "temp dir is not absolute: $p"; return 1 ;; esac
  if git -C "$p" rev-parse --git-dir >/dev/null 2>&1; then
    fx_err "temp dir $p is inside an existing git repo"; return 1
  fi
  printf '%s\n' "$p"
}

fx_mkdir() {
  [ -n "${1:-}" ] || { fx_err "fx_mkdir: empty path"; return 1; }
  mkdir -p -- "$1" 2>/dev/null && [ -d "$1" ] || { fx_err "mkdir failed: $1"; return 1; }
}

fx_enter() {
  local want
  [ -n "${1:-}" ] || { fx_err "fx_enter: empty path"; return 1; }
  want="$(fx_phys "$1")" || { fx_err "fx_enter: cannot resolve $1"; return 1; }
  cd -P -- "$want" 2>/dev/null || { fx_err "cd failed: $1"; return 1; }
  [ "$(pwd -P)" = "$want" ] || { fx_err "cwd $(pwd -P) is not $want"; return 1; }
}

fx_enter_fresh() {
  fx_enter "${1:-}" || return 1
  if git rev-parse --git-dir >/dev/null 2>&1; then
    fx_err "fixture dir $(pwd -P) is already inside a git repo"; return 1
  fi
}

fx_assert_root() {
  local want top
  want="$(fx_phys "${1:-}")" || { fx_err "fx_assert_root: cannot resolve ${1:-}"; return 1; }
  top="$(git -C "$want" rev-parse --show-toplevel 2>/dev/null)" || { fx_err "not a repo: $want"; return 1; }
  top="$(fx_phys "$top")"
  [ "$top" = "$want" ] || { fx_err "repo toplevel $top is not fixture root $want"; return 1; }
}
