#!/usr/bin/env bash
# Hermetic conformance tests for the self-heal-relay v2 block (bash · python · node) + its renderer.
# No network, no real AI harness: the default-chain binaries are replaced by stubs placed first on PATH.
# Runs the bash block under EVERY available bash (macOS /bin/bash 3.2 and a newer one) — ERR-trap semantics differ.
#
#   bash tests/test-self-heal-relay.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RENDER="$ROOT/skills/instrument-self-heal-relay/bin/self-heal-relay-render"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  ❌ %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/shr-test.XXXXXX")"
trap 'case "$SANDBOX" in "${TMPDIR:-/tmp}"/shr-test.*) rm -rf -- "$SANDBOX" ;; esac' EXIT
STUBS="$SANDBOX/stubs"; mkdir -p "$STUBS" "$SANDBOX/tmp"
export TMPDIR="$SANDBOX/tmp" STUB_LOG="$SANDBOX/calls.log" MAOS_SELFHEAL_SEED_DIR="$SANDBOX/seeds"

# Stub harness: records argv + stdin, then exits with STUB_RC printing STUB_OUT. One stub per default-chain binary.
restore_stubs() { local h; for h in kiro-cli claude codex; do
  cat > "$STUBS/$h" <<'STUB'
#!/bin/sh
n=$(( $(wc -l < "$STUB_LOG" 2>/dev/null || echo 0) + 1 ))
echo "$(basename "$0") $*" >> "$STUB_LOG"
echo "ACTIVE=${MAOS_SELFHEAL_ACTIVE:-unset}" >> "$STUB_LOG.env"
cat > "$STUB_LOG.stdin.$n"
[ -n "${STUB_REENTER:-}" ] && "$STUB_REENTER" >/dev/null 2>&1
[ "${STUB_RC:-0}" = 0 ] && printf '%s\n' "${STUB_OUT:-PROPOSAL: fix the thing}"
exit "${STUB_RC:-0}"
STUB
  chmod +x "$STUBS/$h"
done; }
restore_stubs
export PATH="$STUBS:$PATH"
reset_stubs() { rm -f "$STUB_LOG" "$STUB_LOG".stdin.* "$STUB_LOG.env"; : > "$STUB_LOG"; rm -rf "$MAOS_SELFHEAL_SEED_DIR" "$SANDBOX"/tmp/*; unset STUB_RC STUB_OUT STUB_REENTER MAOS_AI_HARNESS MAOS_SELFHEAL_MODE MAOS_SELFHEAL_TIER MAOS_SELFHEAL_ACTIVE MAOS_SELFHEAL; }
fmode() { if stat -c %a "$1" >/dev/null 2>&1; then stat -c %a "$1"; else stat -f %Lp "$1"; fi; }   # GNU first, BSD fallback (GNU `stat -f` is a filesystem report)
gc_alive() { [ -s "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null && [ "$(ps -o stat= -p "$(cat "$1")" 2>/dev/null | cut -c1)" != Z ]; }
gc_stub() { printf '#!/bin/sh\ncat >/dev/null\n( sleep 60 & echo $! > "%s"; wait ) &\ntrap "" TERM\nsleep 60\n' "$1" > "$STUBS/kiro-cli"; chmod +x "$STUBS/kiro-cli"; }
calls() { wc -l < "$STUB_LOG" | tr -d ' '; }
noleak() {  # $1=needle $2=fail msg $3=ok label — passes ONLY if the relay ran (a prompt/stdin exists) and the needle is absent
  local all; all="$(cat "$STUB_LOG".stdin.* "$SANDBOX"/tmp/shr.*/prompt.md 2>/dev/null)"
  if [ -z "$all" ]; then bad "$2 (no relay ran: check is vacuous)"; return; fi
  case "$all" in *"$1"*) bad "$2" ;; *) ok "$3" ;; esac
}

# Secrets are assembled at runtime so no scanner sees a literal credential in this file.
FAKE_AWS="AKIA$(printf 'IOSFODNN7EXAMPLE')"
FAKE_GH="ghp_$(printf 'abcdefghijklmnopqrstuvwxyz0123456789')"
FAKE_PW="hunter2-$(printf 'correcthorse')"

mk_bash() {  # $1=path $2=knobs $3=body
  { printf '#!/usr/bin/env bash\nset -euo pipefail\n%s\n' "$2"; "$RENDER" --lang bash; printf '%s\n' "$3"; } > "$1"
}

echo "== 1. renderer: stamp is current, drift is detected =="
for L in bash python node; do "$RENDER" --lang "$L" > "$SANDBOX/blk.$L" || bad "render $L"; done
if "$RENDER" --verify "$SANDBOX/blk.bash" >/dev/null 2>&1; then ok "fresh bash block verifies (rc 0)"; else bad "fresh bash block should verify"; fi
sed 's/SHR_MAX_LOG_LINES:-200/SHR_MAX_LOG_LINES:-201/' "$SANDBOX/blk.bash" > "$SANDBOX/drift.bash"
"$RENDER" --verify "$SANDBOX/drift.bash" >/dev/null 2>&1; check "hand-edited block is DRIFT (rc 1)" "$?" "1"
printf 'echo hi\n' > "$SANDBOX/none.sh"; "$RENDER" --verify "$SANDBOX/none.sh" >/dev/null 2>&1; check "file without a block is rc 2" "$?" "2"
cat "$SANDBOX/blk.bash" "$SANDBOX/blk.bash" > "$SANDBOX/dup.bash"; "$RENDER" --verify "$SANDBOX/dup.bash" >/dev/null 2>&1; check "two relay blocks in one file are rejected (rc 2)" "$?" "2"
for L in python node; do "$RENDER" --verify "$SANDBOX/blk.$L" >/dev/null 2>&1; check "fresh $L block verifies" "$?" "0"; done

