#!/usr/bin/env bash
# Tests for bin/check-layer-purity when no organization patterns are configured.
# Run: bash bin/tests/check-layer-purity.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BIN="$DIR/../check-layer-purity"

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  \xe2\x9c\x93 %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \xe2\x9c\x97 %s\n      got: [%s]\n' "$1" "$2"; }
has()  { case "$2" in *"$1"*) ok "$3" ;; *) no "$3" "$2" ;; esac; }
hasnt(){ case "$2" in *"$1"*) no "$3" "$2" ;; *) ok "$3" ;; esac; }
eq()   { [ "$1" = "$2" ] && ok "$3" || no "$3" "got=[$2] want=[$1]"; }

printf 'check-layer-purity.test.sh\n'

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t lp)"
trap 'rm -rf "$TMP"' EXIT
printf 'neutral sample\n' > "$TMP/clean.txt"
printf '%s\n' '# comment only' > "$TMP/comments.txt"
printf '%s\n' 'no-such-token' > "$TMP/patterns.txt"
printf '%s\n' '{"pull_request":{"head":{"repo":{"fork":true}}}}' > "$TMP/fork.json"
printf '%s\n' '{"pull_request":{"head":{"repo":{"fork":false}}}}' > "$TMP/same.json"

# Isolate from a developer patterns file and from ambient CI.
base_env() {
  env -u MAOS_LAYER_PURITY_PATTERNS -u CI -u GITHUB_ACTIONS \
    -u GITHUB_EVENT_NAME -u GITHUB_EVENT_PATH \
    MAOS_LAYER_PURITY_PATTERNS_FILE="$TMP/absent.txt" \
    "$@"
}

o="$(base_env bash "$BIN" "$TMP/clean.txt" 2>&1)"; rc=$?
eq "0" "$rc" "local: no patterns configured exits 0"
has "no patterns configured" "$o" "local: no patterns configured prints an explicit warning"
has "warning:" "$o" "local: the warning is explicit"

o="$(base_env env MAOS_LAYER_PURITY_PATTERNS_FILE="$TMP/comments.txt" bash "$BIN" "$TMP/clean.txt" 2>&1)"; rc=$?
eq "0" "$rc" "local: comment-only patterns file is not configured"
has "no patterns configured" "$o" "local: comment-only file still warns"

o="$(base_env env CI=true bash "$BIN" "$TMP/clean.txt" 2>&1)"; rc=$?
eq "1" "$rc" "CI: no patterns configured fails"
has "no patterns configured" "$o" "CI: failure message says no patterns configured"
hasnt "Layer Purity clean" "$o" "CI: does not claim a clean pass"

o="$(base_env env CI=true GITHUB_ACTIONS=true GITHUB_EVENT_NAME=pull_request \
  GITHUB_EVENT_PATH="$TMP/fork.json" bash "$BIN" "$TMP/clean.txt" 2>&1)"; rc=$?
eq "0" "$rc" "fork pull request: no patterns configured does not fail"
has "::warning::" "$o" "fork pull request: emits an explicit ::warning::"
has "skipped" "$o" "fork pull request: warning says the check was skipped"
hasnt "Layer Purity clean" "$o" "fork pull request: skip is not reported as a clean scan"

o="$(base_env env CI=true GITHUB_ACTIONS=true GITHUB_EVENT_NAME=pull_request \
  GITHUB_EVENT_PATH="$TMP/same.json" bash "$BIN" "$TMP/clean.txt" 2>&1)"; rc=$?
eq "1" "$rc" "same-repo pull request: no patterns configured still fails"
has "no patterns configured" "$o" "same-repo pull request: failure message is explicit"

o="$(base_env env MAOS_LAYER_PURITY_PATTERNS='no-such-token' bash "$BIN" "$TMP/clean.txt" 2>&1)"; rc=$?
eq "0" "$rc" "configured env patterns: scan exits 0 on a clean file"
hasnt "no patterns configured" "$o" "configured env patterns: no unconfigured warning"

o="$(base_env env MAOS_LAYER_PURITY_PATTERNS_FILE="$TMP/patterns.txt" bash "$BIN" "$TMP/clean.txt" 2>&1)"; rc=$?
eq "0" "$rc" "configured patterns file: scan exits 0 on a clean file"
hasnt "no patterns configured" "$o" "configured patterns file: no unconfigured warning"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
