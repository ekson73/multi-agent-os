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
#
# Function     : assert every claim bin/lens-dispatch + SKILL.md make about the dispatcher's
#                behaviour, provenance tables, and drift-tripwires — fail loud on any drift.
# Spec         : skills/lens-dispatch/SKILL.md · catalog §13/§13.5/§13.6 · session-type-taxonomy.md
# Idempotent   : yes — read-only over the artifact + a tempfile/in-place mutation battery that
#                restores every mutant it installs (trap + verified-clean baseline); the tree is
#                left byte-identical.
# Portability  : Bash 3.2+ (POSIX; no associative arrays / mapfile) · shasum|sha256sum · jq optional.
# Layer purity : community-clean — no org-specific names, jurisdictions, or credentials.
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
# ⚠️ labels are the catalog's entry names (§5.1 "Steve Jobs", §5.2 "Elon Musk"), kebab-cased.
#    This line previously pinned `jobs-simplicity`/`musk-first-principles` — labels that
#    appear ZERO times in the catalog (positive-controlled grep). The pin was locking in a
#    paraphrase AS IF it were the source: a golden test can enshrine a fabrication just as
#    faithfully as it enshrines a fact. Pinning is only as honest as what it was pinned to.
golden 27 'recipe-14|steve-jobs:§5.1,elon-musk:§5.2,creator:§4.12,visionary:§4.33'
golden 28 'recipe-12|buffett-value:§5.15,munger-models:§5.16,long-term:§1.31'
golden 29 'recipe-07|user-advocate:§9.44,engineering-centric:§9.1,business-centric:§11.1'
golden 30 'uc-30|tdd-beck:§5.24,qa-engineer:§9.22,methodical:§1.17'
golden 32 'uc-32|critic-shadow:§4.16,devils-advocate:§1.13,patient:§3.14,honest:§3.26'
golden 33 'recipe-10|tech-lead:§9.35,ux:§9.44,secops:§9.25,privacy:§9.29,qa:§9.22,critic:§4.16'
# ---------------------------------------------------------------------------
# BRIDGE-ROUTE golden pins (red-team H6, R3/F3).
#
# WHY these exist: every pin above uses `--use-case`, but ALL 16 DISPATCH combinations
# this matrix exercises resolve through `--session-type` (the bridge). So the content of
# the route the suite actually walks was UNPINNED — R2's "both suites blind to lens
# content" was still alive on the bridge while SKILL.md listed it as fixed. Verified by
# mutant M7 (`docs -> 23` retargeted to 27): documentation work silently received
# founder-vision lensing (jobs/musk/creator/visionary) and BOTH suites stayed green.
#
# The set is complete by construction: Table B maps exactly 4 works, and §4c counts that
# number from source — so a 5th mapped work fails the count, and each mapped work's lens
# content is pinned here. Coverage of the bridge route is total, not sampled.
# ---------------------------------------------------------------------------
golden_st() { # $1=work  $2=expected "recipe_id|entry:§ref,..."
  local w="$1" want="$2" got
  got="$("$BIN" --node-kind task --session-type "fresh×${w}" --format json 2>/dev/null \
        | jq -r '"\(.recipe_id)|\([.lens_stack[]|"\(.entry):\(.ref)"]|join(","))"')"
  [ "$got" = "$want" ] || fail "bridge fresh×$w lens drift
    want: $want
    got : $got"
}
PINNED_WORKS="refactor harmonize docs test"
golden_st refactor  'recipe-02|architect:§9.13,conservative:§1.9,fowler:§5.22,systems-thinker:§2.9'
golden_st harmonize 'uc-32|critic-shadow:§4.16,devils-advocate:§1.13,patient:§3.14,honest:§3.26'
golden_st docs      'uc-23|editor:§10.29,researcher:§10.27,patient:§3.14'
golden_st test      'uc-30|tdd-beck:§5.24,qa-engineer:§9.22,methodical:§1.17'

