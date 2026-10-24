#!/usr/bin/env bash
# Real effector CLI; all filesystem/process probes and native cleanup are fixtures.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
SUT="${DHG_TEST_SCRIPT:-$DIR/../collectors/disk-health-guardian.sh}"
JQ="$(/bin/sh -c 'command -v jq')"
[ -x "$JQ" ] || { echo 'jq required for responder contract fixture' >&2; exit 2; }
TMP="$(mktemp -d -t disk-guardian-test.XXXXXX)"
TMP="$(cd "$TMP" && pwd -P)"
trap '/bin/rm -rf -- "$TMP"' EXIT
PASS=0; SKIP=0
fixture() {
  H="$TMP/case-$PASS"; mkdir -p "$H/.local/bin" "$H/.cache/uv" "$H/.cache/pip" "$H/bin"
  printf sentinel > "$H/.cache/uv/sentinel"
  CACHE_SENTINEL="$H/.cache/uv/sentinel"
  printf disposable > "$H/.cache/uv/prunable"
  printf userdata > "$H/user-data"
  printf sentinel > "$H/.cache/pip/sentinel"
  cat > "$H/bin/df" <<'STUB'
#!/bin/bash
[ "${T_UNKNOWN:-0}" = 1 ] && exit 1
if [ -f "$HOME/native-completed" ]; then T_KB="${T_AFTER_KB:-${T_KB:-5242880}}"; fi
printf 'Filesystem 1024-blocks Used Available Capacity
fixture 100000000 90000000 %s 95%%
' "${T_KB:-5242880}"
STUB
  cat > "$H/.local/bin/uv" <<'STUB'
#!/bin/bash
printf '%s
' "$*" >> "$HOME/uv.calls"
case "$*" in
  --version) echo "uv ${T_VERSION:-0.13.0}" ;;
  *'cache dir') echo "${T_CACHE_REPLY:-$HOME/.cache/uv}" ;;
  *'cache prune')
    if [ "${T_INTERRUPT:-0}" = 1 ]; then kill -TERM "$PPID"; exit 143; fi
    [ "${T_UV_RC:-0}" = 0 ] || exit "$T_UV_RC"
    /bin/rm -f "$HOME/.cache/uv/prunable"
    : > "$HOME/native-completed" ;;
  *) exit 9 ;;
esac
STUB
  cat > "$H/bin/timeout" <<'STUB'
#!/bin/bash
case "$*" in *'cache prune') [ "${T_TIMEOUT:-0}" = 1 ] && exit 124 ;; esac
shift; shift
exec "$@"
STUB
  cat > "$H/bin/pgrep" <<'STUB'
#!/bin/bash
exit "${T_PGREP_RC:-1}"
STUB
  cat > "$H/bin/rm" <<'STUB'
#!/bin/bash
printf '%s
' "$*" >> "$HOME/rm.calls"
exit 0
STUB
  cat > "$H/bin/du" <<'STUB'
#!/bin/bash
printf called >> "$HOME/du.calls"
echo "0 $HOME"
STUB
  cat > "$H/bin/osascript" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$HOME/notifications"
STUB
  for cmd in sysctl ps; do printf '#!/bin/bash\nexit 0\n' > "$H/bin/$cmd"; done
  printf '#!/bin/bash
echo called >> "$HOME/tier2.calls"
' > "$H/.local/bin/macos-housekeeping.sh"
  for cmd in claude renice; do
    cat > "$H/bin/$cmd" <<'STUB'
