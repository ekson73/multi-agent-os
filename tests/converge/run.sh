#!/bin/sh
# tests/converge/run.sh — Run the converge-lint script across known fixtures
# and assert each case matches its expected.txt declaration.
#
# USAGE:
#   ./tests/converge/run.sh
#
# Exit 0 if all cases pass; exit 1 otherwise.

set -u  # do NOT set -e — we expect non-zero exits from some test runs

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LINT="$ROOT/scripts/converge-lint.sh"
CASES_DIR="$ROOT/tests/converge"

if [ ! -x "$LINT" ]; then
  echo "FAIL: lint script not found or not executable at $LINT" >&2
  exit 1
fi

total=0
passed=0
failed=0

for case_dir in "$CASES_DIR"/case-*/; do
  [ -d "$case_dir" ] || continue
  case_name="$(basename "$case_dir")"
  output_md="$case_dir/output.md"
  expected_txt="$case_dir/expected.txt"

  if [ ! -f "$output_md" ] || [ ! -f "$expected_txt" ]; then
    echo "[SKIP] $case_name — missing output.md or expected.txt"
    continue
  fi

  total=$((total + 1))

  # Run the lint; capture exit + stdout
  actual_out="$(set +e; "$LINT" "$output_md" 2>/dev/null; echo "EXIT=$?")"
  actual_exit="$(echo "$actual_out" | sed -n 's/^EXIT=//p' | tail -1)"
  actual_stdout="$(echo "$actual_out" | sed '$d')"

  # Parse expected
  expected_exit="$(grep '^exit_code=' "$expected_txt" | head -1 | sed 's/^exit_code=//')"
  expected_rules="$(grep '^expected_rules=' "$expected_txt" | head -1 | sed 's/^expected_rules=//')"

  pass=1

  if [ "$actual_exit" != "$expected_exit" ]; then
    echo "[FAIL] $case_name — exit code mismatch (expected=$expected_exit, actual=$actual_exit)"
    pass=0
  fi

  # If expected_rules listed, assert each appears in stdout
  if [ -n "${expected_rules:-}" ]; then
    for rule in $expected_rules; do
      if ! echo "$actual_stdout" | grep -q ":$rule:"; then
        echo "[FAIL] $case_name — expected rule $rule not detected"
        pass=0
      fi
    done
  fi

  if [ "$pass" -eq 1 ]; then
    echo "[ OK ] $case_name (exit=$actual_exit)"
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "       --- actual stdout ---"
    echo "$actual_stdout" | sed 's/^/       /'
  fi
done

echo ""
echo "Summary: $passed/$total passed, $failed failed"
[ "$failed" -eq 0 ] && exit 0 || exit 1
