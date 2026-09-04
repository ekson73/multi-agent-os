#!/usr/bin/env bash
# routed-pr-review — gate CONTRACT tests.
#
# Why this exists: four dogfood cycles produced 19 findings, zero of them
# self-caught, and the two worst were COMPOSITION defects — every individual
# line verified against the binary while the PATH through them was dead
# (`exit 0` unreachable via a `.head` scope bug) or wrong (`--add-dir` granting
# access without moving cwd). Line-level checking cannot see either. These tests
# run the REAL script end-to-end against stubbed externals, so they assert the
# path, not the line.
#
# Design: no network, no real reviewer, no real gh. A temp git repo supplies a
# real HEAD_SHA (the script fetches/archives it, so it must exist), and a stub
# PATH supplies `gh` + a fake reviewer whose behaviour each case controls via
# T_* env vars. Exit codes and JSON fields are the contract under test.
#
# Usage: bash skills/routed-pr-review/tests/contract.sh [-v]
# Exit:  0 all pass · 1 any fail

set -uo pipefail
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$SELF_DIR/../bin/routed-review.sh"
[ -f "$SUT" ] || { echo "FATAL: script under test not found at $SUT" >&2; exit 1; }

PASS=0; FAIL=0; FAILED_NAMES=()

# ---------------------------------------------------------------- scaffolding
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/rr-contract.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

REPO_DIR="$SANDBOX/repo"; STUB_BIN="$SANDBOX/bin"
mkdir -p "$REPO_DIR" "$STUB_BIN"

# A real one-commit repo: the script proves cwd == HEAD_SHA and can git-archive it.
(
  cd "$REPO_DIR"
  git init -q . 2>/dev/null
  git config user.email t@t; git config user.name t; git config commit.gpgsign false
  echo hello > file.txt
  git add -A && git commit -qm "seed"
) || { echo "FATAL: could not build temp repo" >&2; exit 1; }
HEAD_SHA="$(cd "$REPO_DIR" && git rev-parse HEAD)"

# `gh` stub. Behaviour is driven entirely by T_* env vars so each case is data,
# not code. It answers exactly the four call shapes the script makes.
cat > "$STUB_BIN/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "pr view")
    cat <<JSON
{ "number": 1, "title": "contract fixture", "headRefOid": "${T_HEAD}",
  "headRefName": "feat/x", "baseRefName": "main", "url": "https://example.invalid/pr/1",
  "author": {"login": "someone"},
  "mergeStateStatus": "${T_MERGESTATE:-UNSTABLE}",
  "reviewDecision": "${T_DECISION:-}",
  "latestReviews": ${T_REVIEWS:-[]},
  "comments": ${T_COMMENTS:-[]} }
JSON
    ;;
  "pr diff")    printf 'diff --git a/file.txt b/file.txt\n+contract fixture\n' ;;
  "pr comment") exit 0 ;;
  "api "*|"api")
                printf '%s\n' "${T_REPO_COMMENTS:-[]}" ;;
  *)            exit 0 ;;
esac
STUB
chmod +x "$STUB_BIN/gh"

# Fake reviewer, in a family that is never the caller. Output length + verdict
# are per-case, which is what drives the <40-byte and gate branches.
cat > "$STUB_BIN/kimi" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${T_REVIEW_BODY:-}"
exit "${T_REVIEW_RC:-0}"
STUB
chmod +x "$STUB_BIN/kimi"

# ---------------------------------------------------------------- assertions
# Run the REAL script against the stub PATH. Per-case fixtures are passed as an
# env prefix (`T_REVIEWS=… sut`) — bash applies those to the function call, so
# each case is data rather than another copy of the invocation.
sut() {
  ( cd "$REPO_DIR" \
    && PATH="$STUB_BIN:$PATH" T_HEAD="$HEAD_SHA" \
       bash "$SUT" --pr 1 --repo o/r --reviewer "${RV:-kimi}" --timeout 500 --json 2>"$SANDBOX/err" )
}

