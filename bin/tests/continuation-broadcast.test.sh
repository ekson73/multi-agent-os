#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Tests: bin/continuation-broadcast.sh — the postflight P3.6 BROADCAST marker (v0.2.0)
# Scope: the SAFETY CONTRACT of the structured continuation back-pointer marker —
#   - dry-run is the DEFAULT (no --apply ⇒ zero file mutation)
#   - commit-trailer always emitted + well-formed (git-trailer parseable)
#   - conservative scope IGNORES --file (only --scope all honors file sinks)
#   - --scope all writes the marker; a 2nd --apply is IDEMPOTENT (upsert, not append-duplicate)
#   - the block is BYTE-idempotent (no churning timestamp) — re-apply is a true no-op
#   - ADR/MADR decision records are REFUSED (case-insensitive; not a transient worklist)
#   - symlink --file targets are REFUSED (can't smuggle a write through the link)
#   - malformed/duplicated in-file sentinels ⇒ FAIL-CLOSED (never mass-delete / duplicate)
#   - a sentinel/newline-injected payload ⇒ refused (can't restructure the block)
#   - an unfound --seed is DROPPED as backing (marker points only at REGISTERED referents)
#   - a value-flag as the LAST arg ⇒ usage error, not an infinite loop (bash 3.2)
#   - MAOS_BROADCAST=0 kill-switch ⇒ noop · nothing to point at ⇒ noop
#   - secret-shaped payload ⇒ refused (metadata-only guarantee)
# Bash 3.2-safe. Isolated jobs registry (audit log never touches ~/.claude).
# Run: bash bin/tests/continuation-broadcast.test.sh
# ═══════════════════════════════════════════════════════════════════════════════
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BC="$SCRIPT_DIR/../continuation-broadcast.sh"

PASS=0 FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ❌ %s\n     got: %s\n' "$1" "${2:-<empty>}"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf '{}' > "$TMP/seed.json"   # a REAL seed referent (verified backing; dogfoods governance-F2)
# Run from $TMP (not a git repo ⇒ REPO_ROOT falls back to pwd) so a relative --seed resolves here,
# and isolate the audit log so the test never writes ~/.claude/jobs.
run() { ( cd "$TMP" && CLAUDE_JOBS_DIR="$TMP/jobs" bash "$BC" "$@" 2>/dev/null ); }

echo "── continuation-broadcast SAFETY tests"

# 1. commit-trailer always emitted + well-formed (token · seed:<verified relpath>)
OUT="$(run --ticket VKS-123 --seed seed.json)"
case "$OUT" in
  *'"trailer":"Continue-Here: VKS-123 · seed:seed.json"'*) ok "commit-trailer well-formed (Continue-Here: <key> · seed:<verified path>)" ;;
  *) bad "commit-trailer shape" "$OUT" ;;
esac

# 2. dry-run is the DEFAULT: a --scope all --file target is NOT mutated without --apply
F="$TMP/doc.md"; printf '# Doc\n\nbody\n' > "$F"
BEFORE="$(cat "$F")"
run --ticket VKS-123 --seed seed.json --scope all --file "$F" >/dev/null
if [ "$(cat "$F")" = "$BEFORE" ]; then ok "dry-run default: --file target untouched (no --apply)"; else bad "dry-run mutated the file" "$(cat "$F")"; fi

# 3. conservative scope IGNORES --file (deferred, not written)
OUT="$(run --ticket VKS-123 --seed seed.json --file "$F")"   # no --scope all
case "$OUT" in
  *'"action":"skipped","reason":"--file honored only under --scope all'*) ok "conservative scope defers --file" ;;
  *) bad "conservative should defer --file" "$OUT" ;;
esac

# 4. --scope all --apply WRITES the marker block (one START + one END sentinel)
run --apply --ticket VKS-123 --seed seed.json --scope all --file "$F" >/dev/null
S1=$(grep -cF '<!-- MAOS-CONTINUE:START -->' "$F" 2>/dev/null | tr -d ' ')
E1=$(grep -cF '<!-- MAOS-CONTINUE:END -->' "$F" 2>/dev/null | tr -d ' ')
if [ "$S1" = "1" ] && [ "$E1" = "1" ]; then ok "--apply writes exactly one marker block"; else bad "marker block count after 1st apply" "START=$S1 END=$E1"; fi