#!/bin/bash
printf '%s\n' "$0 $*" >> "$HOME/unauthorized.calls"
exit 9
STUB
  done
  chmod +x "$H/bin/"* "$H/.local/bin/"*
  LOG="$H/.local/state/disk-health-guardian/guardian.log"
}
run() {
  RC=0
  HOME="$H" PATH="$H/bin:/usr/bin:/bin" DHG_TIMEOUT_BIN="${T_TIMEOUT_BIN:-$H/bin/timeout}" DHG_APPROVED_CACHE="${T_APPROVAL:-$H/.cache/uv}" DHG_UV_PRODUCERS_QUIESCENT="${T_QUIESCENT:-1}" /bin/bash "$SUT" "$@" > "$H/stdout" 2> "$H/stderr" || RC=$?
}
check() { if ! { [ "$(cat "$CACHE_SENTINEL")" = sentinel ] && [ "$(cat "$H/.cache/pip/sentinel")" = sentinel ] && [ "$(cat "$H/user-data")" = userdata ] && eval "$2"; }; then echo "FAIL: $1 (rc=$RC)"; cat "$H/stderr"; [ ! -f "$LOG" ] || cat "$LOG"; exit 1; fi; PASS=$((PASS+1)); echo "PASS: $1"; }
fixture; run
check 'critical default monitor notifies and seeds without cleaning' '[ "$RC" = 0 ] && [ -s "$H/notifications" ] && [ -s "$H/.local/state/disk-health-guardian/SUGGESTIONS.md" ] && compgen -G "$H/.local/state/disk-health-guardian/NEEDS-AGENT-*.md" >/dev/null && [ ! -f "$H/uv.calls" ] && [ -f "$H/.cache/uv/prunable" ]'
fixture; run --dry-run
check 'explicit dry-run suppresses notification and triage seed' '[ "$RC" = 0 ] && [ ! -f "$H/notifications" ] && ! compgen -G "$H/.local/state/disk-health-guardian/NEEDS-AGENT-*.md" >/dev/null && [ ! -f "$H/uv.calls" ]'
fixture; mkdir -p "$H/.local/state/disk-health-guardian/action.lock"; run
check 'cleanup lock does not silence critical monitor' '[ "$RC" = 0 ] && [ -s "$H/notifications" ] && compgen -G "$H/.local/state/disk-health-guardian/NEEDS-AGENT-*.md" >/dev/null && [ -d "$H/.local/state/disk-health-guardian/action.lock" ]'
fixture; run; T_KB=31457280 run; T_KB=31457280 run
check 'monitor resolves seeds after two healthy observations' '[ "$RC" = 0 ] && compgen -G "$H/.local/state/disk-health-guardian/consumed/NEEDS-AGENT-*.md" >/dev/null && ! compgen -G "$H/.local/state/disk-health-guardian/NEEDS-AGENT-*.md" >/dev/null'
fixture; mkdir -p "$H/.local/state/disk-health-guardian"; printf '%s 15\n' "$(( $(date +%s) - 600 ))" > "$H/.local/state/disk-health-guardian/free-samples"; run
check 'default monitor emits burn-rate alarm without cleanup' '[ "$RC" = 0 ] && grep -q "Burn-rate alarm" "$H/notifications" && [ ! -f "$H/uv.calls" ]'
for target_kind in symlink missing file; do
  fixture; mv "$H/.cache/uv" "$H/outside-cache"; CACHE_SENTINEL="$H/outside-cache/sentinel"
  case "$target_kind" in symlink) ln -s "$H/outside-cache" "$H/.cache/uv" ;; file) printf notadir > "$H/.cache/uv" ;; esac
  run --cleanup-uv
  check "requested $target_kind UV target defers without outside changes" '[ "$RC" = 2 ] && grep -q "DEFER unsafe-cache" "$LOG" && [ ! -f "$H/uv.calls" ] && [ "$(cat "$H/outside-cache/prunable")" = disposable ]'
