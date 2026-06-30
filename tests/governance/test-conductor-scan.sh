#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Test: test-conductor-scan.sh
# Purpose: C1 single-conductor scan (RULE-011) — lib/conductor-scan.sh + the
#   SessionStart hook single-conductor-scan.sh. DoD-gate: the acceptance is a
#   LOGGED FIELD (decision ∈ {clean,taint,refuse}) over GOLDEN FIXTURES (a
#   planted project-conductor footprint), never a prose THEN.
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB="${PROJECT_ROOT}/plugin-scripts/governance/lib/conductor-scan.sh"
HOOK="${PROJECT_ROOT}/plugin-scripts/governance/single-conductor-scan.sh"

# shellcheck source=/dev/null
source "$LIB"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

TMP=""
setup()    { TMP="$(mktemp -d)"; mkdir -p "$TMP/proj" "$TMP/user" "$TMP/empty"; }
teardown() { [ -n "$TMP" ] && [ -d "$TMP" ] && rm -rf "$TMP"; }

assert_eq() {
    local expected="$1" actual="$2" name="${3:-assert}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$expected" = "$actual" ]; then
        echo -e "  ${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} $name (expected='$expected' actual='$actual')"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" name="${3:-assert-contains}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if printf '%s' "$haystack" | grep -q -- "$needle"; then
        echo -e "  ${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} $name (missing '$needle' in: $haystack)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

_decision() { printf '%s' "$1" | sed -n 's/.*"decision":"\([a-z]*\)".*/\1/p'; }

echo "== test-conductor-scan =="
setup
trap teardown EXIT

# --- Fixture A: a competing manager (bmad) planted in the PROJECT scope -------
mkdir -p "$TMP/proj/.bmad-core"
A="$(csc_scan "$TMP/proj" "$TMP/empty")"
assert_eq "refuse" "$(_decision "$A")"           "project-scope conductor => decision=refuse"
assert_contains "$A" "bmad-method"               "refuse names the detected manager"
assert_contains "$A" '"scope":"project"'         "refuse scope=project"

# --- Fixture B: a competing manager present only USER-globally ----------------
mkdir -p "$TMP/user/skills/superpowers"
B="$(csc_scan "$TMP/empty" "$TMP/user")"
assert_eq "taint" "$(_decision "$B")"            "user-only conductor => decision=taint (advisory)"
assert_contains "$B" "superpowers"               "taint names the detected manager"
assert_contains "$B" '"scope":"user"'            "taint scope=user"

# --- Fixture C: project conflict DOMINATES a user-global one (refuse wins) ----
C="$(csc_scan "$TMP/proj" "$TMP/user")"
assert_eq "refuse" "$(_decision "$C")"           "project match dominates user match => refuse"
assert_contains "$C" "bmad-method"               "union lists project manager"
assert_contains "$C" "superpowers"               "union lists user manager"

# --- Fixture D: clean (no competing manager anywhere) ------------------------
D="$(csc_scan "$TMP/empty" "$TMP/empty")"
assert_eq "clean" "$(_decision "$D")"            "no conductor => decision=clean"
assert_contains "$D" '"detected_conductors":\[\]' "clean has empty detected list"

# --- Fixture E: MAOS's own footprint must NOT self-trip -----------------------
mkdir -p "$TMP/empty/skills/maos" "$TMP/empty/skills/database"   # 'database' contains 'base'
E="$(csc_scan "$TMP/empty" "$TMP/empty")"
assert_eq "clean" "$(_decision "$E")"            "maos/own + 'database' substring do NOT false-trip"

# --- Fixture F: end-to-end hook emits SessionStart context + exits 0 ---------
HOOK_OUT="$(CLAUDE_PROJECT_DIR="$TMP/proj" CLAUDE_CONFIG_DIR="$TMP/empty" bash "$HOOK" 2>/dev/null)"; HOOK_RC=$?
assert_eq "0" "$HOOK_RC"                          "hook never aborts the session (exit 0)"
assert_contains "$HOOK_OUT" '"hookEventName":"SessionStart"' "hook emits SessionStart additionalContext"
assert_contains "$HOOK_OUT" "decision=refuse"    "hook surfaces the refuse decision for a planted project conductor"

# --- Fixture G: opt-out short-circuits ---------------------------------------
G_OUT="$(MAOS_NO_CONDUCTOR_SCAN=1 CLAUDE_PROJECT_DIR="$TMP/proj" bash "$HOOK" 2>/dev/null)"; G_RC=$?
assert_eq "0" "$G_RC"                            "opt-out MAOS_NO_CONDUCTOR_SCAN=1 exits 0"
assert_eq "" "$G_OUT"                            "opt-out emits nothing"

# --- Fixture H: a competitor installed PROJECT-LOCALLY under .claude/ ---------
# (Claude Code project-local layout: .claude/skills/<competitor>) must be caught
# as a project-scope match (refuse), not missed.
mkdir -p "$TMP/projlocal/.claude/skills/superpowers"
H="$(csc_scan "$TMP/projlocal" "$TMP/empty")"
assert_eq "refuse" "$(_decision "$H")"           "project-local .claude/ install => decision=refuse"
assert_contains "$H" "superpowers"               "refuse names the .claude-local manager"
assert_contains "$H" '"scope":"project"'         ".claude-local match scoped project"

# --- Fixture I: hook NEVER aborts even with HOME unset (set -u safe) ----------
I_OUT="$(env -u HOME -u CLAUDE_CONFIG_DIR CLAUDE_PROJECT_DIR="$TMP/empty" bash "$HOOK" 2>/dev/null)"; I_RC=$?
assert_eq "0" "$I_RC"                            "hook exits 0 with HOME unset (never aborts)"
assert_contains "$I_OUT" '"hookEventName":"SessionStart"' "hook still emits SessionStart context, HOME unset"

# --- Fixture J: a data-driven registry id with quote/backslash => VALID JSON --
if command -v python3 >/dev/null 2>&1; then
    REG="$TMP/reg.txt"
    printf 'we"ird\\mgr|marker\n' > "$REG"
    mkdir -p "$TMP/projj/marker"
    J="$(csc_scan "$TMP/projj" "$TMP/empty" "$REG")"
    TESTS_RUN=$((TESTS_RUN + 1))
    if printf '%s' "$J" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["detected_conductors"]==["we\"ird\\mgr"] else 1)' 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} data-driven id with quote/backslash => valid escaped JSON"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} data-driven id with quote/backslash => valid escaped JSON (got: $J)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo "  (skip json-escape fixture J: python3 absent)"
fi

echo ""
echo "  Run: $TESTS_RUN  Passed: $TESTS_PASSED  Failed: $TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]
