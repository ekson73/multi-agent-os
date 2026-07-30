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
else
  ok "gate4 .clone test skipped (no lsof)"
fi

echo
[ "$fail" -eq 0 ] && echo "test-plugin-cache-sweeper: ALL PASS" || echo "test-plugin-cache-sweeper: FAILURES"
exit "$fail"