BASHES="/bin/bash"; NB="$(command -v bash)"; [ "$NB" != "/bin/bash" ] && BASHES="$BASHES $NB"
for B in $BASHES; do
  V="$($B --version | head -1 | sed -E 's/.*version ([0-9.]+).*/\1/')"
  echo; echo "== bash block under $B ($V) =="

  echo "-- 2. fault INSIDE A FUNCTION relays once (set -E), exit code preserved"
  reset_stubs; mk_bash "$SANDBOX/t2.sh" "" 'f() { false; echo NOT-REACHED; }
f'
  "$B" "$SANDBOX/t2.sh" >/dev/null 2>&1; rc=$?
  check "script rc preserved (1)" "$rc" "1"; check "harness dispatched exactly once" "$(calls)" "1"
  grep -q '^kiro-cli ' "$STUB_LOG" && ok "most-qualified-first: kiro-cli got it" || bad "kiro-cli should be first" "$(cat "$STUB_LOG")"
  grep -q 'fs_write' "$STUB_LOG" && bad "propose tier must NOT carry a write tool" || ok "propose tier is read-only (no fs_write)"

  echo "-- 3. intentional exits never relay"
  reset_stubs; mk_bash "$SANDBOX/t3a.sh" 'SHR_CONTRACT_CODES=" 2 "' 'sh -c "exit 2"'
  "$B" "$SANDBOX/t3a.sh" >/dev/null 2>&1; rc=$?
  check "contract code 2 re-exited verbatim" "$rc" "2"; check "contract verdict → zero dispatches" "$(calls)" "0"
  reset_stubs; mk_bash "$SANDBOX/t3b.sh" "" 'exit 3'
  "$B" "$SANDBOX/t3b.sh" >/dev/null 2>&1; rc=$?
  check "explicit exit 3 preserved" "$rc" "3"; check "explicit exit → zero dispatches" "$(calls)" "0"

  echo "-- 4. re-entrancy + single dispatch per harness + verified-only default chain"
  reset_stubs; mk_bash "$SANDBOX/t4.sh" "" 'false'
  STUB_RC=1 STUB_REENTER="$SANDBOX/t4.sh" "$B" "$SANDBOX/t4.sh" >/dev/null 2>&1; rc=$?
  check "rc preserved when every harness fails" "$rc" "1"
  check "3 verified harnesses tried once each — no double dispatch, no recursion" "$(calls)" "3"
  check "relay exports MAOS_SELFHEAL_ACTIVE=1 to every harness (re-entrancy guard)" "$(sort -u "$STUB_LOG.env" | tr '\n' ' ')" "ACTIVE=1 "
  reset_stubs; printf '#!/bin/sh\necho gemini >> "$STUB_LOG"; cat >/dev/null; echo P\n' > "$STUBS/gemini"; chmod +x "$STUBS/gemini"
  mk_bash "$SANDBOX/t4b.sh" "" 'false'
  STUB_RC=1 "$B" "$SANDBOX/t4b.sh" >/dev/null 2>&1
  grep -q '^gemini' "$STUB_LOG" && bad "unverified gemini must NOT be in the default chain" || ok "unverified harness excluded from default chain"
  reset_stubs; MAOS_AI_HARNESS="gemini" "$B" "$SANDBOX/t4b.sh" >/dev/null 2>&1
  grep -q '^gemini' "$STUB_LOG" && ok "explicit MAOS_AI_HARNESS opts an unverified harness in" || bad "explicit opt-in should reach gemini"
  rm -f "$STUBS/gemini"

  echo "-- 4c. harness output is stripped of ANSI colour codes"
  reset_stubs; mk_bash "$SANDBOX/t4c.sh" "" 'false'
  STUB_OUT="$(printf '\033[38;5;141mPROPOSAL\033[0m colour')" "$B" "$SANDBOX/t4c.sh" >/dev/null 2>&1
  PR="$(cat "$SANDBOX"/tmp/shr.*/proposal.md 2>/dev/null)"
  case "$PR" in *$'\033'*) bad "proposal.md still contains ESC" ;; *PROPOSAL*) ok "proposal.md is ANSI-free and non-empty" ;; *) bad "no proposal written" ;; esac

  echo "-- 4d. a harness that ignores SIGTERM cannot hang the caller (TERM then KILL)"
  reset_stubs; mk_bash "$SANDBOX/t4d.sh" "" 'false'
  printf '#!/bin/sh\ntrap "" TERM\ncat >/dev/null\nwhile :; do sleep 1; done\n' > "$STUBS/kiro-cli"; chmod +x "$STUBS/kiro-cli"
  T0=$(date +%s); MAOS_AI_HARNESS=kiro-cli MAOS_SELFHEAL_TIMEOUT=1 "$B" "$SANDBOX/t4d.sh" >/dev/null 2>&1; T1=$(date +%s)
  if [ $((T1-T0)) -le 12 ]; then ok "TERM-ignoring harness bounded ($((T1-T0))s)"; else bad "hung for $((T1-T0))s"; fi
  cat > "$STUBS/kiro-cli" <<'STUB'
