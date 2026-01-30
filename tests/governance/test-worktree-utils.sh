#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Test: test-worktree-utils.sh
# Purpose: Unit tests for governance/lib/worktree-utils.sh
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

assert_true() {
    local result="$1"
    local name="${2:-assertion}"

    ((TESTS_RUN++)) || true
    if [[ "$result" == "0" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "  ${GREEN}✓${NC} $name"
    else
        ((TESTS_FAILED++)) || true
        echo -e "  ${RED}✗${NC} $name (returned $result)"
    fi
}

assert_false() {
    local result="$1"
    local name="${2:-assertion}"

    ((TESTS_RUN++)) || true
    if [[ "$result" != "0" ]]; then
        ((TESTS_PASSED++)) || true
        echo -e "  ${GREEN}✓${NC} $name"
    else
        ((TESTS_FAILED++)) || true
        echo -e "  ${RED}✗${NC} $name (returned 0, expected non-zero)"
    fi
}

# =============================================================================
# TESTS
# =============================================================================

echo "Testing worktree-utils.sh..."
echo ""

# Source library
source "${LIB_DIR}/worktree-utils.sh"

echo "Command detection functions:"

# is_branch_creation
is_branch_creation "git checkout -b feature/test" && R=0 || R=$?
assert_true "$R" "is_branch_creation: git checkout -b"

is_branch_creation "git switch -c feature/test" && R=0 || R=$?
assert_true "$R" "is_branch_creation: git switch -c"

is_branch_creation "git branch feature/test" && R=0 || R=$?
assert_true "$R" "is_branch_creation: git branch <name>"

is_branch_creation "git checkout main" && R=0 || R=$?
assert_false "$R" "is_branch_creation: git checkout (no -b)"

is_branch_creation "git branch -d feature/test" && R=0 || R=$?
assert_false "$R" "is_branch_creation: git branch -d (delete)"

echo ""
echo "is_checkout_command:"

is_checkout_command "git checkout main" && R=0 || R=$?
assert_true "$R" "is_checkout_command: git checkout main"

is_checkout_command "git switch develop" && R=0 || R=$?
assert_true "$R" "is_checkout_command: git switch develop"

is_checkout_command "git checkout -b feature" && R=0 || R=$?
assert_false "$R" "is_checkout_command: excludes branch creation"

echo ""
echo "is_commit_command:"

is_commit_command "git commit -m 'test'" && R=0 || R=$?
assert_true "$R" "is_commit_command: git commit -m"

is_commit_command "git commit --amend" && R=0 || R=$?
assert_true "$R" "is_commit_command: git commit --amend"

is_commit_command "git add ." && R=0 || R=$?
assert_false "$R" "is_commit_command: git add (not commit)"

echo ""
echo "extract_branch_name:"

BRANCH=$(extract_branch_name "git checkout -b feature/test")
assert_equals "feature/test" "$BRANCH" "extract from checkout -b"

BRANCH=$(extract_branch_name "git switch -c hotfix/123")
assert_equals "hotfix/123" "$BRANCH" "extract from switch -c"

BRANCH=$(extract_branch_name "git branch my-branch")
assert_equals "my-branch" "$BRANCH" "extract from git branch"

echo ""
echo "extract_checkout_target:"

TARGET=$(extract_checkout_target "git checkout develop")
assert_equals "develop" "$TARGET" "extract checkout target"

TARGET=$(extract_checkout_target "git switch main")
assert_equals "main" "$TARGET" "extract switch target"

echo ""
echo "get_worktree_name:"

WTNAME=$(get_worktree_name "/path/to/.worktrees/governance/subdir")
assert_equals "governance" "$WTNAME" "extract worktree name from path"

WTNAME=$(get_worktree_name "/path/to/regular/repo")
assert_equals "" "$WTNAME" "empty for non-worktree path"

echo ""
echo "is_protected_branch:"

# Mock get_current_branch for testing
get_current_branch() { echo "main"; }
source "${LIB_DIR}/worktree-utils.sh"

is_protected_branch && R=0 || R=$?
assert_true "$R" "is_protected_branch: main is protected"

get_current_branch() { echo "master"; }
is_protected_branch && R=0 || R=$?
assert_true "$R" "is_protected_branch: master is protected"

get_current_branch() { echo "feature/test"; }
is_protected_branch && R=0 || R=$?
assert_false "$R" "is_protected_branch: feature branch not protected"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Results: ${TESTS_PASSED}/${TESTS_RUN} passed, ${TESTS_FAILED} failed"
echo "═══════════════════════════════════════════════════════════════════"

exit $((TESTS_FAILED > 0 ? 1 : 0))
