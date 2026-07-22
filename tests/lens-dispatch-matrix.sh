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
#    ⚠️ This is NOT a non-regression floor — that claim was retracted for the DISPATCH path
#    (see SKILL.md "The floor claim, corrected"). An earlier version of this comment said
#    the floor "rests on" this assertion, which quietly re-asserted the retracted claim from
#    inside the test suite. What this actually proves is narrower and worth stating exactly:
#    every DISPATCH is traceable to a labelled source. Traceability is not safety.
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
# ⚠️ Capture into a variable — do NOT pipe. Under `set -o pipefail` this check was DEAD:
#    the pipeline returned $BIN's exit 4 (rightmost non-zero) even when grep MATCHED, so
#    `if` was false and `fail` never ran. A leak-detector that cannot fire. Found by the
#    re-verifier — and it is the exact pipe-masks-exit-code trap this repo's own
#    script-safety §6 documents, committed inside the test written to prove the fix.
_err="$("$BIN" --node-kind pr --use-case 99999999999999999999 2>&1 >/dev/null)"
case "$_err" in *"integer expression"*) fail "raw bash error text still leaks into agent-visible output" ;; esac
# meta-check: prove the detector above CAN fire, so it never silently rots again
_probe="$(bash -c 'echo "[: 99: integer expression expected" >&2' 2>&1 >/dev/null)"
case "$_probe" in *"integer expression"*) : ;; *) fail "leak-detector is inert — it cannot fire even on a known leak" ;; esac
# `fix` is the same cognitive work as `debug`; guarding one string only is a spelling check
expect 3 --node-kind task --session-type "fresh×fix"
expect 3 --node-kind task --session-type "fresh×debug"
# N6 — an unknown --signals token used to silently no-op, leaving the degradation guard
# disarmed while the tool DISPATCHED. A typo must not be indistinguishable from absence.
expect 4 --node-kind pr --use-case 6 --signals "complex_reasoning"
expect 4 --node-kind pr --use-case 6 --signals "complex reasoning"
expect 4 --node-kind pr --use-case 6 --signals "security;complex-reasoning"
# ...and every documented token must still resolve (a closed vocabulary, not a locked one)
expect 0 --node-kind pr --use-case 6 --signals "security,irreversible"
expect 0 --node-kind pr --use-case 6 --signals "untrusted-input,cross-org,time-critical"
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
# `note` prints and returns 0 — it whispers, it does not assert. SKILL.md claims "the
# test asserts the inertness", so it must actually fail. (Re-verifier finding N4.)
[ "$uniq_n" = "1" ] || fail "mode axis is no longer inert ($uniq_n behaviours) — update SKILL.md, then this line"

# ---------------------------------------------------------------------------
# 4b. GOLDEN PIN — the check whose absence made both suites blind.
#
# WHY: the re-verifier built a mutant that repointed UC11 ("new service architecture")
# from recipe-02 (Architect+Conservative+Fowler+Systems-Thinker) to recipe-14
# (Jobs+Musk+Creator+Visionary) — a fabrication of exactly the kind that got v0.1.0
# REFUTED — and BOTH suites reported green. A second mutant gutted SecOps, Privacy, QA
# and Critic out of the high-stakes PR-review stack: 30/30 PASS.
# Cause: the self-test's matcher compares only `verdict|reason`, so ANY recipe_id and
# ANY lens_stack satisfied it. 30 assertions about the PATH of the decision, zero about
# its CONTENT. The regression suite for a mis-mapped-lens defect could not see a
# mis-mapped lens.
#
# These 14 lines are the content, pinned. Each is a verbatim transcription of a catalog
# §13.5 / §13 row. Changing a lens set now REQUIRES changing this file — which is the
# point: the diff becomes visible in review instead of silent.
# ---------------------------------------------------------------------------
golden() { # $1=use-case  $2=expected "recipe_id|entry:§ref,..."
  local uc="$1" want="$2" got
  got="$("$BIN" --node-kind task --use-case "$uc" --format json 2>/dev/null \
        | jq -r '"\(.recipe_id)|\([.lens_stack[]|"\(.entry):\(.ref)"]|join(","))"')"
  # Real newlines, not "\n": fail() prints with %s, so an escape would render literally
  # — a diff report you cannot read is a diff report nobody acts on.
  [ "$got" = "$want" ] || fail "UC$uc lens drift
    want: $want
    got : $got"
}
golden 1  'recipe-01|tome:§1.12,critical:§1.1,devils-advocate:§1.13,conservative:§1.9'
golden 6  'recipe-04|tech-lead:§9.35,ux:§9.44,secops:§9.25,privacy:§9.29,qa:§9.22,critic:§4.16'
golden 11 'recipe-02|architect:§9.13,conservative:§1.9,fowler:§5.22,systems-thinker:§2.9'
golden 19 'recipe-03|devsecops:§9.8,suspicious:§1.3,pentester:§9.26,anubis-judgment:§7.17'
golden 21 'recipe-15|dpo:§9.29,auditor:§10.10,compliance:§9.28,anubis-judgment:§7.17'
golden 23 'uc-23|editor:§10.29,researcher:§10.27,patient:§3.14'
golden 27 'recipe-14|jobs-simplicity:§5.1,musk-first-principles:§5.2,creator:§4.12,visionary:§4.33'
golden 28 'recipe-12|buffett-value:§5.15,munger-models:§5.16,long-term:§1.31'
golden 29 'recipe-07|user-advocate:§9.44,engineering-centric:§9.1,business-centric:§11.1'
golden 30 'uc-30|tdd-beck:§5.24,qa-engineer:§9.22,methodical:§1.17'
golden 32 'uc-32|critic-shadow:§4.16,devils-advocate:§1.13,patient:§3.14,honest:§3.26'
golden 33 'recipe-10|tech-lead:§9.35,ux:§9.44,secops:§9.25,privacy:§9.29,qa:§9.22,critic:§4.16'
# UC15 / UC18 are NOT pinned above — they are catalog §13.5.D (Debugging / investigation),
# so the degradation guard now withholds their lens (N5: the guard must be a property of
# the WORK, not of the flag used to name it). Their lens_stack is never emitted, so it
# cannot be pinned through the CLI.
# What IS asserted: the reason `protected-work-use-case-lens-withheld` is reachable ONLY
# when a transcribed mapping EXISTS — so this proves the Table A rows are still there,
# while `use-case-has-no-transcribed-mapping` would prove they had been dropped. The two
# must never be conflated (that conflation was the `06` defect: asserting something FALSE
# about the source document).
# Honest residual: WHICH recipe 15/18 point at is no longer pinned. Accepted — the value
# is never emitted, so a drift there has zero behavioral effect. Dormant data, not a lens.
withheld() { # $1=use-case — assert "mapping exists AND is withheld", not merely exit 3
  local uc="$1" got
  got="$("$BIN" --node-kind task --use-case "$uc" --format json 2>/dev/null | jq -r '.reason')"
  [ "$got" = "protected-work-use-case-lens-withheld" ] \
    || fail "UC$uc must be withheld-with-mapping, got reason '$got'"
}
withheld 15
withheld 18
# ...and the guard must NOT swallow the withdrawal signal for the fabricated rows
for uc in 16 17; do
  _r="$("$BIN" --node-kind task --use-case "$uc" --format json 2>/dev/null | jq -r '.reason')"
  [ "$_r" = "use-case-has-no-transcribed-mapping" ] \
    || fail "UC$uc must still report the withdrawal, got '$_r' (guard is masking it)"