done
fixture; T_AFTER_KB=6291456 run --cleanup-uv
check 'free-space improvement is net observation not causal reclaim' '[ "$RC" = 0 ] && grep -q "OBSERVED_NET_CHANGE +1G" "$LOG" && ! grep -q "RECLAIMED.*from" "$LOG"'
fixture; run
check 'default monitor preserves sentinel and invokes no cleanup' '[ -f "$H/.cache/uv/sentinel" ] && [ ! -f "$H/uv.calls" ] && [ ! -f "$H/rm.calls" ] && [ ! -f "$H/tier2.calls" ]'
fixture; run --cleanup-uv
check 'minimal PATH resolves user absolute UV and binds cache' '[ "$RC" = 0 ] && [ ! -f "$H/.cache/uv/prunable" ] && grep -q -- "--cache-dir $H/.cache/uv cache prune" "$H/uv.calls" && ! grep -q "cache clean" "$H/uv.calls" && [ ! -f "$H/rm.calls" ] && [ ! -f "$H/tier2.calls" ]'
fixture; /bin/rm "$H/.local/bin/uv"; run --cleanup-uv
check 'missing UV defers without raw rm' '[ "$RC" = 2 ] && grep -q "DEFER.*native-missing" "$LOG" && [ ! -f "$H/rm.calls" ]'
fixture; T_VERSION=0.5.9 run --cleanup-uv
check 'unsupported version defers' '[ "$RC" = 2 ] && grep -q "DEFER.*unsupported-version" "$LOG" && ! grep -q "cache prune" "$H/uv.calls"'
fixture; T_UV_RC=7 run --cleanup-uv
check 'native error defers without clean or raw rm' '[ "$RC" = 2 ] && grep -q "DEFER.*native-exit=7" "$LOG" && ! grep -q "cache clean" "$H/uv.calls" && [ ! -f "$H/rm.calls" ]'
fixture; T_TIMEOUT=1 run --cleanup-uv
check 'timeout defers without raw rm' '[ "$RC" = 2 ] && grep -q "DEFER.*native-exit=124" "$LOG" && [ ! -f "$H/rm.calls" ]'
fixture; T_PGREP_RC=0 run --cleanup-uv
check 'busy collector defers without native prune' '[ "$RC" = 2 ] && grep -q "DEFER.*busy" "$LOG" && ! grep -q "cache prune" "$H/uv.calls"'
fixture; UV_CACHE_DIR="$H/.cache/pip" run --cleanup-uv
check 'cache override rejected' '[ "$RC" = 2 ] && grep -q "DEFER.*cache-override" "$LOG" && [ ! -f "$H/uv.calls" ]'
fixture; T_CACHE_REPLY="$H/.cache/pip" run --cleanup-uv
check 'cache binding response checked' '[ "$RC" = 2 ] && grep -q "DEFER.*cache-binding" "$LOG" && ! grep -q "cache prune" "$H/uv.calls"'
fixture; run --cleanup-uv; run --cleanup-uv; run --cleanup-uv; run --cleanup-uv
check 'three attempts halt across runs' '[ "$RC" = 2 ] && [ "$(grep -c "cache prune" "$H/uv.calls")" = 3 ] && grep -q "DEFER.*attempt-cap" "$LOG"'
run --reset-futile-uv; run --cleanup-uv
check 'explicit approved reset allows new attempt' '[ "$(grep -c "cache prune" "$H/uv.calls")" = 4 ]'
fixture; mkdir -p "$H/.local/state/disk-health-guardian/action.lock"; echo $$ > "$H/.local/state/disk-health-guardian/action.lock/pid"; run --cleanup-uv
check 'whole action lock never stolen' '[ "$RC" = 2 ] && grep -q "DEFER.*action-lock" "$H/stderr" && [ ! -f "$H/uv.calls" ] && [ -d "$H/.local/state/disk-health-guardian/action.lock" ]'
run --dry-run
check 'monitor remains live while cleanup lock held' '[ "$RC" = 0 ] && grep -q TRIGGER "$LOG" && [ -d "$H/.local/state/disk-health-guardian/action.lock" ]'
fixture; T_UNKNOWN=1 run
check 'UNKNOWN is not healthy or actionable' '[ "$RC" = 2 ] && grep -q UNKNOWN "$LOG" && ! grep -q "HEARTBEAT healthy" "$LOG" && [ ! -f "$H/uv.calls" ]'
fixture; run --dry-run
check 'real dry-run sentinel smoke avoids large scans at critical margin' '[ "$RC" = 0 ] && [ "$(cat "$H/.cache/uv/sentinel")" = sentinel ] && [ ! -f "$H/du.calls" ] && [ ! -f "$H/uv.calls" ]'
fixture; T_QUIESCENT=0 run --cleanup-uv
check 'producer absence is not authorization' '[ "$RC" = 2 ] && grep -q "producer-contract-required" "$LOG" && [ -f "$H/.cache/uv/prunable" ]'
fixture; T_APPROVAL=wrong run --cleanup-uv
check 'exact approved cache is required' '[ "$RC" = 2 ] && grep -q "approval-required" "$LOG" && [ -f "$H/.cache/uv/prunable" ]'
fixture; T_TIMEOUT_BIN=/missing/timeout run --cleanup-uv
check 'missing timeout fails closed' '[ "$RC" = 2 ] && grep -q "timeout-missing" "$LOG" && [ ! -f "$H/uv.calls" ]'
fixture; T_PGREP_RC=2 run --cleanup-uv
check 'busy UNKNOWN fails closed' '[ "$RC" = 2 ] && grep -q "busy-UNKNOWN" "$LOG" && [ -f "$H/.cache/uv/prunable" ]'
fixture; T_VERSION=0.14.0 run --cleanup-uv
check 'unreviewed newer version fails closed' '[ "$RC" = 2 ] && grep -q "unsupported-version" "$LOG" && [ -f "$H/.cache/uv/prunable" ]'
fixture; run --cleanup-uv; T_KB=31457280 run; run --cleanup-uv; run --cleanup-uv; run --cleanup-uv
check 'healthy cycle does not silently reset attempt cap' '[ "$RC" = 2 ] && [ "$(grep -c "cache prune" "$H/uv.calls")" = 3 ]'
fixture; run --escalate-now
check 'critical escalation serves no bulk census' '[ "$RC" = 0 ] && [ ! -f "$H/du.calls" ] && grep -q "CENSUS DEFER" "$LOG"'
fixture
cat > "$H/bin/mkdir" <<'STUB'
#!/bin/bash
case "$*" in */action.lock/[0-9]*) exit 1 ;; esac
exec /bin/mkdir "$@"
STUB
chmod +x "$H/bin/mkdir"; run --cleanup-uv
check 'owner metadata failure releases newly acquired lock' '[ "$RC" != 0 ] && [ ! -d "$H/.local/state/disk-health-guardian/action.lock" ] && [ ! -f "$H/uv.calls" ]'
fixture; T_INTERRUPT=1 run --cleanup-uv
check 'interrupted mutation retains exclusion for reconciliation' '[ "$RC" = 2 ] && [ -d "$H/.local/state/disk-health-guardian/action.lock" ] && [ -f "$H/.cache/uv/prunable" ]'
run --dry-run
check 'interrupted owner does not disable monitor' '[ "$RC" = 0 ] && grep -q TRIGGER "$LOG"'
fixture; ln -s "$H/.local/bin/uv" "$H/bin/uv"; : > "$H/registry"
RC=0; HOME="$H" PATH="$H/bin:/usr/bin:/bin" OFC_STATE_DIR="$H/ofc" OFC_REGISTRY="$H/registry" /bin/bash "$DIR/offender-containment.sh" --prune > "$H/stdout" 2> "$H/stderr" || RC=$?
check 'containment prune refuses instead of bypassing disk owner' '[ "$RC" = 2 ] && grep -q DEFER "$H/stderr" && [ ! -f "$H/uv.calls" ]'
RC=0; HOME="$H" PATH="$H/bin:/usr/bin:/bin" OFC_STATE_DIR="$H/ofc" OFC_REGISTRY="$H/registry" OFC_ARM=1 OFC_READY=1 /bin/bash "$DIR/offender-containment.sh" --engage > "$H/stdout" 2> "$H/stderr" || RC=$?
check 'armed containment does not implicitly prune' '[ "$RC" = 0 ] && [ ! -f "$H/uv.calls" ]'
fixture; ln -s "$H/.local/bin/uv" "$H/bin/uv"; ln -s "$JQ" "$H/bin/jq"; : > "$H/registry"
cat > "$H/contract.json" <<'JSON'
{"system":{"status":"warn","branches":{"cpu":{"status":"ok"},"agentic_tools":{"status":"warn","leaves":{"cache_producer":{"status":"warn","uv_archive_objects":100,"uvx_latest_procs":0},"claude_runtime":{"health":"healthy"}}}}}}
JSON
RC=0; HOME="$H" PATH="$H/bin:/usr/bin:/bin" SHR_CONTRACT="$H/contract.json" SHR_STATE_DIR="$H/shr" SHR_READY=1 SHR_NO_NOTIFY=1 OFC_REGISTRY="$H/registry" /bin/bash "$DIR/health-respond.sh" --engage > "$H/stdout" 2> "$H/stderr" || RC=$?
check 'engaged responder seeds disk-owner review without UV mutation or escalation' '[ "$RC" = 0 ] && grep -q "DEFER.*disk-health-guardian" "$H/stdout" && grep -q "No UV prune performed" "$H/shr/"NEEDS-AGENT-*.md && [ ! -f "$H/uv.calls" ] && [ ! -f "$H/unauthorized.calls" ]'
if [ "$(uname -s)" = Darwin ]; then
  fixture
  RC=0; HOME="$H" PATH=/usr/bin:/bin DHG_CRIT_FREE_GB=999999 /bin/bash "$SUT" --dry-run > "$H/stdout" 2> "$H/stderr" || RC=$?
  check 'native macOS df dry-run with isolated HOME preserves every sentinel' '[ "$RC" = 0 ] && [ -f "$H/.cache/uv/prunable" ] && [ ! -f "$H/uv.calls" ] && [ ! -f "$H/tier2.calls" ] && [ -s "$LOG" ]'
else
  echo 'SKIP: native macOS df smoke requires Darwin'
  SKIP=$((SKIP + 1))
fi
echo "$PASS assertions passed; $SKIP platform checks skipped"
