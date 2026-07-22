#!/usr/bin/env bash
# lens-dispatch — executable non-regression matrix.
#
# WHY THIS FILE EXISTS
# -------------------
# The first version of skills/lens-dispatch/SKILL.md cited "the 44-combination matrix"
# as proof of the non-regression floor. An independent red-team (H6, 2026-07-22) found
# that the matrix existed ONLY as something the author ran by hand in a terminal: not
# committed, not runnable by anyone else, not re-runnable on change. Citing it as proof
# was citing evidence that does not exist.
#
# This file is that claim, made real. It must run in CI or the claim must be deleted.
#
# Exit: 0 all assertions hold · 1 a claim in the SKILL.md is no longer true.
set -uo pipefail

BIN="$(cd "$(dirname "$0")/../bin" && pwd)/lens-dispatch"
MODES="continuation fresh debate converge"
WORKS="feat enhance fix hotfix debug gap refactor harmonize chore docs test"
fails=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; fails=$((fails+1)); }

[ -x "$BIN" ] || { fail "not executable: $BIN"; exit 1; }

# ---------------------------------------------------------------------------
# 1. Every combination resolves. No orphans, no crashes, no unexpected codes.
# ---------------------------------------------------------------------------
d=0; n=0; inc=0; other=0
for m in $MODES; do
  for w in $WORKS; do
    "$BIN" --node-kind task --session-type "${m}×${w}" >/dev/null 2>&1
    case $? in
      0) d=$((d+1))   ;;
      3) n=$((n+1))   ;;
      4) inc=$((inc+1)) ;;
      *) other=$((other+1)); fail "unexpected exit for ${m}×${w}" ;;
    esac
  done
done
total=$((d+n+inc+other))
[ "$total" -eq 44 ] || fail "expected 44 combinations, counted $total"
[ "$other" -eq 0 ]  || fail "$other combination(s) returned an undocumented exit code"
note "matrix: DISPATCH=$d NULL_PROFILE=$n INCONCLUSIVE=$inc of $total"

# The SKILL.md states this exposure number in plain text. If the tables change, the
# doc is now WRONG — so this test fails rather than letting the doc quietly drift.
[ "$d" -eq 16 ] || fail "DISPATCH count is $d; SKILL.md claims 16 — update BOTH or neither"

# ---------------------------------------------------------------------------
# 2. THE LOAD-BEARING CLAIM: no DISPATCH without traceable provenance.
#    This is the assertion the non-regression floor rests on.
# ---------------------------------------------------------------------------
for m in $MODES; do
  for w in $WORKS; do
    out="$("$BIN" --node-kind task --session-type "${m}×${w}" --format json 2>/dev/null)" || continue
    case "$out" in
      *'"verdict":"DISPATCH"'*)
        case "$out" in
          *'"provenance":"transcribed"'*|*'"provenance":"bridge-hypothesis"'*) : ;;
          *) fail "${m}×${w}: DISPATCH with untraceable provenance" ;;
        esac
        case "$out" in
          *'"recipe_id":""'*|*'"recipe_id":null'*) fail "${m}×${w}: DISPATCH with empty recipe_id" ;;
        esac ;;
    esac
  done
done

# ---------------------------------------------------------------------------
# 3. Red-team H6 regression guards. Each of these SHIPPED BROKEN on 2026-07-22.
# ---------------------------------------------------------------------------
expect() { # $1=want-exit $2..=args
  local want="$1"; shift
  "$BIN" "$@" >/dev/null 2>&1
  local rc=$?
  [ "$rc" = "$want" ] || fail "expected exit $want, got $rc  <=  $*"
}
# one space in the CSV used to silently disarm the degradation guard
expect 3 --node-kind task --session-type "fresh×docs" --signals "security, complex-reasoning"
expect 3 --node-kind task --session-type "fresh×docs" --signals "security,complex-reasoning"
# `06` used to be declared unmapped — a false statement about the source document
expect 0 --node-kind pr --use-case 06
expect 0 --node-kind pr --use-case 6
# a huge integer used to bypass the range guard and leak a raw bash error to stdout
expect 4 --node-kind pr --use-case 99999999999999999999
if "$BIN" --node-kind pr --use-case 99999999999999999999 2>&1 >/dev/null | command grep -q "integer expression"; then
  fail "raw bash error text still leaks into agent-visible output"
fi
# `fix` is the same cognitive work as `debug`; guarding one string only is a spelling check
expect 3 --node-kind task --session-type "fresh×fix"
expect 3 --node-kind task --session-type "fresh×debug"
# fabricated Table A rows must stay withdrawn (NULL_PROFILE = status quo, not a guess)
for uc in 4 5 16 17 24 25 26; do
  expect 3 --node-kind task --use-case "$uc"
done
# UC33 must credit recipe-10 ("Recipe #10" in the catalog), never recipe-04
"$BIN" --node-kind session --use-case 33 --format json 2>/dev/null \
  | command grep -q '"recipe_id":"recipe-10"' || fail "UC33 must map to recipe-10 (ledger integrity)"

# ---------------------------------------------------------------------------
# 4. Honesty check on the `mode` axis.
#    The red-team showed all four modes produce byte-identical output: the axis is
#    INERT and "44 combinations" was 11 behaviours tested four times. We do not
#    pretend otherwise — we assert the inertness so the doc cannot overclaim.
# ---------------------------------------------------------------------------
uniq_n="$(for m in $MODES; do "$BIN" --node-kind task --session-type "${m}×refactor" --format text 2>/dev/null; done | sort -u | wc -l | tr -d ' ')"
[ "$uniq_n" = "1" ] || note "NOTE: mode axis is no longer inert ($uniq_n behaviours) — update SKILL.md"

# ---------------------------------------------------------------------------
# 5. Determinism — the whole premise of computing the verdict outside the model.
# ---------------------------------------------------------------------------
a="$("$BIN" --node-kind pr --use-case 6 --stakes high --format json 2>/dev/null)"
b="$("$BIN" --node-kind pr --use-case 6 --stakes high --format json 2>/dev/null)"
c="$("$BIN" --node-kind pr --use-case 6 --stakes high --format json 2>/dev/null)"
{ [ "$a" = "$b" ] && [ "$b" = "$c" ]; } || fail "non-deterministic output across runs"

if [ "$fails" -eq 0 ]; then
  note "lens-dispatch matrix: PASS"; exit 0
else
  printf 'lens-dispatch matrix: %d FAILURE(S)\n' "$fails" >&2; exit 1
fi