#!/bin/sh
n=$(( $(wc -l < "$STUB_LOG" 2>/dev/null || echo 0) + 1 ))
echo "$(basename "$0") $*" >> "$STUB_LOG"
echo "ACTIVE=${MAOS_SELFHEAL_ACTIVE:-unset}" >> "$STUB_LOG.env"
cat > "$STUB_LOG.stdin.$n"
[ -n "${STUB_REENTER:-}" ] && "$STUB_REENTER" >/dev/null 2>&1
[ "${STUB_RC:-0}" = 0 ] && printf '%s\n' "${STUB_OUT:-PROPOSAL: fix the thing}"
exit "${STUB_RC:-0}"
STUB
  chmod +x "$STUBS/kiro-cli"   # the watchdog kills the harness subprocess tree itself; no host-wide pkill

  echo "-- 4e. clean run leaves no run directory behind"
  reset_stubs; mk_bash "$SANDBOX/t4e.sh" "" 'true'
  "$B" "$SANDBOX/t4e.sh" >/dev/null 2>&1
  check "no shr.* dir after a clean run" "$(ls -d "$SANDBOX"/tmp/shr.* 2>/dev/null | wc -l | tr -d ' ')" "0"

  echo "-- 4f. ERR inherited by a subshell dispatches ONCE and keeps its artifacts"
  reset_stubs; mk_bash "$SANDBOX/t4f.sh" "" '( false )
echo after'
  "$B" "$SANDBOX/t4f.sh" >/dev/null 2>&1
  check "subshell failure → exactly one dispatch" "$(calls)" "1"
  check "relay artifacts (proposal.md) survive the parent's exit" "$(ls "$SANDBOX"/tmp/shr.*/proposal.md 2>/dev/null | wc -l | tr -d ' ')" "1"

  echo "-- 4g. a credential inside the failing COMMAND is redacted and fenced"
  reset_stubs; mk_bash "$SANDBOX/t4g.sh" "" "eval 'false \"password=$FAKE_PW\"'"
  "$B" "$SANDBOX/t4g.sh" >/dev/null 2>&1
  noleak "$FAKE_PW" "credential in failed command reached the harness" "failed-command text is redacted"

  echo "-- 4h. an adopter's own EXIT trap is preserved (and SHR_TRAP_EXIT relays a bare exit N; bash 3.2 reports rc 0 for a set -u abort, so that case is not asserted)"
  reset_stubs; { printf '#!/usr/bin/env bash\nset -euo pipefail\ntrap "echo ADOPTER-EXIT >> %s/marker" EXIT\nSHR_TRAP_EXIT=1\n' "$SANDBOX"; "$RENDER" --lang bash; printf 'exit 5\n'; } > "$SANDBOX/t4h.sh"; rm -f "$SANDBOX/marker"
  "$B" "$SANDBOX/t4h.sh" >/dev/null 2>&1; rc=$?
  check "bare exit 5 relayed once (SHR_TRAP_EXIT)" "$(calls)" "1"; check "adopter EXIT trap still ran" "$(grep -c ADOPTER-EXIT "$SANDBOX/marker" 2>/dev/null)" "1"
  check "original non-zero rc preserved" "$([ "$rc" -ne 0 ] && echo y)" "y"

  echo "-- 4j. adopter state survives the block: \$@, EXIT status, ERR trap, prompt script path"
  reset_stubs; { printf '#!/usr/bin/env bash\nset -euo pipefail\ntrap "echo EXITSEEN=\\$? >> %s/m2" EXIT\ntrap "echo ERRSEEN >> %s/m2" ERR\n' "$SANDBOX" "$SANDBOX"; "$RENDER" --lang bash; printf 'echo "ARGS=$*" >> "%s/m2"\nfalse\n' "$SANDBOX"; } > "$SANDBOX/t4j.sh"; rm -f "$SANDBOX/m2"
  "$B" "$SANDBOX/t4j.sh" alpha beta >/dev/null 2>&1
  check "adopter \$@ untouched by the block" "$(grep -c 'ARGS=alpha beta' "$SANDBOX/m2" 2>/dev/null)" "1"
  check "adopter ERR trap chained" "$(grep -c ERRSEEN "$SANDBOX/m2" 2>/dev/null)" "1"
  check "adopter EXIT trap saw the original status (1)" "$(grep -c 'EXITSEEN=1' "$SANDBOX/m2" 2>/dev/null)" "1"
  check "prompt carries the absolute script path" "$(grep -cE '^Script: /.*/t4j\.sh$' "$STUB_LOG".stdin.1 2>/dev/null)" "1"

  echo "-- 4k. without set -e the ERR relay is not armed (a benign failure must not end the script)"
  reset_stubs; { printf '#!/usr/bin/env bash\n'; "$RENDER" --lang bash; printf 'grep -q nomatch /dev/null\necho STILL-RUNNING\n'; } > "$SANDBOX/t4k.sh"
  check "script without errexit continues past a failing command" "$("$B" "$SANDBOX/t4k.sh" 2>/dev/null)" "STILL-RUNNING"; check "and did not relay" "$(calls)" "0"

  echo "-- 4l. an adopter ERR trap that itself exits cannot pre-empt the relay; a timed-out harness leaves no grandchildren"
  reset_stubs; { printf '#!/usr/bin/env bash\nset -euo pipefail\ntrap "echo adopter-failed >&2; exit 7" ERR\n'; "$RENDER" --lang bash; printf 'false\n'; } > "$SANDBOX/t4l.sh"
  "$B" "$SANDBOX/t4l.sh" >/dev/null 2>&1; rc=$?; check "relay ran before the adopter's exiting ERR trap" "$(calls)" "1"; check "adopter exit code (7) wins" "$rc" "7"
  reset_stubs; GC="$SANDBOX/gc.pid"; rm -f "$GC"
  printf '#!/bin/sh\ncat >/dev/null\n( sleep 60 & echo $! > "%s"; wait ) &\ntrap "" TERM\nsleep 60\n' "$GC" > "$STUBS/kiro-cli"; chmod +x "$STUBS/kiro-cli"
  mk_bash "$SANDBOX/t4m.sh" "MAOS_SELFHEAL_TIMEOUT=2" 'false'; MAOS_AI_HARNESS=kiro-cli MAOS_SELFHEAL_TIMEOUT=2 "$B" "$SANDBOX/t4m.sh" >/dev/null 2>&1; sleep 1
  if [ -s "$GC" ] && kill -0 "$(cat "$GC")" 2>/dev/null && [ "$(ps -o stat= -p "$(cat "$GC")" 2>/dev/null | cut -c1)" != Z ]; then bad "grandchild of the timed-out harness survived"; kill -9 "$(cat "$GC")" 2>/dev/null; else ok "no grandchild survives a harness timeout"; fi
  restore_stubs; reset_stubs

  echo "-- 4i. same-second seeds never collide"
  reset_stubs; mk_bash "$SANDBOX/t4i.sh" "" 'false'
  MAOS_SELFHEAL_MODE=seed "$B" "$SANDBOX/t4i.sh" >/dev/null 2>&1; MAOS_SELFHEAL_MODE=seed "$B" "$SANDBOX/t4i.sh" >/dev/null 2>&1
  check "two failures in one second → two seeds" "$(ls "$MAOS_SELFHEAL_SEED_DIR"/NEEDS-AGENT-*.md 2>/dev/null | wc -l | tr -d ' ')" "2"

  echo "-- 5. redaction: no secret reaches argv, stdin or the kept prompt"
  reset_stubs; mk_bash "$SANDBOX/t5.sh" "" "echo \"boot key=$FAKE_AWS gh=$FAKE_GH\" >&2