# TAXONOMY DRIFT GATE — the missing link that made the first R4/N1 repair unsound.
#
# Everything below ranges over `$WORKS`, a constant declared in THIS file. That makes the
# coverage assertion only as complete as the test's model of the work taxonomy. Measured:
# a mutant adding `probe` to BOTH `valid_work` and Table B produced a LIVE dispatching
# bridge route that the coverage loop never probed (`probe` ∉ $WORKS) — and the FIRST
# repair therefore SURVIVED it, while the source-regex it replaced had caught the
# single-line form. The repair regressed the one case the broken mechanism got right.
#
# Same defect one level deeper: a source-text model of the program was swapped for a
# test-side model of the program. So pin the model to the program. This is the ONE place
# source is parsed, and only to detect drift in a CONSTANT — `valid_work` is a single
# well-defined line, so any change to its shape breaks extraction and fails loudly
# (empty extraction => mismatch => fail, never a silent pass).
_vw="$("$BIN" --list-works 2>/dev/null)"
_vw_sorted="$(echo $_vw   | tr ' ' '\n' | sort | tr '\n' ' ')"
_wk_sorted="$(echo $WORKS | tr ' ' '\n' | sort | tr '\n' ' ')"
[ -n "$_vw" ] || fail "--list-works returned nothing — the taxonomy gate is INERT"
[ "$_vw_sorted" = "$_wk_sorted" ] \
  || fail "work taxonomy drift: the tool declares [$_vw_sorted] but this suite ranges over [$_wk_sorted].
    \$WORKS is this file's transcription of session-type-taxonomy.md; --list-works is the
    program's own declaration. A divergence means one of the two drifted from the document."
# ...and the tool must actually accept each one (the other direction, behaviourally).
for w in $WORKS; do
  _tr="$("$BIN" --node-kind task --session-type "fresh×${w}" --format json 2>/dev/null | jq -r '.reason')"
  [ "$_tr" != "invalid-session-work" ] || fail "\$WORKS lists '$w' but the tool rejects it"
done

# NEAR-MISS BATTERY (red-team H6, R7/ask-3) — the honest-drift half of the residual.
#
# The path-count invariants below constrain the NUMBER of paths. They say nothing about the
# CONDITION inside an existing path. R7's finding: widening that condition in `valid_work`
# ALONE passes every gate silently. It creates no unpinned dispatch (Table B's lookup stays
# exact-match, so the work resolves to nothing) — garbage moves from *rejected* to *unmapped*,
# the fail-safe direction. So "0 dispatches" would be a VACUOUS assertion here; what actually
# changes is the reason: `invalid-session-work` -> `no-bridge-mapping-for-work`. Assert what
# the program DID with a near-miss, not merely that it did not dispatch.
#
# Threat model (R7's reframe, adopted): this defends against honest DRIFT — a maintainer
# widening a condition by CLASS without seeing the blast radius — not against an adversary,
# who can edit tests as easily as bin/. Honest drift widens by class, so probe the classes.
#
# The three variants are not redundant; each catches a shape the others miss. MEASURED:
#     widen $w*   -> caught by  docsx, docsdocs        widen $w?  -> caught by  docsx ONLY
#     widen *$w   -> caught by  xdocs, docsdocs        widen ?$w  -> caught by  xdocs ONLY
#     widen *$w*  -> caught by  docsx, xdocs, docsdocs
# The doubled form looked like it subsumed the other two under the first three shapes; the
# single-char globs refuted that. A coverage claim is only as wide as the set actually run.
#
# This battery is LOAD-BEARING, not belt-and-braces — measured by disabling it and re-running
# every other gate against each mutant: $w* / *$w / *$w* all pass GREEN (rc=0, zero other
# FAILs), which is R7's finding reproduced (independently confirmed R8/ask-2). Those three
# PRESERVE the exact match (`docs` still matches `docs*`), so the program keeps working
# normally while quietly accepting garbage — the realistic drift.
# The single-char forms REPLACE the exact match instead, so every legitimate work is rejected
# and ~11 assertions fire at once — the corpus-level `DISPATCH count is 0; SKILL.md claims 16`,
# 4x exit-code, 4x lens-drift, and 11x `$WORKS lists '<w>' but the tool rejects it`. Those
# mutants are caught by that CLUSTER, not by any single assertion, and NOT by `_n_dispatch`
# (the other thing in this file called a "DISPATCH count", which does not fire). The battery
# fires there too but does not earn the catch. Stated at this precision because the previous
# wording named one ambiguous mechanism and was measured wrong by R8 — in the sentence whose
# next line is the warning below.
# Precision matters: overstating which mechanism does the work is how the SKILL.md claims
# drifted from their mechanisms four times.
# Derived from --list-works (pinned to $WORKS by the gate above), so it grows with the vocabulary.
_vw_ws=" $(echo $_vw) "
_nm=0
for _w in $_vw; do
  for _v in "${_w}x" "x${_w}" "${_w}${_w}"; do
    case "$_vw_ws" in *" $_v "*) continue ;; esac   # a declared work is not a near-miss
    _nm=$((_nm+1))
    _nr="$("$BIN" --node-kind task --session-type "fresh×${_v}" --format json 2>/dev/null | jq -r '.reason')"
    [ "$_nr" = "invalid-session-work" ] \
      || fail "near-miss '$_v' was ACCEPTED (reason=$_nr, expected invalid-session-work) — valid_work's
    condition is wider than the vocabulary --list-works declares. Not an unpinned dispatch, but
    undetected semantic drift: input the taxonomy rejects is now merely unmapped."
  done
