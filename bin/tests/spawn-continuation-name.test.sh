#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Tests: bin/spawn-continuation.sh — D1 locus session-name wiring (v0.2.0)
# Scope: NAME construction ONLY, all via --dry-run (touches nothing, spawns nothing).
#   - default: D1 locus name (emoji-first experiment): <status> · <anchor> · <slug> · #<short>
#   - --status glyph propagates
#   - POSTFLIGHT_NAME_STYLE=legacy → pre-0.2.0 ascii name
#   - locus.sh absent (MAOS_LOCUS_BIN seam) → graceful legacy fallback, exit 0
#   - read-only guarantee: --dry-run writes no jobs-registry entries / markers
# Bash 3.2-safe. Run: bash bin/tests/spawn-continuation-name.test.sh
# ═══════════════════════════════════════════════════════════════════════════════
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SPAWN="$SCRIPT_DIR/../spawn-continuation.sh"

PASS=0 FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  ❌ %s\n     got: %s\n' "$1" "${2:-<empty>}"; }

# isolate the jobs registry so the test never touches ~/.claude/jobs
TMP_JOBS="$(mktemp -d)"
trap 'rm -rf "$TMP_JOBS"' EXIT
run() { CLAUDE_JOBS_DIR="$TMP_JOBS" bash "$SPAWN" --dry-run "$@" 2>/dev/null; }
name_of() { sed -n 's/.*"name":"\([^"]*\)".*/\1/p'; }

echo "── spawn-continuation NAME tests"

# 1. default status → D1 locus name: 🟡 first token, slug + #seq present, ' · ' separators
N="$(run --slug payment-retry | name_of)"
case "$N" in
  "🟡 · "*" · payment-retry · #"*) ok "default D1 name: status 🟡 + computed anchor + slug + #seq" ;;
  *) bad "default D1 name shape" "$N" ;;
esac

# 2. --status 🟢 propagates into the name
N="$(run --slug payment-retry --status 🟢 | name_of)"
case "$N" in
  "🟢 · "*) ok "--status 🟢 propagates" ;;
  *) bad "--status 🟢 propagates" "$N" ;;
esac

# 3. POSTFLIGHT_NAME_STYLE=legacy → pre-0.2.0 ascii name (no emoji, no middle-dot)
N="$(POSTFLIGHT_NAME_STYLE=legacy run --slug payment-retry --ticket VKS-123 | name_of)"
if [ "$N" = "VKS-123-payment-retry-#$(printf '%s' "$N" | sed 's/.*#//')" ] \
   && ! printf '%s' "$N" | grep -q '·'; then
  ok "POSTFLIGHT_NAME_STYLE=legacy → ascii <ticket>-<slug>-#<short>"
else
  bad "legacy name shape" "$N"
fi

# 4. locus renderer absent → graceful legacy fallback + exit 0
OUT="$(MAOS_LOCUS_BIN=/nonexistent-locus run --slug payment-retry)"; RC=$?
N="$(printf '%s' "$OUT" | name_of)"
if [ "$RC" -eq 0 ] && [ "$N" = "payment-retry-#$(printf '%s' "$N" | sed 's/.*#//')" ]; then
  ok "locus.sh absent → legacy fallback, exit 0"
else
  bad "locus.sh absent fallback (rc=$RC)" "$N"
fi

# 5. read-only guarantee: --dry-run created NOTHING in the jobs registry
if [ -z "$(ls -A "$TMP_JOBS" 2>/dev/null)" ]; then
  ok "--dry-run touches nothing (jobs registry empty)"
else
  bad "--dry-run touched the jobs registry" "$(ls -A "$TMP_JOBS")"
fi

# 6. anti-injection: --status outside the 4-glyph whitelist (shell-metachar payload)
#    → falls back to 🟡 and the rendered name stays well-formed (no quote/semicolon leaks)
N="$(run --slug payment-retry --status "🟢'; echo pwned;'" | name_of)"
case "$N" in
  "🟡 · "*) if printf '%s' "$N" | grep -q "pwned"; then bad "status whitelist leaked payload" "$N"
            else ok "--status whitelist: injection-shaped status → 🟡 fallback, no payload leak"; fi ;;
  *) bad "--status whitelist fallback" "$N" ;;
esac

# 7. KICKOFF (v0.4.0): default dry-run resume_cmd carries the positional kickoff prompt
#    (the spawned session must START WORKING — not sit idle at the REPL)
C="$(run --slug payment-retry | sed -n 's/.*"resume_cmd":"\([^"]*\)".*/\1/p')"
case "$C" in
  *"preflight to orient"*) ok "kickoff prompt present by default in the spawn command" ;;
  *) bad "kickoff prompt present by default" "$C" ;;
esac

# 8. --no-kickoff flag → no kickoff in the command
C="$(run --slug payment-retry --no-kickoff | sed -n 's/.*"resume_cmd":"\([^"]*\)".*/\1/p')"
case "$C" in
  *"preflight to orient"*) bad "--no-kickoff still injected kickoff" "$C" ;;
  *) ok "--no-kickoff omits the kickoff prompt" ;;
esac

# 9. POSTFLIGHT_KICKOFF=0 env → no kickoff (same as the flag)
C="$(CLAUDE_JOBS_DIR="$TMP_JOBS" POSTFLIGHT_KICKOFF=0 bash "$SPAWN" --dry-run --slug payment-retry 2>/dev/null | sed -n 's/.*"resume_cmd":"\([^"]*\)".*/\1/p')"
case "$C" in
  *"preflight to orient"*) bad "POSTFLIGHT_KICKOFF=0 still injected kickoff" "$C" ;;
  *) ok "POSTFLIGHT_KICKOFF=0 omits the kickoff prompt" ;;
esac

echo "── $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