echo \"password=$FAKE_PW\" >&2
false"
  "$B" "$SANDBOX/t5.sh" >/dev/null 2>&1
  ALL="$(cat "$STUB_LOG" "$STUB_LOG".stdin.* 2>/dev/null; cat "$SANDBOX"/tmp/shr.*/prompt.md 2>/dev/null)"
  leak=0; for s in "$FAKE_AWS" "$FAKE_GH" "$FAKE_PW"; do case "$ALL" in *"$s"*) leak=1 ;; esac; done
  check "no literal secret in argv / stdin / prompt" "$leak" "0"
  case "$ALL" in *"REDACTED"*) ok "redaction markers present (relay did run)" ;; *) bad "expected [REDACTED] markers" ;; esac
  case "$ALL" in *"UNTRUSTED-LOG-"*) ok "log is fenced as UNTRUSTED with a nonce" ;; *) bad "missing UNTRUSTED fence" ;; esac

  echo "-- 5b. redaction holds for over-long credentials, byte-capped tails and cut private keys"
  LONGPW="$(printf 'p%.0s' $(seq 1 400))"
  reset_stubs; mk_bash "$SANDBOX/t5b.sh" "" "echo \"dial https://bob:$LONGPW@host/x\" >&2
echo \"https://onlytoken$LONGPW@host/y\" >&2
false"
  "$B" "$SANDBOX/t5b.sh" >/dev/null 2>&1
  noleak "$LONGPW" "over-long URL credential leaked" "over-long URL credentials are redacted"
  reset_stubs; mk_bash "$SANDBOX/t5c.sh" "" 'head -c 3000000 /dev/zero | tr "\\0" x >&2; echo >&2; echo TAILMARK >&2; false'
  "$B" "$SANDBOX/t5c.sh" >/dev/null 2>&1
  PSZ="$(wc -c < "$(ls -t "$SANDBOX"/tmp/shr.*/prompt.md | head -1)" | tr -d ' ')"
  check "3MB single-line log → bounded prompt (<400KB)" "$([ "$PSZ" -lt 400000 ] && echo y)" "y"
  reset_stubs; mk_bash "$SANDBOX/t5d.sh" "" 'head -c 300000 /dev/zero | tr "\\0" y >&2; echo >&2; printf "%s\\n" "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC" "-----END PRIVATE KEY-----" "after" >&2; false'
  "$B" "$SANDBOX/t5d.sh" >/dev/null 2>&1
  noleak "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC" "dangling private-key body leaked" "private-key body cut by the byte cap is dropped"

  PEMB="-----BEGIN ""PRIVATE KEY-----"  # split literal: keeps secret scanners from flagging the fixture
  reset_stubs; mk_bash "$SANDBOX/t5e.sh" "" "printf '%s\\n' '$PEMB' 'OPENKEYBODYzzzz1234567890' >&2; false"
  "$B" "$SANDBOX/t5e.sh" >/dev/null 2>&1
  noleak "OPENKEYBODYzzzz1234567890" "bash: unterminated private key leaked" "bash: unterminated private-key block is redacted"

  reset_stubs; mk_bash "$SANDBOX/t5f.sh" "" "printf '%s\\n' '$PEMB' >&2; for i in \$(seq 1 5000); do echo 'SECRETBODYzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz' >&2; done; false"
  "$B" "$SANDBOX/t5f.sh" >/dev/null 2>&1
  noleak "SECRETBODYzzzz" "bash: PEM body whose header precedes the byte window leaked" "bash: PEM body cut off from its header is dropped"

  reset_stubs; mk_bash "$SANDBOX/t5g.sh" "" "printf '%s\\n' '$PEMB' >&2; for i in \$(seq 1 260); do echo 'SECRETBODYzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz' >&2; done; false"
  "$B" "$SANDBOX/t5g.sh" >/dev/null 2>&1
  noleak "SECRETBODYzzzz" "bash: PEM cut from its header by the 200-line cap (log < 256KB) leaked" "bash: PEM cut from its header by the line cap is dropped"
  reset_stubs; mk_bash "$SANDBOX/t5h.sh" "" 'false'
  OUT="$(MAOS_SELFHEAL_TIMEOUT=0 "$B" "$SANDBOX/t5h.sh" 2>&1 >/dev/null)"
  case "$OUT" in *"answered ->"*) ok "bash: TIMEOUT=0 falls back to 300 (harness is not killed at once)" ;; *) bad "bash: TIMEOUT=0 killed the harness: $OUT" ;; esac
  reset_stubs; OUT="$(MAOS_SELFHEAL_TIMEOUT=99999999999999999999 "$B" "$SANDBOX/t5h.sh" 2>&1 >/dev/null)"
  case "$OUT" in *"answered ->"*) ok "bash: absurd TIMEOUT is clamped, harness still runs" ;; *) bad "bash: absurd TIMEOUT broke the relay: $OUT" ;; esac

  echo "-- 6. tier lock: a gate script can never reach the apply tier"
  reset_stubs; mk_bash "$SANDBOX/t6.sh" 'SHR_TIER_LOCK=propose' 'false'
  MAOS_SELFHEAL_TIER=apply "$B" "$SANDBOX/t6.sh" >/dev/null 2>&1
  grep -qE 'Edit|Write|fs_write' "$STUB_LOG" && bad "SHR_TIER_LOCK=propose must beat MAOS_SELFHEAL_TIER=apply" "$(cat "$STUB_LOG")" || ok "apply request ignored under SHR_TIER_LOCK"

  echo "-- 7. seed mode: async hand-off, nothing dispatched"
  reset_stubs; mk_bash "$SANDBOX/t7.sh" "" 'false'
  MAOS_SELFHEAL_MODE=seed "$B" "$SANDBOX/t7.sh" >/dev/null 2>&1; rc=$?
  check "rc preserved in seed mode" "$rc" "1"; check "seed mode dispatches nothing" "$(calls)" "0"
  n="$(ls "$MAOS_SELFHEAL_SEED_DIR"/NEEDS-AGENT-*.md 2>/dev/null | wc -l | tr -d ' ')"; check "one NEEDS-AGENT seed written" "$n" "1"
  SF="$(ls "$MAOS_SELFHEAL_SEED_DIR"/NEEDS-AGENT-*.md 2>/dev/null | head -1)"
  check "seed file is mode 0600 (not world-readable)" "$(fmode "$SF")" "600"
