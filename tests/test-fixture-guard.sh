#!/usr/bin/env bash
# Regression for #495: simulated allocation / mkdir / directory-entry failures and an
# inherited GIT_DIR must stop a fixture BEFORE any git mutation, leaving the caller's
# checkout (HEAD, tree, config) unchanged. No real storage is exhausted: failures are
# simulated with a PATH shim, a regular file as parent, and a removed directory.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$HERE/lib/fixture-guard.sh"

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_NAMESPACE GIT_ALTERNATE_OBJECT_DIRECTORIES
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

SBX="$(mktemp -d)" || { echo "FAIL: mktemp"; exit 1; }
[ -n "$SBX" ] && [ -d "$SBX" ] || { echo "FAIL: sandbox"; exit 1; }
trap 'rm -rf "$SBX"' EXIT

# The "caller checkout" a broken fixture would damage.
OUTER="$SBX/outer"; mkdir -p "$OUTER"
git -C "$OUTER" init -q -b main; echo o > "$OUTER/o"; git -C "$OUTER" add o; git -C "$OUTER" commit -qm outer
snap() { printf '%s|%s|%s' "$(git -C "$OUTER" rev-parse HEAD)" "$(git -C "$OUTER" status --porcelain)" "$(git -C "$OUTER" config --local --list | sort | tr '\n' ';')"; }
BASE="$(snap)"

PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }
unchanged() { [ "$(snap)" = "$BASE" ] && ok "$1: outer unchanged" || { bad "$1: outer MUTATED"; BASE="$(snap)"; }; }

# Guarded fixture body, run from inside the outer checkout. $1 = fixture dir ("" = allocate).
guarded() {
  ( cd "$OUTER" || exit 9
    # shellcheck source=/dev/null
    source "$GUARD"
    fx_reject_git_env || exit 3
    d="${1:-}"
    if [ -z "$d" ]; then d="$(fx_mktemp_dir)" || exit 3; fi
    fx_enter_fresh "$d" && git init -q && fx_assert_root "$d" \
      && git config user.email fixture@x && echo f > f && git add f && git commit -qm fixture \
      || exit 3
    printf '%s' "$d" ) 2>/dev/null
}

mkdir -p "$SBX/shim-fail" "$SBX/shim-empty"
printf '#!/bin/sh\nexit 1\n' > "$SBX/shim-fail/mktemp"; chmod +x "$SBX/shim-fail/mktemp"
printf '#!/bin/sh\nexit 0\n' > "$SBX/shim-empty/mktemp"; chmod +x "$SBX/shim-empty/mktemp"

# Control: the naive pattern really does damage the caller on an empty allocation.
( cd "$OUTER" && d="$(PATH="$SBX/shim-empty:$PATH" mktemp -d)"; ( cd "$d" && git config fixture.naive yes ) ) 2>/dev/null
[ "$(git -C "$OUTER" config --local fixture.naive 2>/dev/null)" = yes ] \
  && ok "control: naive cd \"\" pattern mutates the caller (hazard is real)" \
  || bad "control: naive pattern did not reproduce"
git -C "$OUTER" config --local --unset fixture.naive 2>/dev/null; BASE="$(snap)"

PATH="$SBX/shim-fail:$PATH"  guarded "" >/dev/null; [ $? -ne 0 ] && ok "mktemp failure stops" || bad "mktemp failure ran"; unchanged "mktemp failure"
PATH="$SBX/shim-empty:$PATH" guarded "" >/dev/null; [ $? -ne 0 ] && ok "empty mktemp stops"   || bad "empty mktemp ran";   unchanged "empty mktemp"

touch "$SBX/afile"
( source "$GUARD"; fx_mkdir "$SBX/afile/sub" ) 2>/dev/null && bad "mkdir under a file succeeded" || ok "mkdir failure detected"
guarded "$SBX/afile/sub" >/dev/null; [ $? -ne 0 ] && ok "missing dir entry stops" || bad "missing dir ran"; unchanged "mkdir failure"

mkdir -p "$SBX/gone"; rmdir "$SBX/gone"
guarded "$SBX/gone" >/dev/null; [ $? -ne 0 ] && ok "removed dir stops" || bad "removed dir ran"; unchanged "dir-entry failure"

GIT_DIR="$OUTER/.git" guarded "" >/dev/null; [ $? -ne 0 ] && ok "inherited GIT_DIR rejected" || bad "inherited GIT_DIR ran"; unchanged "inherited GIT_DIR"

mkdir -p "$OUTER/nested"; BASE="$(snap)"
guarded "$OUTER/nested" >/dev/null; [ $? -ne 0 ] && ok "fixture dir inside caller repo stops" || bad "nested fixture ran"
[ ! -e "$OUTER/nested/.git" ] && ok "no nested repo created in caller" || bad "nested repo created"; unchanged "nested fixture"
rmdir "$OUTER/nested"; BASE="$(snap)"

# Positive control: a healthy fixture gets its own repo with one commit.
d="$(guarded "")"; rc=$?
if [ $rc -eq 0 ] && [ -n "$d" ] && [ "$(git -C "$d" rev-list --count HEAD)" = 1 ]; then ok "positive control: disposable fixture created"; rm -rf "$d"
else bad "positive control failed (rc=$rc)"; fi
unchanged "positive control"

echo "fixture-guard: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
