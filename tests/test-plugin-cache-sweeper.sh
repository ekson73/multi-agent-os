#!/usr/bin/env bash
# Test: bin/plugin-cache-sweeper.sh — orphaned plugin staging-clone reclaim.
# Portable (bash 3.2). Exit 0 = all pass; 1 = a failure.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$HERE/bin/plugin-cache-sweeper.sh"
FIX="$(mktemp -d 2>/dev/null || mktemp -d -t 'pcsweep')"
trap 'rm -rf "$FIX"' EXIT
fail=0
ok() { printf '  ok   %s\n' "$1"; }
no() { printf '  FAIL %s\n' "$1"; fail=1; }

echo "test-plugin-cache-sweeper:"

NOW_S=$(date +%s)
OLD_MS=$(( (NOW_S - 86400) * 1000 ))   # 1 day ago  -> eligible
NEW_MS=$(( NOW_S * 1000 ))             # now        -> too young

# ── fixtures ────────────────────────────────────────────────────────────────
CACHE="$FIX/cache"
mkdir -p "$CACHE/marketplace-official/1.0.0"          # a REAL install (never touched)
mkdir -p "$CACHE/temp_git_${OLD_MS}_aaaaaa"           # eligible orphan
mkdir -p "$CACHE/temp_subdir_${OLD_MS}_bbbbbb.clone"  # eligible orphan
mkdir -p "$CACHE/temp_git_${NEW_MS}_cccccc"           # too young
echo x > "$CACHE/marketplace-official/1.0.0/plugin.json"
echo x > "$CACHE/temp_git_${OLD_MS}_aaaaaa/file"

# the carcass: OLD name but FRESH mtime — an interrupted rm -rf rejuvenates its
# own victim, so an mtime-based gate would shield this forever. The name-embedded
# epoch is the immutable clock and must win.
mkdir -p "$CACHE/temp_git_${OLD_MS}_dddddd"
touch "$CACHE/temp_git_${OLD_MS}_dddddd"

# a symlink wearing a staging name, pointing OUTSIDE the cache
mkdir -p "$FIX/outside/precious"; echo keep > "$FIX/outside/precious/data"
ln -s "$FIX/outside/precious" "$CACHE/temp_git_${OLD_MS}_eeeeee"

# ── 1. read-only by default ─────────────────────────────────────────────────
out="$("$BIN" --cache "$CACHE" 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && ok "exits 0 in report mode" || no "report mode exit=$rc"
case "$out" in *'"mode":"report"'*) ok "envelope reports mode=report" ;; *) no "mode missing: $out" ;; esac
case "$out" in *'"swept":0'*) ok "swept=0 without --apply" ;; *) no "swept non-zero in report mode: $out" ;; esac
[ -d "$CACHE/temp_git_${OLD_MS}_aaaaaa" ] && ok "deletes NOTHING without --apply" || no "deleted without --apply"
case "$out" in *'"would_sweep":3'*) ok "would_sweep=3 (2 orphans + 1 carcass)" ;; *) no "would_sweep wrong: $out" ;; esac

# ── 2. gates ────────────────────────────────────────────────────────────────
case "$out" in *'"too_young":1'*) ok "gate1 age: fresh orphan excluded" ;; *) no "too_young wrong: $out" ;; esac
case "$out" in *'"refused":1'*) ok "gate2 symlink refused" ;; *) no "refused wrong: $out" ;; esac

# ── 3. apply ────────────────────────────────────────────────────────────────
out="$("$BIN" --cache "$CACHE" --apply 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && ok "exits 0 in apply mode" || no "apply mode exit=$rc"
[ -d "$CACHE/temp_git_${OLD_MS}_aaaaaa" ] && no "eligible orphan survived --apply" || ok "eligible orphan reclaimed"
[ -d "$CACHE/temp_subdir_${OLD_MS}_bbbbbb.clone" ] && no ".clone orphan survived" || ok ".clone orphan reclaimed"

# the regression this design exists for: fresh mtime must NOT save an old-named dir
[ -d "$CACHE/temp_git_${OLD_MS}_dddddd" ] && no "carcass survived (mtime shielded it)" || ok "carcass reclaimed via name-clock"

