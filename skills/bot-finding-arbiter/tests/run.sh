#!/bin/sh
# tests/run.sh — Run classify.sh across the bot-finding-arbiter fixtures and assert
# each finding.json produces its expected.txt verdict line.
#
# This is the executable PROOF of the deterministic ORIENT gates:
#   - case-02 (gitleaks secret) + case-04 (Trivy CVE) MUST yield never_suppress=true  (⛔ gate)
#   - case-03 (Snyk quota) MUST yield repo_fixable=no                                  (account-vs-code)
#   - case-01 + case-05 (content) MUST yield defer-to-verify                           (no auto-suppress)
#
# USAGE:  ./skills/bot-finding-arbiter/tests/run.sh
# Exit 0 if all cases pass; exit 1 otherwise.

set -u  # do NOT set -e — mismatches are handled per-case

HERE="$(cd "$(dirname "$0")" && pwd)"
CLASSIFY="$HERE/../bin/classify.sh"

if [ ! -x "$CLASSIFY" ]; then
  echo "FAIL: classifier not found or not executable at $CLASSIFY" >&2
  exit 1
fi

total=0
passed=0
failed=0

for case_dir in "$HERE"/case-*/; do
  [ -d "$case_dir" ] || continue
  case_name="$(basename "$case_dir")"
  finding="$case_dir/finding.json"
  expected="$case_dir/expected.txt"

  if [ ! -f "$finding" ] || [ ! -f "$expected" ]; then
    echo "[SKIP] $case_name — missing finding.json or expected.txt"
    continue
  fi

  total=$((total + 1))

  # Capture stderr so a classifier failure (e.g. "jq is required" / "invalid JSON input")
  # is surfaced on FAIL instead of hidden — per qodo #192 observability finding.
  err_file="$(mktemp 2>/dev/null || echo "/tmp/bfa-run-$$-$total.err")"
  actual="$(set +e; "$CLASSIFY" "$finding" 2>"$err_file")"
  want="$(cat "$expected")"

  if [ "$actual" = "$want" ]; then
    echo "[ OK ] $case_name"
    passed=$((passed + 1))
  else
    echo "[FAIL] $case_name"
    echo "       expected: $want"
    echo "       actual:   $actual"
    [ -s "$err_file" ] && echo "       stderr:   $(cat "$err_file")"
    failed=$((failed + 1))
  fi
  rm -f "$err_file"
done

echo ""
echo "Summary: $passed/$total passed, $failed failed"
[ "$failed" -eq 0 ] && exit 0 || exit 1