done
[ "$_nm" -gt 0 ] || fail "near-miss battery examined ZERO variants — INERT (empty --list-works?)"

# COVERAGE, asserted directly instead of inferred from a count (red-team H6, R4/N1).
#
# v0.4.0 claimed bridge coverage was "total by construction" and rested that on the row
# COUNT: 4 rows, 4 pins. The count was a source-text regex matching only single-line case
# arms — so `probe)⏎  echo "11" ;;` (identical bash, identical semantics) grew Table B to
# 5 LIVE works while the counter still said 4, golden_st pinned 4, and the 5th dispatched
# a lens with zero content coverage. Green suite. The mechanism was weaker than the claim,
# which is this tool's recurring defect at the fourth iteration.
#
# The repair is not a better regex. A count is a PROXY for the property; assert the
# PROPERTY: every work that dispatches through the bridge must be pinned. Behavioural, so
# source formatting cannot fool it, and it fails on ANY new dispatching work however it is
# spelled. `_a` was immune all along precisely because it probed the CLI instead of the text.
# Range over the ROWS the program declares, not over a work-list this file maintains.
# A row for a work absent from $WORKS was invisible to the previous loop; it is not to this
# one. `_cov` is the N3 inertness counter PORTED HERE (red-team H6, R6/ask-2b): a typo'd
# flag (`--list-bridges`) yields zero rows and would otherwise pass VACUOUSLY — the same
# defect as the dead leak-detector, in a new mechanism. Applying it to the loop this one
# replaced would have discarded the fix along with the loop.
_cov=0
for _kv in $("$BIN" --list-bridge 2>/dev/null); do
  _cov=$((_cov+1))
  _w="${_kv%%:*}"
  _cw="$("$BIN" --node-kind task --session-type "fresh×${_w}" --format json 2>/dev/null | jq -r '.reason')"
  [ "$_cw" = "resolved-bridge" ] || continue
  case " $PINNED_WORKS " in
    *" $_w "*) ;;
    *) fail "declared bridge row '$_kv' DISPATCHES but has no golden_st pin — bridge coverage is incomplete" ;;
  esac
done
[ "$_cov" -gt 0 ] || fail "coverage loop examined ZERO rows — INERT (bad flag name? empty --list-bridge?)"