# 5. IDEMPOTENCY (the crux): a 2nd --apply upserts — still exactly ONE block, not two
run --apply --ticket VKS-456 --seed seed.json --scope all --file "$F" >/dev/null
S2=$(grep -cF '<!-- MAOS-CONTINUE:START -->' "$F" 2>/dev/null | tr -d ' ')
E2=$(grep -cF '<!-- MAOS-CONTINUE:END -->' "$F" 2>/dev/null | tr -d ' ')
if [ "$S2" = "1" ] && [ "$E2" = "1" ]; then ok "2nd --apply is idempotent (upsert — still ONE block)"; else bad "idempotency broken (block accumulated)" "START=$S2 END=$E2"; fi
# ...and the block was UPDATED to the new ticket (VKS-456), original preserved around it
if grep -qF 'VKS-456' "$F" && grep -qF '# Doc' "$F" && grep -qF 'body' "$F"; then ok "upsert refreshed payload (VKS-456) + preserved surrounding content"; else bad "upsert content" "$(cat "$F")"; fi

# 6. ADR files are REFUSED (never injected)
ADR="$TMP/docs/adrs/ADR-777-x.md"; mkdir -p "$(dirname "$ADR")"; printf '# ADR-777\n' > "$ADR"
OUT="$(run --apply --ticket VKS-1 --seed seed.json --scope all --file "$ADR")"
if grep -qF '"action":"refused"' <<< "$OUT" && [ "$(cat "$ADR")" = "# ADR-777" ]; then ok "ADR refused + left untouched"; else bad "ADR should be refused+untouched" "$OUT / $(cat "$ADR")"; fi

# 7. kill-switch
OUT="$(MAOS_BROADCAST=0 run --ticket VKS-1 --seed seed.json)"
case "$OUT" in *'"status":"noop"'*'kill-switch'*) ok "MAOS_BROADCAST=0 kill-switch ⇒ noop" ;; *) bad "kill-switch" "$OUT" ;; esac

# 8. nothing to point at ⇒ noop
OUT="$(run --session x)"
case "$OUT" in *'"status":"noop"'*'nothing verifiably to point at'*) ok "no ticket + no seed ⇒ noop" ;; *) bad "no-op guard" "$OUT" ;; esac

# 9. secret-shaped payload ⇒ refused (exit 1, metadata-only guarantee)
if run --ticket 'ghp_0123456789012345678901234' --seed seed.json >/dev/null 2>&1; then
  bad "secret-shaped ticket should be refused" "exit 0"
else
  ok "secret-shaped payload refused (exit != 0)"
fi

# 10. read-only guarantee: a dry-run (in a FRESH jobs registry) writes NO audit log (apply-only side-effect)
FRESH="$TMP/jobs-fresh"
( cd "$TMP" && CLAUDE_JOBS_DIR="$FRESH" bash "$BC" --ticket VKS-123 --seed seed.json --scope all --file "$F" >/dev/null 2>&1 )
if [ ! -e "$FRESH/continuation-broadcasts.log" ]; then ok "dry-run wrote no audit log (apply-only side-effect)"; else bad "dry-run wrote the audit log" "$(cat "$FRESH/continuation-broadcasts.log")"; fi

# ── v0.2.0 hardening regressions (MoE-council security pass) ──────────────────

# 11. BYTE-idempotent: re-apply identical inputs ⇒ file bytes UNCHANGED (no timestamp churn)
G="$TMP/idem.md"; printf '# I\n\ntext\n' > "$G"
run --apply --ticket VKS-9 --seed seed.json --scope all --file "$G" >/dev/null
C1="$(cksum < "$G")"
run --apply --ticket VKS-9 --seed seed.json --scope all --file "$G" >/dev/null
C2="$(cksum < "$G")"
if [ "$C1" = "$C2" ]; then ok "byte-idempotent re-apply (no churning timestamp)"; else bad "re-apply changed bytes" "$C1 vs $C2"; fi

# 12. FAIL-CLOSED on a dangling START (no END) ⇒ file UNTOUCHED, refused (never mass-delete to EOF)
D="$TMP/dangling.md"; printf '# D\n<!-- MAOS-CONTINUE:START -->\nkeep me\nand me\n' > "$D"
BEF="$(cat "$D")"
OUT="$(run --apply --ticket VKS-9 --seed seed.json --scope all --file "$D")"
if grep -qF '"action":"refused"' <<< "$OUT" && [ "$(cat "$D")" = "$BEF" ]; then ok "dangling START ⇒ fail-closed (file untouched, no mass-delete)"; else bad "dangling START not fail-closed" "$OUT / $(cat "$D")"; fi