check() {  # check <name> <expected-rc> [<jq-filter> <expected-value>]
  local name="$1" want_rc="$2" filter="${3:-}" want_val="${4:-}" ok=1 why=""
  [ "$RC" = "$want_rc" ] || { ok=0; why="exit $RC, wanted $want_rc"; }
  if [ -n "$filter" ] && [ "$ok" = 1 ]; then
    local got; got="$(printf '%s' "$OUT" | jq -r "$filter" 2>/dev/null)"
    [ "$got" = "$want_val" ] || { ok=0; why="$filter = '$got', wanted '$want_val'"; }
  fi
  if [ "$ok" = 1 ]; then
    PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m  %s\n' "$name"
  else
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$name")
    printf '  \033[31mFAIL\033[0m  %s — %s\n' "$name" "$why"
    [ "$VERBOSE" = 1 ] && { printf '        stdout: %s\n' "${OUT:0:400}"; printf '        stderr: %s\n' "$(tail -3 "$SANDBOX/err")"; }
  fi
}

ok_grep() {  # ok_grep <name> <pattern> — assert stderr carries a reason
  if grep -qi "$2" "$SANDBOX/err"; then
    PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m  %s\n' "$1"
  else
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); printf '  \033[31mFAIL\033[0m  %s\n' "$1"
  fi
}

AT_HEAD='[{"author":{"login":"coderabbitai"},"state":"%s","commit":{"oid":"'"$HEAD_SHA"'"}}]'
OLD_SHA='[{"author":{"login":"coderabbitai"},"state":"APPROVED","commit":{"oid":"0000000000000000000000000000000000000000"}}]'
BODY="Finding 1 [major] the fixture body is deliberately well past the forty byte floor.
VERDICT: REQUEST_CHANGES — substantive."

echo "routed-pr-review — gate contract"
echo "  SUT: $SUT"
echo "  fixture head: ${HEAD_SHA:0:7}"
echo

# ── 1 ── `exit 0` must be REACHABLE.
# Regression for the `.head` scope bug: `.head` does not exist inside a
# `.reviews[]` element, so `select(.sha != .head)` was `!= null` = always true;
# every review counted stale and this path was dead code. Four cycles of
# line-level verification never caught it because every line was correct.
OUT="$(T_REVIEWS="$(printf "$AT_HEAD" APPROVED)" T_DECISION=APPROVED T_REVIEW_BODY="$BODY" \
       ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "exit 0 reachable when a configured primary cleared THIS head" 0 '.may_complete_c3' "true"

# ── 2 ── an approval at an OLDER sha must not clear the gate (no false-green).
OUT="$(T_REVIEWS="$OLD_SHA" T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "stale-head approval does NOT clear C3" 3 '.may_complete_c3' "false"

# ── 3 ── §4.1(e): routing never dismisses an active CHANGES_REQUESTED.
OUT="$(T_REVIEWS="$(printf "$AT_HEAD" CHANGES_REQUESTED)" T_DECISION=CHANGES_REQUESTED \
       T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "CHANGES_REQUESTED is never dismissed by a routed review" 3 '.may_complete_c3' "false"

# ── 4 ── empty reviewer output is NOT a review (anti-theater guard #1).
OUT="$(T_REVIEWS='[]' T_REVIEW_BODY="" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "under-40-byte output is treated as NO review" 2 '.status' "empty_review"

# ── 5 ── verifier != generator: the caller's own family may not review.
OUT="$(RV=kimi ROUTED_REVIEW_CALLER=kimi sut)"; RC=$?
check "explicit --reviewer identical to the caller is REFUSED" 1
ok_grep "refusal names the correlated-verifier reason" 'correlated verifier'

# ── 6 ── silence is never 'absent'. No bot ever seen, no attestation => HOLD.
OUT="$(T_REVIEWS='[]' T_COMMENTS='[]' T_REPO_COMMENTS='[]' T_REVIEW_BODY="$BODY" \
       ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "silence alone never proves 'no primary configured'" 3 '.may_complete_c3' "false"

# ── 7 ── argument parsing must terminate.
# Regression for the `shift 2` infinite loop: a value option passed last left
# \$# unchanged and the loop spun (2000 iterations measured before the fix).
timeout 10 bash "$SUT" --pr 1 --repo >/dev/null 2>&1; RC=$?
if [ "$RC" = 1 ]; then
  PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m  %s\n' "trailing value-option dies immediately (no infinite loop)"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("arg loop")
  printf '  \033[31mFAIL\033[0m  trailing value-option: exit %s (124 = hung)\n' "$RC"
fi

echo
printf '  %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || { printf '  failed: %s\n' "${FAILED_NAMES[*]}"; exit 1; }
exit 0
