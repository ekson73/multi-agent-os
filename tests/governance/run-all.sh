#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Governance Tests Runner
# Purpose: Run all governance tests
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}           MAOS GOVERNANCE TEST SUITE                               ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Run each test file
for test_file in "$SCRIPT_DIR"/test-*.sh; do
    if [[ -f "$test_file" ]] && [[ "$test_file" != *"run-all.sh" ]]; then
        echo -e "${YELLOW}Running: $(basename "$test_file")${NC}"
        echo ""

        if bash "$test_file"; then
            echo ""
        else
            ((TOTAL_FAILED++)) || true
        fi

        ((TOTAL_TESTS++)) || true
    fi
done

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
if [[ $TOTAL_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All test suites passed!${NC}"
else
    echo -e "${RED}${TOTAL_FAILED} test suite(s) failed${NC}"
fi
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"

exit $TOTAL_FAILED
