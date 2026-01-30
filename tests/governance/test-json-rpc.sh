#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Test: test-json-rpc.sh
# Purpose: Unit tests for governance/lib/json-rpc.sh
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/plugin-scripts/governance/lib"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test helper
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local name="${3:-assertion}"

    ((TESTS_RUN++)) || true
    if [[ "$haystack" == *"$needle"* ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "  ${GREEN}✓${NC} $name"
    else
        ((TESTS_FAILED++)) || true
        echo -e "  ${RED}✗${NC} $name"
        echo "    Needle: $needle"
        echo "    Haystack: $haystack"
    fi
}

assert_valid_json() {
    local json="$1"
    local name="${2:-JSON valid}"

    ((TESTS_RUN++)) || true
    if echo "$json" | jq . >/dev/null 2>&1; then
        ((TESTS_PASSED++)) || true
        echo -e "  ${GREEN}✓${NC} $name"
    else
        ((TESTS_FAILED++)) || true
        echo -e "  ${RED}✗${NC} $name (invalid JSON)"
    fi
}

# =============================================================================
# TESTS
# =============================================================================

echo "Testing json-rpc.sh..."
echo ""

# Source library
source "${LIB_DIR}/json-rpc.sh"

echo "json_error function:"

# Capture stderr output
ERROR_OUTPUT=$(json_error -32000 "Test error" "TestHook" "Run test" 2>&1)

assert_valid_json "$ERROR_OUTPUT" "json_error produces valid JSON"
assert_contains "$ERROR_OUTPUT" '"jsonrpc": "2.0"' "json_error has jsonrpc field"
assert_contains "$ERROR_OUTPUT" '"code": -32000' "json_error has correct code"
assert_contains "$ERROR_OUTPUT" 'Test error' "json_error has message"
assert_contains "$ERROR_OUTPUT" '"hook":"TestHook"' "json_error has hook in data"
assert_contains "$ERROR_OUTPUT" '"instructions":"Run test"' "json_error has instructions"

echo ""
echo "error_commit_blocked function:"

COMMIT_ERROR=$(error_commit_blocked "main" "git commit -m test" 2>&1)

assert_valid_json "$COMMIT_ERROR" "error_commit_blocked produces valid JSON"
assert_contains "$COMMIT_ERROR" '"code": -32000' "error_commit_blocked uses -32000"
assert_contains "$COMMIT_ERROR" '"branch":"main"' "error_commit_blocked includes branch"

echo ""
echo "error_branch_blocked function:"

BRANCH_ERROR=$(error_branch_blocked "feature/test" "git checkout -b feature/test" 2>&1)

assert_valid_json "$BRANCH_ERROR" "error_branch_blocked produces valid JSON"
assert_contains "$BRANCH_ERROR" '"code": -32001' "error_branch_blocked uses -32001"
assert_contains "$BRANCH_ERROR" 'feature/test' "error_branch_blocked includes branch name"
assert_contains "$BRANCH_ERROR" 'git worktree add' "error_branch_blocked suggests worktree"

echo ""
echo "error_checkout_blocked function:"

CHECKOUT_ERROR=$(error_checkout_blocked "develop" "git checkout develop" 2>&1)

assert_valid_json "$CHECKOUT_ERROR" "error_checkout_blocked produces valid JSON"
assert_contains "$CHECKOUT_ERROR" '"code": -32002' "error_checkout_blocked uses -32002"
assert_contains "$CHECKOUT_ERROR" '"target":"develop"' "error_checkout_blocked includes target"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Results: ${TESTS_PASSED}/${TESTS_RUN} passed, ${TESTS_FAILED} failed"
echo "═══════════════════════════════════════════════════════════════════"

exit $((TESTS_FAILED > 0 ? 1 : 0))
