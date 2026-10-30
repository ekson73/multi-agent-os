#!/usr/bin/env bash
# Tests for bin/sync-agentic-tools.sh: a missing source repo is reported, never a silent no-op.
# Run: bash bin/tests/sync-agentic-tools.test.sh
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BIN="$DIR/../sync-agentic-tools.sh"
pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  \xe2\x9c\x93 %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \xe2\x9c\x97 %s\n      got: [%s]\n' "$1" "$2"; }
printf 'sync-agentic-tools.test.sh\n'
TMP="$(mktemp -d 2>/dev/null || mktemp -d -t sat)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home" "$TMP/maos/skills" "$TMP/toolkit/agents"

# Dry-run only (no --apply): it writes nothing outside the sandbox HOME.
run() { env HOME="$TMP/home" MAOS_DIR="$TMP/maos" MAOS_TOOLKIT_DIR="$1" bash "$BIN" 2>&1; }

o="$(run "$TMP/absent-toolkit")"; rc=$?
[ "$rc" -eq 0 ] && ok "missing toolkit: dry-run still exits 0" || no "missing toolkit: dry-run still exits 0" "rc=$rc"
case "$o" in
  *"WARN (source repo not found"*"MAOS_TOOLKIT_DIR"*"$TMP/absent-toolkit"*) ok "missing toolkit: WARN names the variable and the path" ;;
  *) no "missing toolkit: WARN names the variable and the path" "$o" ;;
esac

o="$(run "$TMP/toolkit")"; rc=$?
[ "$rc" -eq 0 ] && ok "present toolkit: dry-run exits 0" || no "present toolkit: dry-run exits 0" "rc=$rc"
case "$o" in
  *"source repo not found"*) no "present toolkit: no missing-repo WARN" "$o" ;;
  *) ok "present toolkit: no missing-repo WARN" ;;
esac

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