# RESOLUTION-PATH TRIPWIRE (red-team H6, R8) — the STAGE, not the shape.
#
# R8 broke every mechanism above with ONE line, strictly weaker than the M10 boundary:
#     work="$(split_session_type "$st" work)"   ->   ... work | tr -d '-_.')"
# `fresh×re-factor` -> DISPATCH|recipe-02 on the mutant, INCONCLUSIVE on clean. Declarations
# byte-identical, all three path-counts pass, near-miss battery blind, matrix rc=0, self-test 40/40.
#
# The structural reason it was invisible, which is the whole lesson: every gate above derives
# its inputs FROM the declaration (the drift gate compares --list-works to $WORKS; the coverage
# loop ranges over --list-bridge; the battery generates its 33 from --list-works). But the token
# is PREPARED before either lookup consults the declaration. A widening placed upstream of the
# lookup is unreachable by declaration-derived generation BY CONSTRUCTION — no suffix/prefix/
# doubling of a declared work can reach a stage that runs before the declaration is read.
# So this is not "one more variant". Separator-shaped near-misses would close `tr -d '-_.'` and
# not `tr -d ' '`, not a stemmer, not a soundex. The gap is the STAGE.
#
# A stage is enumerable where a shape-space is not. This pins the complete code path from raw
# CLI input to recipe id — norm() · split_session_type() · valid_work() · use_case_for_work()
# and the decide() lines that wire them — and fails on ANY byte-change to it. Shape-agnostic:
# tr, sed, parameter expansion, a stemmer and a soundex all change bytes equally.
#
# HONEST SCOPE, because five versions of the SKILL.md have overstated in this exact place:
#   * It is a TRIPWIRE, not a proof. It says the path did not change; it never says the path
#     is correct.
#   * It reads source — but it is a hash, the limit case of a count, not an extraction. An
#     extraction can silently read the wrong value (how `_n_emit` was defeated); a hash cannot
#     be silently wrong, only loudly stale.
#   * Cost is real and deliberate: a legitimate refactor must re-pin. That friction IS the
#     mechanism — it forces a maintainer to notice they touched a safety-relevant stage.
#   * It does NOT cover a widening achieved WITHOUT editing this code (via the data tables —
#     those have their own gates above), nor an edit accompanied by a deliberate re-pin. The
#     latter is the adversary who edits tests/ as easily as bin/, explicitly out of scope.
# NO SELECTION AT ALL — the pin is the FILE. Three versions were needed to get here, and the two
# discarded ones are the argument:
#   v1 pinned a grep-filtered slice of decide(). I broke it myself: a one-line insert the filter
#      did not match — work="${work//-/}" — made fresh×re-factor DISPATCH with the suite green.
#   v2 pinned the whole decide() body. The red-team broke THAT with two one-line transforms placed
#      UPSTREAM of decide() — at the --session-type arg-parse assignment, and at the decide() call
#      site — leaving every pinned byte untouched. Verified independently against the v2 commit:
#      both OPEN (rc=0, zero FAILs) while an in-pin positive control was CAUGHT, so the negatives
#      are meaningful and not a dead harness.
# The sentence v2 shipped — "a hash over the whole function has no model to evade" — is FALSE, and
# it is the same error one level up. THE RANGE IS THE MODEL. `awk '/^decide()/,/^}/'` is a
# selection exactly as the grep was; widening a selection is not removing one. The residual is
# never "a line the filter missed" — it is A STAGE THE SELECTION DOES NOT COVER, and the entire
# arg-parse/dispatch prologue was outside it. By the time the pinned code ran, $SESSION_TYPE had
# already been rewritten.
# Hence: no selection. Every byte of the binary, or the tripwire is again precise about the wrong
# thing.
#   COST, stated rather than hidden: EVERY edit to bin/lens-dispatch re-pins — comments included.
#   That is deliberate. The re-pin ritual is change → run this battery → update the pin. A pin
#   that only fires on lines someone already thought to name buys precision with blindness.
#   RESIDUAL, measured not assumed: a file hash cannot cover what is not IN the file — the
#   environment and the interpreter. Grepped for externally-settable reads: DOGFOOD_LEDGER_DIR is
#   the only env var reaching behaviour (the confidence read, red-team R3/F1) and it does NOT
#   reach the dispatch decision. That is the honest boundary of this mechanism.
[ -s "$BIN" ] || fail "tripwire INERT: $BIN is empty or missing"
# NO INERTNESS GUARD IS NEEDED, and that is the point — the earlier machinery existed only
# because an EXTRACTION had a shape to be truncated. v2 needed a 7-marker presence loop plus a
# positional tail assertion (the loop alone was defeatable: a padding string carrying the tail
# marker's TEXT plus a line starting with `}` truncated decide() 80→21 lines with all 7 markers
# passing; what caught it was an unrelated invariant, i.e. true by accident). With no selection
# there is nothing to truncate: any missing byte changes the hash. `[ -s "$BIN" ]` above covers
# the degenerate empty/missing case so the failure is legible rather than merely a mismatch.
#
# HASH THE FILE ON DISK DIRECTLY — never $(cat "$BIN") first. Copilot (H6 PR-review, #279) surfaced
# that command substitution strips trailing newlines, so `printf '%s' "$(cat "$BIN")" | shasum` was
# blind to a trailing-newline-only change: measured, bin/lens-dispatch + one extra "\n" produced the
# IDENTICAL old pin (e21676…) — a real byte-change invisible to a tripwire that claims "any byte
# change fails". This is the recurring class one turn deeper: R8's lesson ("the pin's computation
# must BE the check's computation") was satisfied, but the common method I had standardized on
# ($(cat)) carried its OWN hole. `shasum -a 256 "$BIN"` is BOTH its own instrument (the pin is now
# reproducible by anyone with `sha256sum bin/lens-dispatch`) AND byte-complete (covers the trailing
# newline the substitution ate). Strictly stronger: same file, now every on-disk byte.
if command -v shasum >/dev/null 2>&1; then _path_hash="$(shasum -a 256 "$BIN" | cut -d' ' -f1)"
else                                       _path_hash="$(sha256sum   "$BIN" | cut -d' ' -f1)"; fi
_PATH_PIN='f3bb986cc232bea3a3dc1f78bcdf507de5617ca86dca289a7f4206e9b3ae7543'
[ "$_path_hash" = "$_PATH_PIN" ] || fail "resolution path CHANGED (sha256 $_path_hash != pinned $_PATH_PIN).
    Every input-to-dispatch stage is pinned because the gates above sample inputs FROM the
    declaration, and cannot see a transform applied BEFORE the declaration is read (R8).
    If this change is intentional: re-run the mutation battery, then update _PATH_PIN. Do not
    update the pin without re-reading what the change does to token acceptance."