# ── 4. what must survive ────────────────────────────────────────────────────
[ -f "$CACHE/marketplace-official/1.0.0/plugin.json" ] && ok "real install untouched" || no "REAL INSTALL DESTROYED"
[ -d "$CACHE/temp_git_${NEW_MS}_cccccc" ] && ok "too-young orphan preserved" || no "too-young orphan deleted"
[ -f "$FIX/outside/precious/data" ] && ok "symlink target outside cache untouched" || no "FOLLOWED SYMLINK OUT OF BOUNDARY"
[ -L "$CACHE/temp_git_${OLD_MS}_eeeeee" ] && ok "symlink itself left in place" || no "symlink removed"

# ── 5. absent cache degrades cleanly ────────────────────────────────────────
out="$("$BIN" --cache "$FIX/does-not-exist" 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && ok "exits 0 on absent cache" || no "absent cache exit=$rc"
case "$out" in *'"note":"cache-absent"'*) ok "absent cache reported in envelope" ;; *) no "absent-cache note missing: $out" ;; esac

# ── 6. age override ─────────────────────────────────────────────────────────
# with a 1-minute floor the young orphan becomes eligible
out="$("$BIN" --cache "$CACHE" --age-min 0 2>/dev/null)"
case "$out" in *'"too_young":0'*) ok "--age-min override honored" ;; *) no "age override ignored: $out" ;; esac

# ── 7. --age-min must be a non-negative integer (fail CLOSED, valid JSON) ────
# A non-numeric value used to be interpolated raw into the `age_min` NUMBER field,
# so a crafted argument emitted malformed JSON to a machine consumer.
CACHE2="$FIX/cache2"
mkdir -p "$CACHE2/temp_git_${OLD_MS}_ffffff"
out="$("$BIN" --cache "$CACHE2" --age-min 'abc"; rm -rf /' --apply 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && ok "invalid --age-min still exits 0" || no "invalid age exit=$rc"
case "$out" in *'"note":"invalid-age-min"'*) ok "invalid --age-min reported in envelope" ;; *) no "invalid-age note missing: $out" ;; esac
case "$out" in *'"age_min":0,'*) ok "age_min stays a valid JSON number" ;; *) no "age_min not numeric: $out" ;; esac
case "$out" in *'"swept":0'*) ok "invalid --age-min sweeps NOTHING (fail-closed)" ;; *) no "swept despite invalid age: $out" ;; esac
[ -d "$CACHE2/temp_git_${OLD_MS}_ffffff" ] && ok "candidate survived invalid --age-min" || no "DELETED under invalid --age-min"

# a quote/backslash in the cache path must not terminate the JSON string early
out="$("$BIN" --cache "$FIX/we\"ird" 2>/dev/null)"
case "$out" in *'"note":"cache-absent"'*) ok "quoted cache path keeps envelope parseable" ;; *) no "quote broke envelope: $out" ;; esac

# ── 7b. an option whose VALUE is missing must never fall back to the default ──
# `--apply --cache` (value lost to a typo / an unquoted empty var / a truncated wrapper) used to
# keep the DEFAULT cache and aim the deletion at the operator's REAL plugin cache. Asserted on the
# EFFECT (did it delete) rather than the envelope text, with a control proving the test can see a
# deletion at all — an assertion that only reads `note` would pass even if the files were removed.
DECOY="$FIX/decoy-cache"
mkdir -p "$DECOY/temp_git_${OLD_MS}_victim"; echo payload > "$DECOY/temp_git_${OLD_MS}_victim/file"
out="$(PCS_CACHE="$DECOY" "$BIN" --apply --cache 2>/dev/null)"
case "$out" in *'"note":"missing-option-value"'*) ok "missing --cache value refused" ;; *) no "missing-value not refused: $out" ;; esac
[ -d "$DECOY/temp_git_${OLD_MS}_victim" ] && ok "missing --cache value did NOT delete from the fallback cache" || no "DELETED from fallback cache on missing --cache value"
out="$("$BIN" --apply --cache "$DECOY" 2>/dev/null)"
[ -d "$DECOY/temp_git_${OLD_MS}_victim" ] && no "control failed: supplied path did not delete (test is blind)" || ok "control: supplied path still reclaims"
out="$("$BIN" --age-min 2>/dev/null)"
case "$out" in *'"note":"missing-option-value"'*) ok "missing --age-min value refused" ;; *) no "missing --age-min not refused: $out" ;; esac