done

# self-check: the pin must be capable of failing (guards against a no-op golden()).
# stderr is suppressed for THIS call only — the probe is designed to mismatch, and an
# expected "FAIL: UC6 lens drift" in the log is indistinguishable from a real regression
# to whoever reads CI. Not a subshell: fail() must still increment `fails` in this shell.
_g_before=$fails; golden 6 'recipe-99|nonsense:§0.0' 2>/dev/null
[ "$fails" -gt "$_g_before" ] || fail "golden() is inert — it cannot detect drift"
fails=$_g_before   # discard the deliberate probe failure

# ---------------------------------------------------------------------------
# 4c. TABLE SIZES — the SKILL.md states these in plain text, so they must be counted,
#     not trusted. Hardcoding a count is the same defect as the old "21/21 PASS".
# ---------------------------------------------------------------------------
_a=0
for uc in $(seq 1 33); do
  _r="$("$BIN" --node-kind task --use-case "$uc" --format json 2>/dev/null | jq -r '.reason')"
  # A row EXISTS in Table A iff it either dispatched or was withheld-with-mapping.
  case "$_r" in resolved-use-case|protected-work-use-case-lens-withheld) _a=$((_a+1)) ;; esac
done
[ "$_a" -eq 14 ] || fail "Table A has $_a mapped use-cases; SKILL.md claims 14"

_b=0
for w in $WORKS; do
  "$BIN" --node-kind task --session-type "fresh×${w}" >/dev/null 2>&1 && _b=$((_b+1))
done
[ "$_b" -eq 4 ] || fail "Table B resolves $_b works; SKILL.md claims 4"
note "tables: A=$_a mapped use-cases · B=$_b mapped works"

# ---------------------------------------------------------------------------
# 4d. --help must describe the behaviour the tool ACTUALLY has.
#
# WHY: the help text drifted out of sync the moment the guard was extended to `fix`, and
# stayed wrong through a whole repair round — no test looked at it. A user reading --help
# would have been told `fresh×fix` dispatches. That is the R2 headline defect (a claim
# corrected in one file and left stale in another) relocated into the user-facing contract.
# These assertions do not pin prose; they pin the terms that name real behaviour, so the
# next behaviour change forces the doc change instead of merely inviting it.
# ---------------------------------------------------------------------------
_help="$("$BIN" --help 2>&1)"
case "$_help" in
  *"work=debug|fix"*) : ;;
  *) fail "--help omits that the guard covers work=fix (stale since the R2 fix)" ;;
esac
case "$_help" in
  *"13.5.D"*) : ;;
  *) fail "--help omits the §13.5.D work-class guard (UC15-18 are withheld)" ;;
esac
case "$_help" in
  *"unknown"*) : ;;
  *) fail "--help omits that an unknown --signals token is INCONCLUSIVE" ;;
esac
# meta-check: prove these can fire, so they cannot rot into always-true string matches
case "$_help" in *"this-string-is-absent-on-purpose"*) fail "help-drift detector is inert" ;; esac

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