# PATH-COUNT INVARIANTS (red-team H6, R6/ask-1 + ask-3).
# --list-* publishes what the program CONTAINS; that is a declaration, and an edit can move
# the behaviour while leaving the declaration byte-identical — measured three times, the
# same mutant surviving three different fixes. These three counts constrain the other side:
# they do not read a VALUE out of the source (an extraction, silently defeatable), they
# assert a NUMBER that any added path increments and any reshaping breaks. Fails closed.
_n_accept="$(awk '/^valid_work\(\)/,/^}/' "$BIN" | grep -c 'return 0')"
# ⚠️ GENERIC echo-count, not `grep -c 'echo "${kv#*:}"'`. That first form was an EXTRACTION
#    wearing a count's clothes: it counts one specific spelling, so a second emitting path
#    written any other way (`echo "11"`) left it at 1. Measured — the mutant survived. The
#    generic count moves 2 -> 3 for ANY added emission regardless of how it is spelled.
_n_emit="$(awk '/^use_case_for_work\(\)/,/^}/' "$BIN" | grep -c 'echo ')"
_n_dispatch="$(grep -c 'echo "DISPATCH' "$BIN")"
[ "$_n_accept"   -eq 1 ] || fail "valid_work has $_n_accept accepting paths, expected 1 — a second one accepts works --list-works never declares"
[ "$_n_emit"     -eq 2 ] || fail "use_case_for_work has $_n_emit echo statements, expected 2 (the lookup hit + the empty miss) — a third is an emitting path --list-bridge never declares"
[ "$_n_dispatch" -eq 2 ] || fail "decide() has $_n_dispatch DISPATCH exits, expected 2 (transcribed + bridge) — a third bypasses Table B entirely"
# self-check: this pin must be capable of failing (same discipline as golden()'s probe).
_gs_before=$fails; golden_st docs 'recipe-99|nonsense:§0.0' 2>/dev/null
[ "$fails" -gt "$_gs_before" ] || fail "golden_st() is inert — it cannot detect drift"
fails=$_gs_before

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