# ── 7c. a raw C0 control char in --cache is refused, and the REFUSAL still parses ─
# RFC 8259 forbids U+0000-U+001F raw in a string. The gate fired correctly from the start, but the
# refusal envelope itself embedded the offending byte — reproducing the very defect it refused.
CTLPATH="$(printf '%s' "$FIX/ev")$(printf '\001')x"
out="$("$BIN" --cache "$CTLPATH" 2>/dev/null)"
case "$out" in *'"note":"invalid-cache-path"'*) ok "control-char cache path refused" ;; *) no "ctl-char not refused: $out" ;; esac
case "$out" in *$(printf '\001')*) no "refusal envelope still embeds the raw control byte" ;; *) ok "refusal envelope is free of raw control bytes" ;; esac

# ── 8. gate 4 — open handle blocks deletion, INCLUDING the .clone class ──────
# The lsof capture pattern must admit the `.clone` suffix: gate 4 compares WHOLE
# names, so a truncated capture never matches its own candidate and would silently
# exempt every temp_subdir_*.clone with a live file handle.
if command -v lsof >/dev/null 2>&1; then
  CACHE3="$FIX/cache3"
  HELD="$CACHE3/temp_subdir_${OLD_MS}_999999.clone"
  mkdir -p "$HELD"; echo held > "$HELD/open-file"
  exec 9<"$HELD/open-file"            # hold a real handle for the duration
  out="$("$BIN" --cache "$CACHE3" --apply 2>/dev/null)"
  exec 9<&-
  [ -d "$HELD" ] && ok "gate4 refused a held-open .clone candidate" || no "DELETED a .clone with an open handle"
  case "$out" in *'"refused":1'*) ok "gate4 counted the .clone refusal" ;; *) no "refusal not counted: $out" ;; esac

  # ── 8a. an out-of-boundary NAMESAKE must not block the in-cache candidate ───
  # lsof reports every open path on the machine and gate 4 compares BASENAMES, so an open file in an
  # unrelated directory that merely SHARES a candidate's name refused the legitimate in-cache
  # candidate forever. Over-refusing is safer than over-deleting, but a PERMANENT false refusal makes
  # the sweeper useless at its one job — so the in-use set is scoped to "$BOUND/" before name-matching.
  CACHE5="$FIX/cache5"; TWIN="temp_git_${OLD_MS}_bnd001"
  mkdir -p "$CACHE5/$TWIN"; echo c > "$CACHE5/$TWIN/file"          # legit, NOT held
  mkdir -p "$FIX/elsewhere/$TWIN"; echo o > "$FIX/elsewhere/$TWIN/file"
  exec 8<"$FIX/elsewhere/$TWIN/file"                               # hold the OUT-OF-BOUNDARY twin
  out="$("$BIN" --cache "$CACHE5" --apply 2>/dev/null)"
  exec 8<&-
  [ -d "$CACHE5/$TWIN" ] && no "out-of-boundary namesake blocked the in-cache candidate (false refusal)" || ok "out-of-boundary namesake does NOT block the in-cache candidate"

  # ── 8c. a held-open candidate OUTSIDE the narrow name shape must still block ─
  # ⛔ THE IN-USE FILTER MUST ADMIT EXACTLY THE CANDIDATE CLASS (`temp_*`). A narrower pattern is
  # FAIL-OPEN, not strict: gate 4 compares whole basenames, so any held-open candidate the filter
  # drops is INVISIBLE to the gate and gets deleted WHILE IN USE. Measured on the prior
  # `temp_[a-z]*_[0-9]*_[a-z0-9]*(\.clone)?` matcher: 3 of 3 held-open candidates slipped through.
  # Each name below IS a candidate (`find -name 'temp_*'` + gate 0 both admit it) yet fails that
  # narrower shape — no epoch / uppercase / hyphen. Asserts DELETION IS REFUSED, i.e. the gate can
  # SEE them; the age/boundary gates narrow by REFUSING, they must never EXEMPT.
  CACHE6="$FIX/cache6"
  for odd in "temp_weird" "temp_UPPER_${OLD_MS}_x" "temp_a-b_${OLD_MS}_x"; do
    mkdir -p "$CACHE6/$odd"; echo o > "$CACHE6/$odd/file"
  done
  exec 6<"$CACHE6/temp_weird/file" 5<"$CACHE6/temp_UPPER_${OLD_MS}_x/file" 4<"$CACHE6/temp_a-b_${OLD_MS}_x/file"
  out="$("$BIN" --cache "$CACHE6" --apply 2>/dev/null)"
  exec 6<&- 5<&- 4<&-
  odd_gone=0
  for odd in "temp_weird" "temp_UPPER_${OLD_MS}_x" "temp_a-b_${OLD_MS}_x"; do
    [ -d "$CACHE6/$odd" ] || odd_gone=$((odd_gone+1))
  done
  [ "$odd_gone" -eq 0 ] && ok "held-open candidates outside the narrow name shape are still seen by gate4" \
                        || no "DELETED $odd_gone held-open candidate(s) invisible to the in-use filter (fail-open)"

  # ── 8d. a cache path containing regex METACHARACTERS must not bypass gate 4 ──
  # ⛔ $BOUND MUST NEVER REACH A REGEX. The in-use extraction used to embed it in a `sed` s|…|…|
  # expression, so a `|` in the path became the DELIMITER: sed died (`bad flag in substitute
  # command`), INUSE came back EMPTY, `INUSE_OK=1` was still trusted (it is assigned on lsof's rc
  # alone, BEFORE the filter runs), and a held-open candidate was DELETED — measured `swept:1
  # in_use:0` with a live handle. Escaping `|` would patch one delimiter; the fix removes the regex.
  # ⚠️ THE POSITIVE CONTROL IS NOT OPTIONAL HERE. My first attempt at that fix used bash-4 `case`
  # syntax inside `$( )`, which bash 3.2 (this file's floor) mis-parses — the script ABORTED and the
  # held-open dir "survived", which reads exactly like a pass. Only asserting that a PLAIN path
  # still reclaims exposed it: the tool was broken, not strict. Survival proves refusal only when
  # the same build can still delete.
  for _mc in 'cache|pipe' 'cache*star' 'cache?q' 'cache[b]br' 'cache sp' 'cache.dot'; do
    _mcC="$FIX/mc/$_mc"; _mcH="$_mcC/temp_git_${OLD_MS}_mc0001"
    _mcO="$_mcC/temp_git_${OLD_MS}_mc0002"                 # eligible, NOT held → the control
    mkdir -p "$_mcH" "$_mcO"; echo h > "$_mcH/file"; echo o > "$_mcO/file"
    exec 3<"$_mcH/file"
    "$BIN" --cache "$_mcC" --apply >/dev/null 2>&1
    exec 3<&-
    [ -d "$_mcH" ] || no "DELETED a held-open candidate under cache path '$_mc' (gate 4 bypassed)"
    [ -d "$_mcO" ] && no "control blind for '$_mc': the unheld candidate was NOT reclaimed, so survival proves nothing"
    [ -d "$_mcH" ] && [ ! -d "$_mcO" ] && ok "gate4 holds under metachar cache path '$_mc' (held refused, unheld reclaimed)"
    rm -rf "$FIX/mc"
  done

  # ── 8b. an UNAVAILABLE probe must refuse, not pass ──────────────────────────
  # `INUSE=""` means two opposite things — "nothing is open" and "I could not look". Reading the
  # second as the first is the free-negative that turns gate 4 into a no-op exactly when it cannot
  # see. Simulated by shadowing lsof with a non-zero stub on PATH (covers absent/broken/timed-out).
  SHADOW="$FIX/shadow-bin"; mkdir -p "$SHADOW"
  printf '#!/bin/sh\nexit 1\n' > "$SHADOW/lsof"; chmod +x "$SHADOW/lsof"
  CACHE4="$FIX/cache4"; BLIND="$CACHE4/temp_subdir_${OLD_MS}_888888.clone"
  mkdir -p "$BLIND"; echo x > "$BLIND/file"
  out="$(PATH="$SHADOW:$PATH" "$BIN" --cache "$CACHE4" --apply 2>/dev/null)"
  [ -d "$BLIND" ] && ok "gate4 fail-closed when the probe could not run" || no "DELETED while the in-use probe was blind"
  case "$out" in *'"refused":1'*) ok "blind-probe refusal counted" ;; *) no "blind refusal not counted: $out" ;; esac
else
  ok "gate4 .clone test skipped (no lsof)"
  ok "gate4 blind-probe test skipped (no lsof)"
fi

echo
[ "$fail" -eq 0 ] && echo "test-plugin-cache-sweeper: ALL PASS" || echo "test-plugin-cache-sweeper: FAILURES"
exit "$fail"
