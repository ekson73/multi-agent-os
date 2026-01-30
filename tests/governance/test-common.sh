#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Test: test-common.sh
# Purpose: Unit tests for governance/lib/common.sh
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
assert_equals() {
    local expected="$1"
    local actual="$2"
    local name="${3:-assertion}"

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

assert_not_empty() {
    local actual="$1"
    local name="${2:-assertion}"

    ((TESTS_RUN++)) || true
    if [[ -n "$actual" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "  ${GREEN}✓${NC} $name"
    else
        ((TESTS_FAILED++)) || true
        echo -e "  ${RED}✗${NC} $name (was empty)"
    fi
}

# =============================================================================
# TESTS
# =============================================================================

echo "Testing common.sh..."
echo ""

# Source library
source "${LIB_DIR}/common.sh"

echo "Constants:"
assert_equals "0" "$EXIT_SUCCESS" "EXIT_SUCCESS is 0"
assert_equals "1" "$EXIT_ERROR" "EXIT_ERROR is 1"
assert_equals "2" "$EXIT_BLOCKED" "EXIT_BLOCKED is 2"
assert_equals "-32000" "$ERR_COMMIT_BLOCKED" "ERR_COMMIT_BLOCKED is -32000"
assert_equals "-32001" "$ERR_BRANCH_BLOCKED" "ERR_BRANCH_BLOCKED is -32001"
assert_equals "-32002" "$ERR_CHECKOUT_BLOCKED" "ERR_CHECKOUT_BLOCKED is -32002"

echo ""
echo "Functions:"

# Test generate_request_id
REQUEST_ID=$(generate_request_id)
assert_not_empty "$REQUEST_ID" "generate_request_id returns value"

# Test get_timestamp
TIMESTAMP=$(get_timestamp)
assert_not_empty "$TIMESTAMP" "get_timestamp returns value"
[[ "$TIMESTAMP" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]] && echo -e "  ${GREEN}✓${NC} get_timestamp ISO 8601 format" || echo -e "  ${RED}✗${NC} get_timestamp not ISO 8601"

# Test json_escape
ESCAPED=$(json_escape 'hello "world"')
assert_equals 'hello \"world\"' "$ESCAPED" "json_escape escapes quotes"

ESCAPED=$(json_escape $'line1\nline2')
assert_equals 'line1\nline2' "$ESCAPED" "json_escape escapes newlines"

# Test has_bypass_flag
has_bypass_flag "git commit --force-no-worktree" && RESULT="true" || RESULT="false"
assert_equals "true" "$RESULT" "has_bypass_flag detects --force-no-worktree"

has_bypass_flag "git commit -m test" && RESULT="true" || RESULT="false"
assert_equals "false" "$RESULT" "has_bypass_flag returns false for normal commands"

# Test strip_bypass_flags
STRIPPED=$(strip_bypass_flags "git commit --force-no-worktree -m test")
[[ "$STRIPPED" =~ "force-no-worktree" ]] && RESULT="contains" || RESULT="stripped"
assert_equals "stripped" "$RESULT" "strip_bypass_flags removes flag"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Results: ${TESTS_PASSED}/${TESTS_RUN} passed, ${TESTS_FAILED} failed"
echo "═══════════════════════════════════════════════════════════════════"

exit $((TESTS_FAILED > 0 ? 1 : 0))
