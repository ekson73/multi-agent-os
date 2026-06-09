#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Test: test-peer-session-detect.sh
# Purpose: Unit tests for governance/lib/peer-session-detect.sh (the optional,
#          capability-detected cross-session layer of the preflight bundle).
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/plugin-scripts/governance/lib"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

assert_equals() {
    local expected="$1" actual="$2" name="${3:-assertion}"
    ((TESTS_RUN++)) || true
    if [[ "$expected" == "$actual" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "  ${GREEN}✓${NC} $name"
    else
        ((TESTS_FAILED++)) || true
        echo -e "  ${RED}✗${NC} $name"
        echo "    Expected: $expected"
        echo "    Actual:   $actual"
    fi
}

echo "Testing peer-session-detect.sh..."
echo ""

source "${LIB_DIR}/peer-session-detect.sh"

# Isolate from any real host signal: pin the freshness window + a self id.
export MAOS_PEER_FRESH_SECS=90
export MAOS_SELF_SESSION_ID="self-aaaa"

# ── Capability-detection: no backend resolves → UNKNOWN (graceful degrade) ─────
echo "Capability detection (no backend):"
R="$(MAOS_PEER_SESSION_DIR="/nonexistent/maos/peer/dir-xyz" psd_status .)"
assert_equals "UNKNOWN" "$R" "psd_status: missing session dir → UNKNOWN"

R="$(MAOS_PEER_SESSION_DIR="/nonexistent/maos/peer/dir-xyz" psd_repo_busy_by_peers . && echo 0 || echo $?)"
assert_equals "2" "$R" "psd_repo_busy_by_peers: missing dir → returns 2 (UNKNOWN)"

# ── Detector present: fresh peers counted, self excluded, stale ignored ────────
echo ""
echo "Detector present (synthetic transcript dir):"
TMP="$(mktemp -d 2>/dev/null || mktemp -d -t maospeer)"
trap 'rm -rf "$TMP"' EXIT
export MAOS_PEER_SESSION_DIR="$TMP"

# 2 fresh peers + the current session (excluded) + 1 stale (year 2000)
: > "$TMP/peer-bbbb.jsonl"
: > "$TMP/peer-cccc.jsonl"
: > "$TMP/self-aaaa.jsonl"          # == MAOS_SELF_SESSION_ID → excluded
: > "$TMP/peer-old.jsonl"
touch -t 200001010000 "$TMP/peer-old.jsonl"   # portable stale mtime (BSD + GNU touch)

R="$(psd_peer_sessions .)"
assert_equals "2" "$R" "psd_peer_sessions: counts 2 fresh peers (self + stale excluded)"

R="$(psd_status .)"
assert_equals "BUSY_PEERS 2" "$R" "psd_status: BUSY_PEERS 2"

R="$(psd_repo_busy_by_peers . && echo 0 || echo $?)"
assert_equals "0" "$R" "psd_repo_busy_by_peers: peers active → returns 0 (BUSY)"

# ── Empty dir → 0 peers → QUIET ───────────────────────────────────────────────
echo ""
echo "Empty dir (quiet):"
TMP2="$(mktemp -d 2>/dev/null || mktemp -d -t maospeer2)"
export MAOS_PEER_SESSION_DIR="$TMP2"
R="$(psd_peer_sessions .)"; assert_equals "0" "$R" "psd_peer_sessions: empty dir → 0"
R="$(psd_status .)"; assert_equals "QUIET" "$R" "psd_status: empty dir → QUIET"
R="$(psd_repo_busy_by_peers . && echo 0 || echo $?)"; assert_equals "1" "$R" "psd_repo_busy_by_peers: quiet → returns 1"
rm -rf "$TMP2"

# ── Path encoder ──────────────────────────────────────────────────────────────
echo ""
echo "Path encoder:"
R="$(_psd_encode_path "/Users/x/Projects/repo")"
assert_equals "-Users-x-Projects-repo" "$R" "_psd_encode_path: non-alnum → dash"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Results: ${TESTS_PASSED}/${TESTS_RUN} passed, ${TESTS_FAILED} failed"
echo "═══════════════════════════════════════════════════════════════════"

exit $((TESTS_FAILED > 0 ? 1 : 0))
