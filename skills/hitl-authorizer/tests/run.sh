#!/bin/sh
# tests/run.sh — Run classify.sh across the hitl-authorizer (Tribune) fixtures and assert
# each escalation.json produces its expected.txt verdict line.
#
# This is the executable PROOF of the deterministic HARD-BOUNDARY gates (the safety spine):
#   - case-02 (secret exposure)  MUST yield never_authorize=true · council=none  (⛔ un-liftable)
#   - case-03 (production PII/LGPD) MUST yield never_authorize=true · council=none  (HUMAN_DOMAIN)
#   - case-04 (merge→main/prod)  MUST yield never_authorize=true · council=none  (human-owned)
#   - case-05 + case-06 (auth-change / self-edit-governance) MUST yield adversarial-verify-required
#   - case-01 + case-07 (uncertainty-residue) MUST yield council · never_authorize=false
#
# USAGE:  ./skills/hitl-authorizer/tests/run.sh
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
  escalation="$case_dir/escalation.json"
  expected="$case_dir/expected.txt"

  if [ ! -f "$escalation" ] || [ ! -f "$expected" ]; then
    echo "[SKIP] $case_name — missing escalation.json or expected.txt"
    continue
  fi

  total=$((total + 1))

  # Capture stderr so a classifier failure (e.g. "jq is required" / "invalid JSON input")
  # is surfaced on FAIL instead of hidden.
  err_file="$(mktemp 2>/dev/null || echo "/tmp/hitl-run-$$-$total.err")"
  actual="$(set +e; "$CLASSIFY" "$escalation" 2>"$err_file")"
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
