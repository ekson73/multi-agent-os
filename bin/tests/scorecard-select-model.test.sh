#!/usr/bin/env bash
# Tests for bin/scorecard-select-model.sh — the dynamic context-based model
# selector (issue #132). Bash 3.2-safe, self-contained. Uses an ISOLATED temp
# pointer for the round-robin delegation tests (never the real user-scope state).
# Run: bash bin/tests/scorecard-select-model.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SEL="$DIR/../scorecard-select-model.sh"

pass=0 ; fail=0
ok() { pass=$((pass + 1)); printf '  \xe2\x9c\x93 %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \xe2\x9c\x97 %s\n      got: [%s]\n' "$1" "$2"; }
eq() { [ "$1" = "$2" ] && ok "$3" || no "$3" "got=[$2] want=[$1]"; }

printf 'scorecard-select-model.test.sh\n'

# Isolate the round-robin pointer + clear any ambient pin.
TMP="$(mktemp -d 2>/dev/null || echo /tmp/scsm.$$)"; mkdir -p "$TMP"
export POSTFLIGHT_SCORECARD_STATE="$TMP/ptr"
unset POSTFLIGHT_SCORECARD_MODEL 2>/dev/null || true
cleanup() { rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT

# ── decision table (first-match, deterministic) ──────────────────────────────
eq '2' "$("$SEL")"                                      'bare call (no factors) → R8 default = 2 (no-info ≠ trivial)'
eq '6' "$("$SEL" --audience agent)"                     'R1 agent audience → 6 Telemetry'
eq '8' "$("$SEL" --purpose briefing)"                   'R2 briefing purpose → 8 Briefing Card'
eq '6' "$("$SEL" --purpose handoff)"                    'R3 handoff purpose → 6 Telemetry'
eq '1' "$("$SEL" --risk high --items 5 --open 1)"       'R4 high risk → 1 Cockpit'
eq '1' "$("$SEL" --urgency high)"                       'R4 high urgency → 1 Cockpit'
eq '7' "$("$SEL" --items 2 --open 0)"                   'R5 trivial (sized) → 7 One-Liner'
eq '7' "$("$SEL" --items 0)"                            'R5 explicit zero items → 7 One-Liner'
eq '5' "$("$SEL" --items 10 --open 4)"                  'R6 open ≥4 → 5 Kanban'
eq '5' "$("$SEL" --items 4 --open 2)"                   'R6 open ≥ items/2 (open≥2) → 5 Kanban'
eq '4' "$("$SEL" --items 9 --open 1)"                   'R7 backlog-heavy → 4 Burndown'
eq '2' "$("$SEL" --items 5 --open 1)"                   'R8 default mid-size → 2 Strip'

# ── precedence (first match wins) ────────────────────────────────────────────
eq '6' "$("$SEL" --audience agent --purpose briefing)"  'R1 beats R2 (agent > briefing)'
eq '8' "$("$SEL" --purpose briefing --risk high)"       'R2 beats R4 (briefing > risk)'
eq '1' "$("$SEL" --risk high --items 2 --open 0)"       'R4 beats R5 (stakes > trivial)'

# ── R0: env pin overrides EVERYTHING (any mode, any factors) ────────────────
eq '3'         "$(POSTFLIGHT_SCORECARD_MODEL=3         "$SEL" --audience agent)" 'R0 pin (id) beats R1'
eq 'telemetry' "$(POSTFLIGHT_SCORECARD_MODEL=telemetry "$SEL" --purpose briefing)" 'R0 pin (name) verbatim'
eq '8'         "$(POSTFLIGHT_SCORECARD_MODEL=8         "$SEL")" 'R0 pin accepts new id 8'
if command -v python3 >/dev/null 2>&1 && [ -f "$DIR/../scorecard.py" ]; then
  out="$(POSTFLIGHT_SCORECARD_MODEL=telemetery "$SEL" --audience agent 2>/dev/null)"
  eq '6' "$out" 'invalid pin (typo) warns + falls through to the table (R1)'
fi

# ── round-robin mode: delegates to the preserved interim engine ──────────────
rm -f "$POSTFLIGHT_SCORECARD_STATE"
eq '1' "$("$SEL" --mode round-robin)" 'round-robin mode delegates → first advance is 1'
eq '2' "$("$SEL" --mode round-robin)" 'round-robin mode advances → 2'
eq '3' "$("$SEL" --mode round-robin --audience agent)" 'round-robin mode ignores factors (pointer-driven → 3)'
ptr="$(cat "$POSTFLIGHT_SCORECARD_STATE" 2>/dev/null)"
eq '3' "$ptr" 'round-robin pointer continuity through the front-door'

# ── graceful degradation (never abort a debrief) ─────────────────────────────
eq '2' "$("$SEL" --items banana 2>/dev/null)"           'non-numeric --items → warn + default 0 → R8'
eq '2' "$("$SEL" --risk catastrophic 2>/dev/null)"      'invalid --risk enum → warn + low → R8'
eq '2' "$("$SEL" --mode warp 2>/dev/null)"              'invalid --mode → warn + dynamic → R8'
eq '2' "$("$SEL" --bogus-flag 2>/dev/null)"             'unknown flag → warn + skip → R8'
"$SEL" --items banana >/dev/null 2>&1 ; eq '0' "$?"     'invalid input still exits 0'
"$SEL" --explain >/dev/null 2>&1 ;      eq '0' "$?"     '--explain exits 0'

# trailing value-flag with NO value must not hang (shift-2 guard — qodo finding PR #139)
out="$(perl -e 'alarm 5; exec @ARGV' "$SEL" --risk 2>/dev/null)"; rc=$?
eq '0' "$rc"  'trailing --risk (no value) exits 0 within 5s (no hang)'
eq '2' "$out" 'trailing --risk (no value) → warn + default → R8'

# ── --explain emits the matched rule to stderr, stdout unchanged ─────────────
exp_err="$("$SEL" --purpose briefing --explain 2>&1 >/dev/null)"
case "$exp_err" in *"rule R2"*) ok '--explain names the matched rule (R2)' ;; *) no '--explain names the matched rule (R2)' "$exp_err" ;; esac
eq '8' "$("$SEL" --purpose briefing --explain 2>/dev/null)" '--explain leaves stdout contract intact'

# ── output contract: exactly one line, always a valid token ──────────────────
lines="$("$SEL" --items 5 --open 1 | wc -l | tr -d ' ')"
eq '1' "$lines" 'output is exactly one line'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