done

  echo "-- 7b. seed mode reports failure instead of claiming a seed that was not written"
  reset_stubs; mk_bash "$SANDBOX/t7b.sh" "" 'false'; : > "$SANDBOX/notadir"
  OUT="$(MAOS_SELFHEAL_MODE=seed MAOS_SELFHEAL_SEED_DIR="$SANDBOX/notadir/sub" "$B" "$SANDBOX/t7b.sh" 2>&1 >/dev/null)"
  case "$OUT" in *"seed NOT written"*) ok "unwritable seed dir is reported" ;; *) bad "seed failure not reported: $OUT" ;; esac
  case "$OUT" in *"seed written ->"*) bad "claimed a seed that was not written" ;; *) ok "no false 'seed written'" ;; esac

echo; echo "== ports: python + node (uncaught fault relays; intentional exit never does) =="
if command -v python3 >/dev/null 2>&1; then
  reset_stubs; { printf 'import sys\n'; "$RENDER" --lang python; printf 'raise RuntimeError("boom %s")\n' "$FAKE_GH"; } > "$SANDBOX/p1.py"
  python3 "$SANDBOX/p1.py" >/dev/null 2>&1; rc=$?
  check "python: uncaught exception → non-zero" "$([ "$rc" -ne 0 ] && echo y)" "y"; check "python: relayed once" "$(calls)" "1"
  noleak "$FAKE_GH" "python: secret leaked to harness" "python: secret redacted"
  reset_stubs; { "$RENDER" --lang python; printf 'print("fine")\n'; } > "$SANDBOX/p3.py"; python3 "$SANDBOX/p3.py" >/dev/null 2>&1
  check "python: clean run leaves no run directory" "$(ls -d "$SANDBOX"/tmp/shr.* 2>/dev/null | wc -l | tr -d ' ')" "0"
  reset_stubs; { "$RENDER" --lang python; printf 'raise RuntimeError("x")\n'; } > "$SANDBOX/p4.py"; MAOS_SELFHEAL_MODE=seed python3 "$SANDBOX/p4.py" >/dev/null 2>&1
  SF="$(ls "$MAOS_SELFHEAL_SEED_DIR"/NEEDS-AGENT-*.md 2>/dev/null | head -1)"; check "python: seed is mode 0600" "$(fmode "$SF")" "600"
  reset_stubs; { printf 'import sys\n'; "$RENDER" --lang python; printf 'sys.exit(2)\n'; } > "$SANDBOX/p2.py"
  reset_stubs; GCP="$SANDBOX/gcp.pid"; rm -f "$GCP"; gc_stub "$GCP"; { "$RENDER" --lang python; printf 'raise RuntimeError("x")\n'; } > "$SANDBOX/p6.py"
  MAOS_AI_HARNESS=kiro-cli MAOS_SELFHEAL_TIMEOUT=2 python3 "$SANDBOX/p6.py" >/dev/null 2>&1; sleep 1
  if gc_alive "$GCP"; then bad "python: grandchild survived the timeout"; kill -9 "$(cat "$GCP")" 2>/dev/null; else ok "python: no grandchild survives a harness timeout"; fi; restore_stubs
  reset_stubs; { "$RENDER" --lang python; printf 'import threading\nt = threading.Thread(target=lambda: 1/0); t.start(); t.join()\n'; } > "$SANDBOX/p7.py"; python3 "$SANDBOX/p7.py" >/dev/null 2>&1; check "python: uncaught worker-thread exception relays once" "$(calls)" "1"
  check "python: prompt carries the absolute script path" "$(grep -cE '^Script: /.*/p7\.py$' "$STUB_LOG".stdin.1 2>/dev/null)" "1"
  reset_stubs; { "$RENDER" --lang python; printf 'import threading\ndef w(): 1/0\nt = threading.Thread(target=w); t.start(); t.join()\nraise RuntimeError("main")\n'; } > "$SANDBOX/p8.py"; python3 "$SANDBOX/p8.py" >/dev/null 2>&1; check "python: worker fault + later main fault dispatch exactly once" "$(calls)" "1"
  reset_stubs; { "$RENDER" --lang python; printf 'import sys\nsys.stderr.write("x" * 3000000 + "\\nTAILMARK\\n")\nraise RuntimeError("big log")\n'; } > "$SANDBOX/p9.py"; python3 "$SANDBOX/p9.py" >/dev/null 2>&1; check "python: 3MB log still relays with a bounded tail" "$(grep -c TAILMARK "$STUB_LOG".stdin.1 2>/dev/null)" "1"
  reset_stubs; { "$RENDER" --lang python; printf 'raise RuntimeError("x")\n'; } > "$SANDBOX/p10.py"; : > "$SANDBOX/notadir2"
  OUT="$(MAOS_SELFHEAL_MODE=seed MAOS_SELFHEAL_SEED_DIR="$SANDBOX/notadir2/sub" python3 "$SANDBOX/p10.py" 2>&1 >/dev/null)"
  case "$OUT" in *"seed NOT written"*) ok "python: unwritable seed dir is reported" ;; *) bad "python: seed failure not reported" ;; esac
  reset_stubs; MAOS_SELFHEAL_TIMEOUT=bogus python3 "$SANDBOX/p1.py" >/dev/null 2>&1; check "python: malformed timeout still dispatches once, leaves no child" "$(calls)" "1"
  reset_stubs; { "$RENDER" --lang python; printf 'import sys\nsys.stderr.write("y" * 300000 + "\\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASC\\n-----END PRIVATE KEY-----\\n")\nraise RuntimeError("k")\n'; } > "$SANDBOX/p11.py"; python3 "$SANDBOX/p11.py" >/dev/null 2>&1
  noleak "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC" "python: dangling key body leaked" "python: private-key body cut by the byte cap is dropped"
  reset_stubs; { "$RENDER" --lang python; printf 'raise RuntimeError("https://u:%s@h/")\n' "$LONGPW"; } > "$SANDBOX/p12.py"; python3 "$SANDBOX/p12.py" >/dev/null 2>&1
  noleak "$LONGPW" "python: over-long URL credential leaked" "python: over-long URL credentials are redacted"
  reset_stubs; { "$RENDER" --lang python; printf 'raise RuntimeError("%s\\nOPENKEYBODYzzzz1234567890")\n' "$PEMB"; } > "$SANDBOX/p13.py"; python3 "$SANDBOX/p13.py" >/dev/null 2>&1
  noleak "OPENKEYBODYzzzz1234567890" "python: unterminated private key leaked" "python: unterminated private-key block is redacted"
  reset_stubs; MAOS_SELFHEAL_TIMEOUT=1e100 python3 "$SANDBOX/p1.py" >/dev/null 2>&1; check "python: absurd timeout (1e100) is clamped, dispatches once" "$(calls)" "1"
  reset_stubs; { "$RENDER" --lang python; printf 'raise RuntimeError("E" * 3000000)\n'; } > "$SANDBOX/p14.py"; python3 "$SANDBOX/p14.py" >/dev/null 2>&1
  PSZ="$(cat "$STUB_LOG".stdin.1 2>/dev/null | wc -c | tr -d ' ')"; check "python: 3MB exception text → bounded prompt (<400KB)" "$([ "$PSZ" -lt 400000 ] && echo y)" "y"
  reset_stubs; { "$RENDER" --lang python; printf 'import sys\nsys.stderr.write("%s\\n")\nfor _ in range(5000): sys.stderr.write("SECRETBODYzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz\\n")\nraise RuntimeError("k")\n' "$PEMB"; } > "$SANDBOX/p15.py"; python3 "$SANDBOX/p15.py" >/dev/null 2>&1
  noleak "SECRETBODYzzzz" "python: PEM body cut off from its header leaked" "python: PEM body cut off from its header is dropped"
  reset_stubs; GCP="$SANDBOX/gci.pid"; rm -f "$GCP"; gc_stub "$GCP"; { "$RENDER" --lang python; printf 'raise RuntimeError("x")\n'; } > "$SANDBOX/p16.py"
  # a background job in a non-interactive shell inherits SIGINT=ignored: re-arm the handler inside the process under test
  MAOS_AI_HARNESS=kiro-cli MAOS_SELFHEAL_TIMEOUT=60 python3 -c 'import signal,runpy,sys; signal.signal(signal.SIGINT, signal.default_int_handler); runpy.run_path(sys.argv[1], run_name="__main__")' "$SANDBOX/p16.py" >/dev/null 2>&1 & PYP=$!
  for _ in $(seq 1 40); do [ -s "$GCP" ] && break; sleep 0.25; done; kill -INT "$PYP" 2>/dev/null; sleep 2
  if gc_alive "$GCP"; then bad "python: harness survived Ctrl-C"; kill -9 "$(cat "$GCP")" 2>/dev/null; else ok "python: Ctrl-C during the harness kills the whole harness group"; fi; kill -9 "$PYP" 2>/dev/null; wait "$PYP" 2>/dev/null; restore_stubs
  reset_stubs; { "$RENDER" --lang python; printf 'import sys\nsys.stderr.write("%s\\n")\nfor _ in range(260): sys.stderr.write("SECRETBODYzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz\\n")\nraise RuntimeError("k")\n' "$PEMB"; } > "$SANDBOX/p17.py"; python3 "$SANDBOX/p17.py" >/dev/null 2>&1
  noleak "SECRETBODYzzzz" "python: PEM cut from its header by the 200-line cap leaked" "python: PEM cut from its header by the line cap is dropped"
  reset_stubs; { "$RENDER" --lang python; printf 'raise RuntimeError("%s\\n" + "A" * 70000 + "\\nEXCBODYzzzz1234567890")\n' "$PEMB"; } > "$SANDBOX/p18.py"; python3 "$SANDBOX/p18.py" >/dev/null 2>&1
  noleak "EXCBODYzzzz1234567890" "python: PEM in exception text cut from its header by the 64KB slice leaked" "python: exception text is redacted before the 64KB slice"
  reset_stubs; MAOS_SELFHEAL_TIMEOUT=inf python3 "$SANDBOX/p1.py" >/dev/null 2>&1; check "python: TIMEOUT=inf/1e400 falls back, dispatches once" "$(calls)" "1"
  reset_stubs; { "$RENDER" --lang python; printf 'raise KeyboardInterrupt\n'; } > "$SANDBOX/p5.py"; python3 "$SANDBOX/p5.py" >/dev/null 2>&1; check "python: Ctrl-C (KeyboardInterrupt) never relays" "$(calls)" "0"
  python3 "$SANDBOX/p2.py" >/dev/null 2>&1; rc=$?; check "python: sys.exit(2) preserved" "$rc" "2"; check "python: sys.exit → zero dispatches" "$(calls)" "0"