# 13. FAIL-CLOSED on duplicate START sentinels ⇒ untouched, refused (never duplicate-block)
DUP="$TMP/dup.md"
printf '<!-- MAOS-CONTINUE:START -->\na\n<!-- MAOS-CONTINUE:END -->\n<!-- MAOS-CONTINUE:START -->\nb\n<!-- MAOS-CONTINUE:END -->\n' > "$DUP"
BEF="$(cat "$DUP")"
OUT="$(run --apply --ticket VKS-9 --seed seed.json --scope all --file "$DUP")"
if grep -qF '"action":"refused"' <<< "$OUT" && [ "$(cat "$DUP")" = "$BEF" ]; then ok "duplicate sentinels ⇒ fail-closed (untouched)"; else bad "duplicate sentinels not fail-closed" "$OUT"; fi

# 14. payload carrying a sentinel/comment marker ⇒ refused (can't restructure the block)
if run --ticket 'VKS-1 --> <!-- MAOS-CONTINUE:END -->' --seed seed.json >/dev/null 2>&1; then
  bad "sentinel-injected ticket should be refused" "exit 0"
else ok "sentinel-injected payload refused"; fi

# 15. a value-flag as the LAST arg ⇒ usage error (exit 1), NOT an infinite loop (bash 3.2)
TMO=""; command -v gtimeout >/dev/null 2>&1 && TMO="gtimeout 5"; [ -z "$TMO" ] && command -v timeout >/dev/null 2>&1 && TMO="timeout 5"
if $TMO bash "$BC" --ticket >/dev/null 2>&1; then bad "trailing --ticket should error" "exit 0"; else ok "trailing value-flag ⇒ usage error (no hang)"; fi

# 16. lowercase adr- and MADR numbered decision records are ALSO refused (case-insensitive)
LADR="$TMP/docs/adrs/adr-888-y.md"; mkdir -p "$(dirname "$LADR")"; printf '# adr\n' > "$LADR"
MADR="$TMP/docs/decisions/0007-z.md"; mkdir -p "$(dirname "$MADR")"; printf '# madr\n' > "$MADR"
O1="$(run --apply --ticket VKS-1 --seed seed.json --scope all --file "$LADR")"
O2="$(run --apply --ticket VKS-1 --seed seed.json --scope all --file "$MADR")"
if grep -qF '"action":"refused"' <<< "$O1" && [ "$(cat "$LADR")" = "# adr" ] \
   && grep -qF '"action":"refused"' <<< "$O2" && [ "$(cat "$MADR")" = "# madr" ]; then
  ok "lowercase adr- + MADR decisions/ refused (case-insensitive)"
else bad "lowercase/MADR ADR not refused" "$O1 | $O2"; fi

# 17. a symlink --file target is refused (can't smuggle a write through the link)
REAL="$TMP/real.md"; printf 'orig\n' > "$REAL"
LN="$TMP/link.md"; ln -s "$REAL" "$LN"
OUT="$(run --apply --ticket VKS-1 --seed seed.json --scope all --file "$LN")"
if grep -qF '"action":"refused"' <<< "$OUT" && [ "$(cat "$REAL")" = "orig" ]; then ok "symlink target refused (real file untouched)"; else bad "symlink not refused" "$OUT / $(cat "$REAL")"; fi

# 18. an unfound --seed is DROPPED as backing (marker points only at REGISTERED referents)
OUT="$(run --ticket none --seed does/not/exist.json)"   # ticket 'none' + missing seed ⇒ nothing verifiable
case "$OUT" in *'"status":"noop"'*'nothing verifiably'*) ok "unbacked seed + no ticket ⇒ noop (no unbacked marker)" ;; *) bad "unbacked seed should noop" "$OUT" ;; esac
OUT2="$(run --ticket VKS-5 --seed does/not/exist.json)"  # ...but a NAMED ticket still backs it (seed→none)
case "$OUT2" in *'"trailer":"Continue-Here: VKS-5 · seed:none"'*) ok "named ticket backs marker; unfound seed dropped to none" ;; *) bad "ticket-backed marker with dropped seed" "$OUT2" ;; esac

echo "── $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
