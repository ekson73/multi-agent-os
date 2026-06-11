#!/usr/bin/env bash
# Tests for bin/scorecard-next-model.sh — the postflight scorecard round-robin selector.
# Bash 3.2-safe, self-contained. Uses an ISOLATED temp pointer (never the real
# user-scope state). Run: bash bin/tests/scorecard-next-model.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SEL="$DIR/../scorecard-next-model.sh"

pass=0 ; fail=0
ok() { pass=$((pass + 1)); printf '  \xe2\x9c\x93 %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \xe2\x9c\x97 %s\n      got: [%s]\n' "$1" "$2"; }
eq() { [ "$1" = "$2" ] && ok "$3" || no "$3" "got=[$2] want=[$1]"; }

printf 'scorecard-next-model.test.sh\n'

# Isolate the pointer to a throwaway file (never touch the real ~/.claude state).
TMP="$(mktemp -d 2>/dev/null || echo /tmp/scnm.$$)"; mkdir -p "$TMP"
export POSTFLIGHT_SCORECARD_STATE="$TMP/ptr"
unset POSTFLIGHT_SCORECARD_MODEL 2>/dev/null || true
cleanup() { rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT

# fresh pointer (no file) → first advance is model 1
rm -f "$POSTFLIGHT_SCORECARD_STATE"
eq '1' "$("$SEL")"          'fresh pointer → first model is 1'
eq '2' "$("$SEL")"          'advance → 2'
eq '3' "$("$SEL")"          'advance → 3'

# full wrap 3→8→1 (8 models since Model 8 "Briefing Card" — issue #132)
eq '4' "$("$SEL")" 'advance → 4'
eq '5' "$("$SEL")" 'advance → 5'
eq '6' "$("$SEL")" 'advance → 6'
eq '7' "$("$SEL")" 'advance → 7'
eq '8' "$("$SEL")" 'advance → 8'
eq '1' "$("$SEL")" 'wraps 8 → 1 (round-robin)'

# --peek does NOT advance the pointer (idempotent read). Pointer is at 1 here
# (the 7→1 wrap above), so --current stays 1 and --peek keeps reporting 2.
p1="$("$SEL" --peek)"; p2="$("$SEL" --peek)"
eq "$p1" "$p2" '--peek is non-advancing (two peeks equal)'
eq '2'  "$p1"                 '--peek reports the next id (2) without advancing'
eq '1'  "$("$SEL" --current)" '--current reflects last-used (1), unchanged by peeks'

# --reset → pointer back to 0, next advance is 1 again
eq '0' "$("$SEL" --reset)"  '--reset prints 0'
eq '1' "$("$SEL")"          'after reset → 1'

# valid env override pins a model and never advances the pointer
"$SEL" --reset >/dev/null
eq '5'         "$(POSTFLIGHT_SCORECARD_MODEL=5         "$SEL")" 'env override (id) pins verbatim'
eq 'telemetry' "$(POSTFLIGHT_SCORECARD_MODEL=telemetry "$SEL")" 'env override (name) pins verbatim'
eq '0'         "$("$SEL" --current)" 'override never touched the pointer (still 0)'

# INVALID override (typo) → warns + falls back to round-robin, never emits the junk token
# (needs python3 + scorecard.py to reject a bad NAME; otherwise the selector accepts gracefully).
if command -v python3 >/dev/null 2>&1 && [ -f "$DIR/../scorecard.py" ]; then
  "$SEL" --reset >/dev/null
  out="$(POSTFLIGHT_SCORECARD_MODEL=telemetery "$SEL" 2>/dev/null)"   # 'telemetery' = typo of 'telemetry'
  case "$out" in 1|2|3|4|5|6|7|8) ok 'invalid override falls back to a valid 1..8 id' ;; *) no 'invalid override falls back to a valid 1..8 id' "$out" ;; esac
  case "$out" in telemetery) no 'invalid override NOT emitted verbatim' "$out" ;; *) ok 'invalid override NOT emitted verbatim' ;; esac
  POSTFLIGHT_SCORECARD_MODEL=telemetery "$SEL" 2>&1 >/dev/null | grep -q 'ignoring invalid' && ok 'invalid override warns to stderr' || no 'invalid override warns to stderr' '(no warning seen)'
else
  printf '  - skipped invalid-override-fallback (python3/scorecard.py unavailable)\n'
fi

# invalid pointer content self-heals to 0 → next is 1
printf 'garbage\n' > "$POSTFLIGHT_SCORECARD_STATE"
eq '1' "$("$SEL")" 'non-numeric pointer self-heals → 1'
printf '99\n'      > "$POSTFLIGHT_SCORECARD_STATE"
eq '1' "$("$SEL")" 'out-of-range pointer self-heals → 1'

# every emitted id is a valid scorecard model (1..8) over two full cycles
"$SEL" --reset >/dev/null
bad=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do
  m="$("$SEL")"
  case "$m" in 1|2|3|4|5|6|7|8) ;; *) bad=1 ;; esac
done
eq '0' "$bad" 'all emitted ids over 16 advances are in 1..8'

# always exits 0 (must never abort a session-end debrief)
"$SEL" >/dev/null 2>&1 ; eq '0' "$?"          'advance exits 0'
"$SEL" --peek >/dev/null 2>&1 ; eq '0' "$?"   '--peek exits 0'
"$SEL" --bogus >/dev/null 2>&1 ; eq '0' "$?"  'unknown arg falls through to advance, exits 0'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
