#!/usr/bin/env bash
# Regression for #399: snapshot.sh must not report a gitleaks scanner error as
# "findings". gitleaks exits 1 on BOTH a real finding and a fatal error; only a
# real finding writes a non-empty report. A PATH stub plays each gitleaks mode.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAPSHOT="$HERE/../plugin-scripts/session-fission/snapshot.sh"

SBX="$(mktemp -d)" || { echo "FAIL: mktemp"; exit 1; }
[ -n "$SBX" ] && [ -d "$SBX" ] || { echo "FAIL: sandbox"; exit 1; }
trap 'rm -rf "$SBX"' EXIT

mkdir -p "$SBX/bin"
cat > "$SBX/bin/gitleaks" <<'STUB'
#!/usr/bin/env bash
report=""
while [ $# -gt 0 ]; do
  case "$1" in --report-path) report="$2"; shift 2 ;; *) shift ;; esac
done
case "${GL_STUB_MODE:?}" in
  clean)    exit 0 ;;
  findings) [ -n "$report" ] && printf '[{"RuleID":"generic-api-key"}]\n' > "$report"; exit 1 ;;
  fatal)    echo "FTL bad source" >&2; exit 1 ;;
  emptyrep) [ -n "$report" ] && printf '[]\n' > "$report"; exit 1 ;;
  other)    exit 2 ;;
esac
STUB
chmod +x "$SBX/bin/gitleaks"

PASS=0; FAIL=0
check() { # mode expected
  local mode="$1" want="$2" out dir got
  dir="$SBX/out-$mode"
  printf '{"n":1,"mode":"%s"}\n' "$mode" > "$SBX/t-$mode.jsonl"
  out="$(GL_STUB_MODE="$mode" PATH="$SBX/bin:$PATH" bash "$SNAPSHOT" "$SBX/t-$mode.jsonl" "$dir")" || {
    echo "  FAIL $mode: snapshot.sh exited non-zero ($out)"; FAIL=$((FAIL+1)); return; }
  got="$(sed -n 's/^gitleaks: "\(.*\)"$/\1/p' "$dir"/*.manifest.yaml)"
  if [ "$got" = "$want" ]; then echo "  PASS $mode -> $got"; PASS=$((PASS+1))
  else echo "  FAIL $mode: want $want, got '${got}'"; FAIL=$((FAIL+1)); fi
}

check clean    clean
check findings findings
check fatal    scan-error
check emptyrep scan-error
check other    scan-error

echo "session-fission snapshot: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