# ---------------------------------------------------------------------------
# BRIDGE-ROUTE GUARD reachability proof (red-team H6, R3/F2).
#
# THE PROBLEM this solves: the §13.5.D guard must hold on the bridge route too, but that
# path is UNREACHABLE today — Table B maps no work to 15-18. A test cannot assert on a
# path it cannot reach, so the natural move is to write no test and claim "it's fine
# because nothing points there". That claim is TRUE and USELESS: it describes today's
# table, not the guard. The first fix shipped exactly that state — one call site, the
# other route open, protected only by an accident of data (`harmonic` L9: safety that
# depends on nobody-later-mapping-a-work-to-15 is safety that depends on recall).
#
# SO: the test CONSTRUCTS the reachability. One-token mutant in an isolated copy, with an
# applied-mutation control — because a mutation test whose mutant never landed is a
# FALSE-PASS GENERATOR that measures the `sed`, not the suite (learned the hard way: the
# first mutation run here reported CAUGHT for a mutant that was never applied).
_mut_dir="$(mktemp -d)"; _mut="$_mut_dir/lens-dispatch"
sed 's/refactor:11/refactor:15/' "$BIN" > "$_mut"   # Table B is DATA now; re-anchored (R6)
chmod +x "$_mut"
if cmp -s "$BIN" "$_mut"; then
  fail "bridge-guard proof is INERT — the mutant never applied (sed did not match)"
else
  _mr="$("$_mut" --node-kind task --session-type "fresh×refactor" --format json 2>/dev/null | jq -r '.reason')"
  [ "$_mr" = "protected-work-use-case-lens-withheld" ] \
    || fail "bridge route does NOT honour the §13.5.D guard: with Table B pointed at UC15 it answered '$_mr' (expected withheld). The guard has a route it does not cover."
fi
rm -rf "$_mut_dir"

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

# Table B rows — counted BEHAVIOURALLY (red-team H6, R3/F4 then R4/N1).
#
# Two wrong versions preceded this one:
#   v0.3.0 counted works that DISPATCH → `chore -> 5` grew the table while resolving to
#          NULL_PROFILE (UC5 has no recipe) and stayed invisible. Growth detector, blind
#          to growth.
#   v0.4.0 counted `echo "N"` arms in the source text → a two-line case arm is identical
#          bash and invisible to the regex. Parsing source to describe behaviour re-creates
#          the whole class: the model of the program is not the program.
#
# A row EXISTS (and is reachable) iff the bridge path got far enough to look it up. The
# reason strings already encode that, so ask the program instead of reading it.
# NEGATIVE list on purpose: a reason string added later lands in the counted set and fails
# LOUDLY. A positive allow-list would silently drop it — undercount, exactly the failure
# being repaired. When in doubt, default to the branch that breaks the build.
#   excluded: no-bridge-mapping-for-work        (no row at all)
#             complex-reasoning-degradation-guard (guard fires before the lookup)
#   counted : resolved-bridge · bridge-target-has-no-mapping · protected-work-...-withheld
# Honest residual: a row for `debug`/`fix` is unreachable behind the degradation guard, so
# it is invisible here. That row is DEAD (no lens can ever be emitted through it), so the
# count measures LIVE rows — which is the set the coverage assertion above ranges over.
_b=0
for w in $WORKS; do
  _r="$("$BIN" --node-kind task --session-type "fresh×${w}" --format json 2>/dev/null | jq -r '.reason')"
  case "$_r" in
    no-bridge-mapping-for-work|complex-reasoning-degradation-guard) ;;
    *) _b=$((_b+1)) ;;
  esac
