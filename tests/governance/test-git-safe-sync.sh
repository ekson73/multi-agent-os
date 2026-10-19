#!/usr/bin/env bash
# Regression: gss_heal (SessionStart R2) must never rebase on its own. A diverged
# branch DEFERs with HEAD and tree unchanged; rebase runs only with
# GSS_ALLOW_REBASE=1 (positive control). Behind-only still fast-forwards.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HERE/../../plugin-scripts/governance/lib/git-safe-sync.sh"

# Fixture isolation: never let an inherited Git location redirect fixture git calls.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_NAMESPACE
SBX="$(mktemp -d)" || { echo "FAIL: mktemp"; exit 1; }
[ -n "$SBX" ] && [ -d "$SBX" ] || { echo "FAIL: sandbox"; exit 1; }
trap 'rm -rf "$SBX"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
g() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }

PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

# shellcheck source=/dev/null
source "$LIB"

mk_pair() { # $1 = name → origin bare + clone with upstream
  g init -q --bare "$SBX/$1.git"
  g clone -q "$SBX/$1.git" "$SBX/$1" 2>/dev/null
  echo a > "$SBX/$1/f"; g -C "$SBX/$1" add f; g -C "$SBX/$1" commit -qm a; g -C "$SBX/$1" push -q origin main 2>/dev/null
  g clone -q "$SBX/$1.git" "$SBX/$1-peer" 2>/dev/null
}
peer_push() { echo "$2" > "$SBX/$1-peer/p"; g -C "$SBX/$1-peer" add p; g -C "$SBX/$1-peer" commit -qm "$2"; g -C "$SBX/$1-peer" push -q origin main 2>/dev/null; }

# 1. diverged, default → DEFERRED, nothing rewritten
mk_pair div; peer_push div up1
echo local > "$SBX/div/l"; g -C "$SBX/div" add l; g -C "$SBX/div" commit -qm local
before="$(g -C "$SBX/div" rev-parse HEAD)"
out="$(gss_heal "$SBX/div")"; rc=$?
after="$(g -C "$SBX/div" rev-parse HEAD)"
case "$out" in "DEFERRED diverged"*) ok "diverged defers: $out" ;; *) bad "diverged verdict: $out" ;; esac
[ "$rc" -ne 0 ] && ok "diverged returns non-zero" || bad "diverged rc=$rc"
[ "$before" = "$after" ] && ok "diverged HEAD unchanged" || bad "diverged HEAD rewritten"
[ ! -e "$SBX/div/p" ] && ok "diverged tree unchanged" || bad "diverged tree changed"

# 2. diverged, explicit opt-in → rebased (positive control)
out="$(GSS_ALLOW_REBASE=1 gss_heal "$SBX/div")"
case "$out" in HEALED_REBASE*) ok "opt-in rebases: $out" ;; *) bad "opt-in verdict: $out" ;; esac

# 3. behind-only → fast-forward still automatic
mk_pair ff; peer_push ff up2
out="$(gss_heal "$SBX/ff")"
case "$out" in HEALED_FF*) ok "behind-only fast-forwards: $out" ;; *) bad "ff verdict: $out" ;; esac

echo "git-safe-sync: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
