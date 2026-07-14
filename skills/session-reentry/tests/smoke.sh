#!/usr/bin/env sh
# smoke.sh — deterministic tests for the session-reentry M1 + M2 increments.
# Tests the two net-new bins (bin/dormancy-score.sh · bin/resolve-session.sh) across
# bands / determinism / id-resolution, and asserts SKILL.md frontmatter + Goldilocks
# size + M2 register wiring. License: MIT.
set -eu

DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$DIR/bin/dormancy-score.sh"
RES="$DIR/bin/resolve-session.sh"
SKILL="$DIR/SKILL.md"
NOW=1000000000
fail=0

# Deterministic fixture root for the id→path resolver (cleaned on exit).
FIX="$(mktemp -d 2>/dev/null || mktemp -d -t sreentry)"
trap 'rm -rf "$FIX"' EXIT INT TERM
mkdir -p "$FIX/enc-cwd"
: > "$FIX/enc-cwd/abc123.jsonl"
: > "$FIX/enc-cwd/abc123-extra.jsonl"   # prefix collision — exact match must still win

check() {  # check <label> <expected-substring> <actual>
  case "$3" in
    *"$2"*) printf '  ok   %s\n' "$1" ;;
    *)      printf '  FAIL %s\n       expected ~ %s\n       got        %s\n' "$1" "$2" "$3"; fail=1 ;;
  esac
}

echo "== dormancy-score bands (deterministic, injected epochs) =="
check "14d self  → 0.67 deep L3"  '"score": 0.67, "band": "deep"'  "$("$BIN" "$BIN" --now "$NOW" --mtime $((NOW-14*86400)))"
check "2d self   → 0.10 fresh L1" '"score": 0.10, "band": "fresh"' "$("$BIN" "$BIN" --now "$NOW" --mtime $((NOW-2*86400)))"
check "0d foreign→ 0.30 warm L2"  '"score": 0.30, "band": "warm"'  "$("$BIN" "$BIN" --now "$NOW" --mtime "$NOW" --foreign)"
check "30d self  → 1.00 cold full" '"score": 1.00, "band": "cold"' "$("$BIN" "$BIN" --now "$NOW" --mtime $((NOW-30*86400)))"
check "14d foreign→0.97 cold full" '"score": 0.97, "band": "cold"' "$("$BIN" "$BIN" --now "$NOW" --mtime $((NOW-14*86400)) --foreign)"
check "future mtime clamps fresh"  '"band": "fresh"'               "$("$BIN" "$BIN" --now "$NOW" --mtime $((NOW+86400)))"

echo "== determinism (same inputs → identical) =="
A="$("$BIN" "$BIN" --now "$NOW" --mtime $((NOW-14*86400)))"
B="$("$BIN" "$BIN" --now "$NOW" --mtime $((NOW-14*86400)))"
[ "$A" = "$B" ] && echo "  ok   deterministic" || { echo "  FAIL non-deterministic"; fail=1; }

echo "== error handling =="
"$BIN" 2>/dev/null && { echo "  FAIL missing-arg should exit non-zero"; fail=1; } || echo "  ok   missing arg → non-zero"
"$BIN" /no/such/path --now "$NOW" 2>/dev/null && { echo "  FAIL bad-path should exit non-zero"; fail=1; } || echo "  ok   bad path → non-zero"
"$BIN" "$BIN" --now 2>/dev/null && { echo "  FAIL --now w/o value should exit non-zero"; fail=1; } || echo "  ok   --now w/o value → non-zero"
"$BIN" "$BIN" --now abc 2>/dev/null && { echo "  FAIL --now non-int should exit non-zero"; fail=1; } || echo "  ok   --now non-int → non-zero"
"$BIN" "$BIN" extra --now "$NOW" 2>/dev/null && { echo "  FAIL multiple positionals should exit non-zero"; fail=1; } || echo "  ok   multiple positionals → non-zero"

echo "== resolve-session id→path (M2, deterministic) =="
check "existing path passthrough" "$BIN"                 "$("$RES" "$BIN")"
check "id → exact .jsonl (prefix loses)" "enc-cwd/abc123.jsonl" "$("$RES" abc123 --root "$FIX")"
"$RES" nosuchid --root "$FIX" 2>/dev/null && { echo "  FAIL unknown id should exit non-zero"; fail=1; } || echo "  ok   unknown id → non-zero"
"$RES" 2>/dev/null && { echo "  FAIL resolver missing-arg should exit non-zero"; fail=1; } || echo "  ok   resolver missing arg → non-zero"
"$RES" abc123 --root 2>/dev/null && { echo "  FAIL resolver --root w/o value should exit non-zero"; fail=1; } || echo "  ok   resolver --root w/o value → non-zero"
"$RES" nosuchid --root /no/such/root 2>/dev/null && { echo "  FAIL bad root should exit non-zero"; fail=1; } || echo "  ok   bad root → non-zero"
# Q2 (Qodo): HOME unset must NOT abort on set -u before --root is honored.
check "HOME unset + --root still resolves" "enc-cwd/abc123.jsonl" "$(env -u HOME "$RES" abc123 --root "$FIX")"
# Q3 (Qodo): a glob-metachar id must be rejected (find -name glob → wrong-artifact risk).
"$RES" 'abc*' --root "$FIX" 2>/dev/null && { echo "  FAIL glob-metachar id should be rejected"; fail=1; } || echo "  ok   glob id 'abc*' → non-zero"

echo "== SKILL.md frontmatter + Goldilocks size =="
head -1 "$SKILL" | grep -q '^---$'            && echo "  ok   frontmatter opens" || { echo "  FAIL no frontmatter"; fail=1; }
grep -q '^name: session-reentry$' "$SKILL"    && echo "  ok   name: session-reentry" || { echo "  FAIL name"; fail=1; }
grep -q '^version:' "$SKILL"                  && echo "  ok   version present" || { echo "  FAIL version"; fail=1; }
grep -q '^allowed-tools:' "$SKILL"            && echo "  ok   allowed-tools present" || { echo "  FAIL allowed-tools"; fail=1; }
SZ=$(wc -c < "$SKILL")
[ "$SZ" -lt 12288 ] && echo "  ok   size ${SZ}B < 12288 (Goldilocks)" || { echo "  FAIL size ${SZ}B >= 12288"; fail=1; }

echo "== SKILL.md example matches bin output (no drift) =="
grep -q '"score": 0.67, "band": "deep", "age_days": 14' "$SKILL" && echo "  ok   JSON example == bin(14d,self)" || { echo "  FAIL example drift"; fail=1; }

echo "== SKILL.md M2 register wiring (no drift) =="
grep -q 'opera-debrief --audience' "$SKILL" && echo "  ok   --mind → opera-debrief --audience wired" || { echo "  FAIL M2 register wiring missing"; fail=1; }
grep -q 'resolve-session.sh' "$SKILL"       && echo "  ok   resolve-session.sh referenced" || { echo "  FAIL resolver ref missing"; fail=1; }

if [ "$fail" -eq 0 ]; then echo "ALL PASS ✓"; else echo "FAILURES ✗"; fi
exit "$fail"