done
[ "$_b" -eq 4 ] || fail "Table B has $_b live rows; SKILL.md claims 4"
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
# the guard covers BOTH routes — help must say so, or it re-creates the one-route illusion
case "$_help" in
  *"SAME guard as 4, on the"*) : ;;
  *) fail "--help omits that the §13.5.D guard also applies on the --session-type route" ;;
esac
# --format is pinned by BEHAVIOUR, not by prose. ⚠️ The first draft of this check matched
# `*"json|text"*` in --help — a string that already existed in the usage block before the
# validation was written, so it passed with or without the fix: an always-true match, the
# exact rot the meta-check below exists to catch. A pin must be able to fail.
"$BIN" --node-kind task --use-case 6 --format bogus >/dev/null 2>&1 \
  && fail "--format accepts an invalid value (silently emits JSON instead of rejecting)"
"$BIN" --node-kind task --use-case 6 --format TEXT >/dev/null 2>&1 \
  && fail "--format is case-permissive: 'TEXT' must be rejected, not silently treated as JSON"
"$BIN" --node-kind task --use-case 6 --format text >/dev/null 2>&1 \
  || fail "--format text must still be accepted (validation over-tightened)"
# meta-check: prove these can fire, so they cannot rot into always-true string matches
case "$_help" in *"this-string-is-absent-on-purpose"*) fail "help-drift detector is inert" ;; esac

# ---------------------------------------------------------------------------
# 4e. SIGNALS VALIDATION — glob-injection must fail CLOSED (red-team H6, coderabbit PR #279).
#
# THE BUG (reproduced, fail-OPEN): valid_signals split its CSV with `for tok in $csv`. An
# unquoted expansion word-splits THEN pathname-expands; `IFS=,` governs only the split. So
# with a decoy file named after a signal in the CWD, `--signals '*'` glob-expanded to that
# filename, PASSED the vocabulary check, and DISPATCHed instead of failing closed. N6 had
# hardened the vocabulary CHECK; the token EXTRACTION was where the property had to hold —
# the recurring class (the correction applied where the finding showed, not where it holds).
#
# This guard is LOAD-BEARING BY CONSTRUCTION: it MANUFACTURES the exact condition the bug
# needs — a signal-named decoy in the CWD — so a regression to `for tok in $csv` makes '*'
# glob-expand to valid signals and DISPATCH (exit 0), tripping the `= 4` assertion wherever
# CI runs. The valid-input counter-assertion additionally rules out a reject-all over-fix.
# (The one-time load-bearing proof against the PRE-fix bin is recorded in the PR, NOT here —
# a git-HEAD self-check would invert the moment the fix is committed and fire false failures.)
# ---------------------------------------------------------------------------
_sig_rc() { # $1=signals -> exit code of a run FROM a decoy sandbox (no masking pipe)
  local _s="$1" _sb _rc
  _sb="$(mktemp -d)"; : > "$_sb/security"; : > "$_sb/complex-reasoning"; : > "$_sb/irreversible"
  ( cd "$_sb" && "$BIN" --node-kind ticket --use-case 1 --signals "$_s" >/dev/null 2>&1 ); _rc=$?
  rm -rf "$_sb"; printf '%s' "$_rc"
}
[ "$(_sig_rc '*')"        = 4 ] || fail "glob-injection OPEN: --signals '*' from a decoy dir did not fail closed (expected INCONCLUSIVE exit 4)"
[ "$(_sig_rc 'sec*')"     = 4 ] || fail "partial-glob token 'sec*' not rejected (expected INCONCLUSIVE exit 4)"
[ "$(_sig_rc 'security')" = 0 ] || fail "signals guard over-rejects: a valid token must still DISPATCH from a dir containing files"