else bad "python3 missing"; fi
if command -v node >/dev/null 2>&1; then
  reset_stubs; GCN="$SANDBOX/gcn.pid"; rm -f "$GCN"; gc_stub "$GCN"; { "$RENDER" --lang node; printf 'throw new Error("x");\n'; } > "$SANDBOX/n6.js"
  MAOS_AI_HARNESS=kiro-cli MAOS_SELFHEAL_TIMEOUT=2 node "$SANDBOX/n6.js" >/dev/null 2>&1; sleep 1
  if gc_alive "$GCN"; then bad "node: grandchild survived the timeout"; kill -9 "$(cat "$GCN")" 2>/dev/null; else ok "node: no grandchild survives a harness timeout"; fi; restore_stubs
  reset_stubs; { "$RENDER" --lang node; printf 'throw new Error("boom %s");\n' "$FAKE_GH"; } > "$SANDBOX/n1.js"
  node "$SANDBOX/n1.js" >/dev/null 2>&1; rc=$?
  check "node: uncaught exception → non-zero" "$([ "$rc" -ne 0 ] && echo y)" "y"; check "node: relayed once" "$(calls)" "1"
  noleak "$FAKE_GH" "node: secret leaked to harness" "node: secret redacted"
  reset_stubs; { "$RENDER" --lang node; printf 'console.log("fine");\n'; } > "$SANDBOX/n3.js"; node "$SANDBOX/n3.js" >/dev/null 2>&1
  check "node: clean run leaves no run directory" "$(ls -d "$SANDBOX"/tmp/shr.* 2>/dev/null | wc -l | tr -d ' ')" "0"
  reset_stubs; { "$RENDER" --lang node; printf 'throw new Error("x");\n'; } > "$SANDBOX/n4.js"; MAOS_SELFHEAL_MODE=seed node "$SANDBOX/n4.js" >/dev/null 2>&1
  SF="$(ls "$MAOS_SELFHEAL_SEED_DIR"/NEEDS-AGENT-*.md 2>/dev/null | head -1)"; check "node: seed is mode 0600" "$(fmode "$SF")" "600"
  reset_stubs; { "$RENDER" --lang node; printf 'process.exit(2);\n'; } > "$SANDBOX/n2.js"
  node "$SANDBOX/n2.js" >/dev/null 2>&1; rc=$?; check "node: process.exit(2) preserved" "$rc" "2"; check "node: process.exit → zero dispatches" "$(calls)" "0"
  : > "$SANDBOX/notadir2"
  reset_stubs; { "$RENDER" --lang node; printf 'throw new Error("%s\\nOPENKEYBODYzzzz1234567890");\n' "$PEMB"; } > "$SANDBOX/n13.js"; node "$SANDBOX/n13.js" >/dev/null 2>&1
  noleak "OPENKEYBODYzzzz1234567890" "node: unterminated private key leaked" "node: unterminated private-key block is redacted"
  reset_stubs; { "$RENDER" --lang node; printf 'throw new Error("E".repeat(3000000));\n'; } > "$SANDBOX/n14.js"; node "$SANDBOX/n14.js" >/dev/null 2>&1
  PSZ="$(cat "$STUB_LOG".stdin.1 2>/dev/null | wc -c | tr -d ' ')"; check "node: 3MB exception text → bounded prompt (<400KB)" "$([ "$PSZ" -lt 400000 ] && echo y)" "y"
  reset_stubs; { "$RENDER" --lang node; printf 'process.stderr.write("%s\\n"); for (let i = 0; i < 5000; i++) process.stderr.write("SECRETBODYzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz\\n"); throw new Error("k");\n' "$PEMB"; } > "$SANDBOX/n15.js"; node "$SANDBOX/n15.js" >/dev/null 2>&1
  noleak "SECRETBODYzzzz" "node: PEM body cut off from its header leaked" "node: PEM body cut off from its header is dropped"
  reset_stubs; { "$RENDER" --lang node; printf 'process.stderr.write("x".repeat(3000000) + "\\nTAILMARK\\n"); throw new Error("big log");\n'; } > "$SANDBOX/n9.js"; node "$SANDBOX/n9.js" >/dev/null 2>&1; check "node: 3MB single-line log relays (redaction is linear, no ReDoS)" "$(calls)" "1"
  reset_stubs; { "$RENDER" --lang node; printf 'throw new Error("x");\n'; } > "$SANDBOX/n10.js"
  OUT="$(MAOS_SELFHEAL_MODE=seed MAOS_SELFHEAL_SEED_DIR="$SANDBOX/notadir2/sub" node "$SANDBOX/n10.js" 2>&1 >/dev/null)"
  case "$OUT" in *"seed NOT written"*) ok "node: unwritable seed dir is reported" ;; *) bad "node: seed failure not reported" ;; esac
  reset_stubs; { "$RENDER" --lang node; printf 'throw new Error("https://u:%s@h/");\n' "$LONGPW"; } > "$SANDBOX/n11.js"; node "$SANDBOX/n11.js" >/dev/null 2>&1
  noleak "$LONGPW" "node: over-long URL credential leaked" "node: over-long URL credentials are redacted"
  reset_stubs; { "$RENDER" --lang node; printf 'throw new Error("x");\n'; } > "$SANDBOX/n12.js"; MAOS_SELFHEAL_TIMEOUT=bogus node "$SANDBOX/n12.js" >/dev/null 2>&1; check "node: malformed timeout still dispatches once" "$(calls)" "1"
  reset_stubs; { "$RENDER" --lang node; printf 'process.stderr.write("%s\\n"); for (let i = 0; i < 260; i++) process.stderr.write("SECRETBODYzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz\\n"); throw new Error("k");\n' "$PEMB"; } > "$SANDBOX/n17.js"; node "$SANDBOX/n17.js" >/dev/null 2>&1
  noleak "SECRETBODYzzzz" "node: PEM cut from its header by the 200-line cap leaked" "node: PEM cut from its header by the line cap is dropped"
  reset_stubs; { "$RENDER" --lang node; printf 'throw new Error("%s\\n" + "A".repeat(70000) + "\\nEXCBODYzzzz1234567890");\n' "$PEMB"; } > "$SANDBOX/n18.js"; node "$SANDBOX/n18.js" >/dev/null 2>&1
  noleak "EXCBODYzzzz1234567890" "node: PEM in exception text cut from its header by the 64KB slice leaked" "node: exception text is redacted before the 64KB slice"
else bad "node missing"; fi

echo; printf 'self-heal-relay: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
