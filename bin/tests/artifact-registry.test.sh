#!/usr/bin/env bash
# Tests for bin/artifact-registry — dedup-memory for Anima (naming) & Forge
# (creation), + the mkdir-lock bound (multi-agent-os#380 follow-up: this file's
# lock loop mirrors the SAME shape amazon-q/coderabbitai flagged in
# bin/atomize-and-route). Bash 3.2-safe, self-contained.
# Run: bash bin/tests/artifact-registry.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BIN="$DIR/../artifact-registry"

pass=0 ; fail=0
ok() { pass=$((pass + 1)); printf '  \xe2\x9c\x93 %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \xe2\x9c\x97 %s\n      got: [%s]\n' "$1" "$2"; }
has()  { case "$2" in *"$1"*) ok "$3" ;; *) no "$3" "$2" ;; esac; }
hasnt(){ case "$2" in *"$1"*) no "$3" "$2" ;; *) ok "$3" ;; esac; }
eq()   { [ "$1" = "$2" ] && ok "$3" || no "$3" "got=[$2] want=[$1]"; }

printf 'artifact-registry.test.sh\n'

# isolate ledger from the real one (never write to $HOME/.claude/audit in tests)
TMPDIR_TEST="$(mktemp -d 2>/dev/null || mktemp -d -t ar)"
export ARTIFACT_REGISTRY_DIR="$TMPDIR_TEST"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- usage / validation -------------------------------------------------
o="$("$BIN" 2>&1)"; rc=$?
eq "0" "$rc" 'bare invocation (usage) exits 0'

o="$("$BIN" bogus-verb 2>&1)"; rc=$?
eq "1" "$rc" 'unknown verb exits 1'

o="$("$BIN" record 2>&1)"; rc=$?
eq "1" "$rc" 'record without --kind exits 1'

o="$("$BIN" record --kind bogus --slug x 2>&1)"; rc=$?
eq "1" "$rc" 'record with invalid --kind exits 1'

o="$("$BIN" record --kind name 2>&1)"; rc=$?
eq "1" "$rc" 'record without --slug exits 1'

o="$("$BIN" record --kind name --slug 'bad slug!' 2>&1)"; rc=$?
eq "1" "$rc" 'record with an invalid slug charset exits 1'

# --- empty-registry lookup graceful degradation -------------------------
o="$("$BIN" lookup --purpose "anything" --json 2>/dev/null)"
has 'CLEAR' "$o" 'lookup on an empty/absent registry returns CLEAR cleanly'

# --- record + lookup round trip -----------------------------------------
o="$("$BIN" record --kind name --slug praxis-audit --type skill \
  --purpose "audit the session's own enacted methods for theater" --dry-run 2>/dev/null)"
has 'praxis-audit' "$o" 'record --dry-run prints the event JSON'
[ -f "$ARTIFACT_REGISTRY_DIR/artifact-registry.jsonl" ] \
  && no '--dry-run writes nothing to the ledger' 'file exists' \
  || ok '--dry-run writes nothing to the ledger'

"$BIN" record --kind name --slug praxis-audit --type skill \
  --purpose "audit the session's own enacted methods for theater" >/dev/null 2>&1
o="$("$BIN" lookup --purpose "session method audit theater" --json 2>/dev/null)"
has 'DUP-RISK' "$o" 'lookup with an overlapping purpose flags DUP-RISK (synonym catch)'
has 'praxis-audit' "$o" 'DUP-RISK match names the prior slug'

o="$("$BIN" lookup --purpose "completely unrelated topic xyz" --json 2>/dev/null)"
has 'CLEAR' "$o" 'lookup with a non-overlapping purpose is CLEAR'

# --- idempotency ----------------------------------------------------------
n1="$(wc -l < "$ARTIFACT_REGISTRY_DIR/artifact-registry.jsonl" | tr -d ' ')"
"$BIN" record --kind name --slug praxis-audit --type skill \
  --purpose "audit the session's own enacted methods for theater" >/dev/null 2>&1
n2="$(wc -l < "$ARTIFACT_REGISTRY_DIR/artifact-registry.jsonl" | tr -d ' ')"
eq "$n1" "$n2" 're-recording the identical (kind,slug,purpose) is idempotent (no duplicate line)'

# --- lock-loop bound (multi-agent-os#380 follow-up — same fix as
#     bin/atomize-and-route): a HELD lock must exit 1 promptly, never spin
#     forever. Pre-hold the lock dir, cap the attempts tiny via the env
#     overrides, and assert (a) exit non-zero (b) bounded wall-clock
#     (c) no ledger event written for the blocked record.
mkdir -p "$ARTIFACT_REGISTRY_DIR/.lock-artifact-registry"   # simulate a wedged/dead holder
START_TS="$(date +%s 2>/dev/null || echo 0)"
ARTIFACT_REGISTRY_LOCK_MAX_ATTEMPTS=3 ARTIFACT_REGISTRY_LOCK_SLEEP=0.01 \
  "$BIN" record --kind name --slug lock-test-slug --purpose "lock timeout probe" \
  >/dev/null 2>/tmp/ar-lock-test-err.$$
rc=$?
END_TS="$(date +%s 2>/dev/null || echo 0)"
ELAPSED=$((END_TS - START_TS))
eq "1" "$rc" 'a HELD lock exits 1 (not 0, not a hang) once the attempt cap is reached'
[ "$ELAPSED" -le 5 ] && ok 'a HELD lock gives up within a few seconds (bounded, not an infinite spin)' \
  || no 'a HELD lock gives up within a few seconds (bounded, not an infinite spin)' "elapsed=${ELAPSED}s"
has 'giving up' "$(cat /tmp/ar-lock-test-err.$$ 2>/dev/null)" 'the timeout error names itself (not a silent hang)'
rm -f /tmp/ar-lock-test-err.$$
hasnt 'lock-test-slug' "$(cat "$ARTIFACT_REGISTRY_DIR/artifact-registry.jsonl" 2>/dev/null)" \
  'a timed-out lock attempt writes NO ledger event for the record'
rm -rf "$ARTIFACT_REGISTRY_DIR/.lock-artifact-registry"   # release the simulated holder

# once the lock is free again, a fresh record call works normally
"$BIN" record --kind name --slug lock-test-slug --purpose "lock timeout probe" >/dev/null 2>&1
o="$("$BIN" lookup --slug lock-test-slug --json 2>/dev/null)"
has 'lock-test-slug' "$o" 'after the lock frees, a fresh record call succeeds normally'

echo
if [ "$fail" -eq 0 ]; then echo "ALL PASS ✓"; else echo "FAILURES ✗"; fi
exit "$fail"