# ---------------------------------------------------------------------------
# 4b. `--format json` without jq must FAIL CLOSED — never a reduced schema.
# json is the DEFAULT format, so this branch was the more likely one off-CI, and it used to emit a
# DIFFERENT contract under the SAME flag: 5 keys instead of 11 (no lens_stack / ratified_cycles /
# harness_mode / bridge_authored / expected_3_output / recommended_action) with rc=0 and no warning.
# A consumer reading `.lens_stack` got null and could not tell "no lenses" from "smaller schema".
# ⚠️ Asserts BOTH directions: json REFUSES (exit 5) and text STILL WORKS — a fail-closed gate that
# also breaks the working path is a regression, not a fix. Built by symlinking every real bin
# EXCEPT jq: a failing `jq` stub would test "broken", not "absent" (`command -v` still finds a stub).
_nojq_path() {
  local d="$1" src b
  for src in /usr/bin /bin /usr/sbin /sbin /opt/homebrew/bin /usr/local/bin; do
    [ -d "$src" ] || continue
    for f in "$src"/*; do
      b="$(basename "$f")"; [ "$b" = jq ] && continue
      [ -e "$d/$b" ] || ln -sf "$f" "$d/$b" 2>/dev/null
    done
  done
}
_njdir="$(mktemp -d)"; _nojq_path "$_njdir"
if PATH="$_njdir" command -v jq >/dev/null 2>&1; then
  fail "jq-absent test is BLIND: jq still reachable on the stripped PATH"
elif ! PATH="$_njdir" command -v grep >/dev/null 2>&1; then
  fail "jq-absent test is BLIND: the stripped PATH lost grep, so any failure is the harness, not the tool"
elif ! PATH="$_njdir" command -v bash >/dev/null 2>&1; then
  # `#!/usr/bin/env bash` resolves `bash` THROUGH PATH, not absolutely — so a stripped PATH without
  # it makes the shebang itself fail, and every rc below would measure the harness, not the gate.
  fail "jq-absent test is BLIND: the stripped PATH lost bash, so the shebang would fail before the tool runs"
else
  # ⛔ INVOKE "$BIN" DIRECTLY — never `sh "$BIN"`. The tool ships `#!/usr/bin/env bash` and uses
  #    `set -o pipefail`; forcing it through `sh` bypasses that contract and runs it under whatever
  #    /bin/sh happens to be. That passes HERE by accident (macOS /bin/sh IS bash-3.2, measured:
  #    `$BASH_VERSION` = 3.2.57) and FAILS on the ubuntu-latest runner this PR's own workflow uses,
  #    where /bin/sh is dash: measured `dash ./bin/lens-dispatch …` → `set: Illegal option -o
  #    pipefail` (line 56) → **rc=2**, not 5.
  #    ⚠️ The damage is the DIAGNOSIS, not the red: rc=2 trips the `!= 5` branch, whose message
  #    reads "a reduced schema may be shipping" — so a harness defect would be reported as the exact
  #    schema regression this section exists to detect, sending the next reader to the wrong file.
  #    A regression test must exercise the SHIPPED runtime; the stripped PATH already supplies
  #    `env` + `bash` for the shebang (asserted by the grep control above).
  ( PATH="$_njdir" "$BIN" --node-kind decision --use-case 6 >/dev/null 2>&1 ); _njrc=$?
  [ "$_njrc" = 5 ] || fail "--format json without jq did not fail closed (expected exit 5, got $_njrc — a reduced schema may be shipping)"
  ( PATH="$_njdir" "$BIN" --node-kind decision --use-case 6 --format text >/dev/null 2>&1 ); _txrc=$?
  [ "$_txrc" = 0 ] || fail "--format text broke without jq (expected exit 0, got $_txrc — the gate over-refused)"
fi
rm -rf "$_njdir"

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
