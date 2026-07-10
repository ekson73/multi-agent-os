#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Test: test-session-tip.sh
# Purpose: MAOS-Tips session-start hook (plugin-scripts/session-tip.sh). DoD-gate is a
#   BEHAVIOR over GOLDEN FIXTURES (a fixture catalog + a fixture HOME for the seen-ledger),
#   never a prose THEN: opt-out silences · resume/compact skipped · startup fires exactly
#   one valid tip · no-repeat across sessions · same-session idempotency · --print on-demand ·
#   --emit-announcements array · absent catalog degrades to silent no-op.
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="${PROJECT_ROOT}/plugin-scripts/session-tip.sh"

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

TMP=""
setup() {
  TMP="$(mktemp -d)"
  mkdir -p "$TMP/plug/tips" "$TMP/plug/skills/maos-concierge" "$TMP/home/.claude" "$TMP/empty/tips"
  # a valid concierge skill so family.route resolves (not used by the hook, but realistic)
  printf 'name: maos-concierge\n' > "$TMP/plug/skills/maos-concierge/SKILL.md"
  cat > "$TMP/plug/tips/catalog.json" <<'JSON'
{ "version":"1.0.0",
  "families":{ "f1":{"route":"maos-concierge","blurb":"x"}, "_default":{"route":"maos-concierge","blurb":"d"} },
  "tips":[
    {"id":"t1","tool":"alpha","invocation":"/maos:alpha","tool_type":"skill","tool_path":"skills/alpha/SKILL.md","family":"f1","text":"do alpha."},
    {"id":"t2","tool":"bravo","invocation":"/maos:bravo","tool_type":"skill","tool_path":"skills/bravo/SKILL.md","family":"f1","text":"do bravo."}
  ] }
JSON
}
teardown() { [ -n "$TMP" ] && [ -d "$TMP" ] && rm -rf "$TMP"; }

assert_eq() {
  local expected="$1" actual="$2" name="${3:-assert}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$expected" = "$actual" ]; then echo -e "  ${GREEN}✓${NC} $name"; TESTS_PASSED=$((TESTS_PASSED + 1))
  else echo -e "  ${RED}✗${NC} $name (expected='$expected' actual='$actual')"; TESTS_FAILED=$((TESTS_FAILED + 1)); fi
}
assert_contains() {
  local hay="$1" needle="$2" name="${3:-assert-contains}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s' "$hay" | grep -q -- "$needle"; then echo -e "  ${GREEN}✓${NC} $name"; TESTS_PASSED=$((TESTS_PASSED + 1))
  else echo -e "  ${RED}✗${NC} $name (missing '$needle' in: $hay)"; TESTS_FAILED=$((TESTS_FAILED + 1)); fi
}
assert_ne() {
  local a="$1" b="$2" name="${3:-assert-ne}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$a" != "$b" ]; then echo -e "  ${GREEN}✓${NC} $name"; TESTS_PASSED=$((TESTS_PASSED + 1))
  else echo -e "  ${RED}✗${NC} $name (both='$a')"; TESTS_FAILED=$((TESTS_FAILED + 1)); fi
}

# run the hook in hook-mode with a given source+session_id; echoes STDERR (the human line)
run_hook() {  # $1=source $2=sid ; extra env via caller
  printf '{"source":"%s","session_id":"%s"}' "$1" "$2" \
    | CLAUDE_PLUGIN_ROOT="$TMP/plug" HOME="$TMP/home" bash "$HOOK" 2>&1 >/dev/null
}
run_hook_stdout() {  # stdout only (the additionalContext JSON)
  printf '{"source":"%s","session_id":"%s"}' "$1" "$2" \
    | CLAUDE_PLUGIN_ROOT="$TMP/plug" HOME="$TMP/home" bash "$HOOK" 2>/dev/null
}
tool_of() { printf '%s' "$1" | sed -n 's/.*💡 MAOS Tip · \([a-z]*\):.*/\1/p'; }

echo "== test-session-tip =="
setup
trap teardown EXIT

# A: opt-out MAOS_TIPS=off → silence + exit 0
OUT="$(printf '{"source":"startup","session_id":"sA"}' | MAOS_TIPS=off CLAUDE_PLUGIN_ROOT="$TMP/plug" HOME="$TMP/home" bash "$HOOK" 2>&1)"; RC=$?
assert_eq "0" "$RC"  "opt-out MAOS_TIPS=off exits 0"
assert_eq ""  "$OUT" "opt-out emits nothing"

# A2: opt-out ~/.claude/.maos-no-tips sentinel file
: > "$TMP/home/.claude/.maos-no-tips"
OUT="$(printf '{"source":"startup","session_id":"sA2"}' | CLAUDE_PLUGIN_ROOT="$TMP/plug" HOME="$TMP/home" bash "$HOOK" 2>&1)"
assert_eq "" "$OUT" "sentinel file .maos-no-tips silences"
rm -f "$TMP/home/.claude/.maos-no-tips"

# B: source=resume → skip (no tip); source=compact → skip
assert_eq "" "$(run_hook resume  sB)" "source=resume is skipped"
assert_eq "" "$(run_hook compact sB2)" "source=compact is skipped"

# C: source=startup → exactly one valid tip on stderr + additionalContext on stdout
E1="$(run_hook startup s1)"
assert_contains "$E1" "💡 MAOS Tip"        "startup surfaces a tip line"
assert_contains "$E1" "more: /maos:maos-concierge" "tip carries the concierge route"
O1="$(run_hook_stdout startup s1b)"
assert_contains "$O1" '"hookEventName":"SessionStart"' "stdout emits SessionStart additionalContext"

# D: no-repeat across DIFFERENT sessions — second tip differs from first (2-tip corpus)
T_A="$(tool_of "$(run_hook startup d1)")"
T_B="$(tool_of "$(run_hook startup d2)")"
assert_ne "$T_A" "$T_B" "consecutive sessions get different tips (no-repeat)"

# E: idempotency — same session_id twice → second run silent
E_first="$(run_hook startup eS)"
E_again="$(run_hook startup eS)"
assert_contains "$E_first" "💡 MAOS Tip" "same-session first run tips"
assert_eq "" "$E_again"                  "same-session second run is silent (idempotent)"

# F: --emit-announcements N → JSON array of length N on stdout
ANN="$(CLAUDE_PLUGIN_ROOT="$TMP/plug" HOME="$TMP/home" bash "$HOOK" --emit-announcements 2 2>/dev/null)"
LEN="$(printf '%s' "$ANN" | jq 'length' 2>/dev/null || echo -1)"
assert_eq "2" "$LEN" "--emit-announcements 2 prints a 2-element array"
assert_contains "$ANN" "MAOS Tip" "announcement strings carry the tip glyph"

# G: --print on-demand → a tip on stdout, ledger untouched (non-mutating)
P="$(CLAUDE_PLUGIN_ROOT="$TMP/plug" HOME="$TMP/home" bash "$HOOK" --print 2>/dev/null)"
assert_contains "$P" "💡 MAOS Tip" "--print renders a tip to stdout"

# H: absent catalog → silent no-op, exit 0 (degrade, never fail)
OUT="$(printf '{"source":"startup","session_id":"sH"}' | CLAUDE_PLUGIN_ROOT="$TMP/empty" HOME="$TMP/home" bash "$HOOK" 2>&1)"; RC=$?
assert_eq "0" "$RC" "absent catalog exits 0"
assert_eq "" "$OUT" "absent catalog emits nothing"

# I: HOME unset → still renders (state degrades, never aborts under set -u)
I_OUT="$(printf '{"source":"startup","session_id":"sI"}' | env -u HOME CLAUDE_PLUGIN_ROOT="$TMP/plug" bash "$HOOK" 2>&1 >/dev/null)"; I_RC=$?
assert_eq "0" "$I_RC" "hook exits 0 with HOME unset"
assert_contains "$I_OUT" "💡 MAOS Tip" "hook still tips with HOME unset"

echo ""
echo "  Run: $TESTS_RUN  Passed: $TESTS_PASSED  Failed: $TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]
