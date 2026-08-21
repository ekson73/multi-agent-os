#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Test: test-postflight-active-world.sh
# Purpose: Unit + integration tests for the `active_world` field (continuation-seed
#   contract v1.4.0) — the Two-Worlds boundary classification wired through
#   lib/seed-io.sh, postflight-precompact.sh, postflight-postcompact.sh, and
#   reload-session.sh. Codifies the regression cases surfaced across PR #383's
#   5 review rounds (unrecognized-org default, spoofed remote, DRY identity map,
#   version-bump-on-backfill, future-contract-version preservation) that were
#   previously verified only by throwaway ad-hoc test harnesses per round.
# ═══════════════════════════════════════════════════════════════════════════════

set -uo pipefail   # NOT -e: each test asserts its own outcome; a probe's non-zero must not abort the suite.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/plugin-scripts/governance/lib"
PRECOMPACT="${PROJECT_ROOT}/plugin-scripts/governance/postflight-precompact.sh"
POSTCOMPACT="${PROJECT_ROOT}/plugin-scripts/governance/postflight-postcompact.sh"
RELOAD="${PROJECT_ROOT}/plugin-scripts/governance/reload-session.sh"

command -v jq >/dev/null 2>&1 || { echo "jq required for this test suite — skipping (soft-fail)."; exit 0; }

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

assert_equals() {
  local expected="$1" actual="$2" name="${3:-assertion}"
  ((TESTS_RUN++)) || true
  if [[ "$expected" == "$actual" ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $name"
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $name"
    echo "    Expected: $expected"
    echo "    Actual:   $actual"
  fi
}

assert_true() {
  local cond="$1" name="${2:-assertion}"
  ((TESTS_RUN++)) || true
  if [[ "$cond" == "true" ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $name"
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $name"
  fi
}

# ── Fixtures ───────────────────────────────────────────────────────────────────
TEST_ROOT=""
teardown() { [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]] && rm -rf "$TEST_ROOT"; }
trap teardown EXIT
TEST_ROOT="$(mktemp -d)"

mk_repo() { # mk_repo <dir> [remote-url]
  local dir="$1" remote="${2:-}"
  mkdir -p "$dir"
  git -C "$dir" init --initial-branch=main -q
  # test@example.com is the linter_pii.py EMAIL_ALLOWLIST_EXACT convention (RFC 2606) —
  # not the tests/-dir exclude glob, which does not match a root-level `tests/` path.
  git -C "$dir" -c user.email=test@example.com -c user.name=test commit --allow-empty -q -m init
  [[ -n "$remote" ]] && git -C "$dir" remote add origin "$remote"
  true
}

# =============================================================================
# SECTION 1 — seed_active_world() unit tests (lib/seed-io.sh)
# =============================================================================
echo "Testing seed_active_world() [lib/seed-io.sh]..."
echo ""

# shellcheck source=/dev/null
source "${LIB_DIR}/seed-io.sh"

REPO1="${TEST_ROOT}/personal-ssh";  mk_repo "$REPO1" "git@github.com:ekson73/some-repo.git"
REPO2="${TEST_ROOT}/personal-https"; mk_repo "$REPO2" "https://github.com/ekson73/some-repo.git"
REPO3="${TEST_ROOT}/work-ssh";      mk_repo "$REPO3" "git@github.com:vek-im/some-repo.git"
REPO4="${TEST_ROOT}/other-org";     mk_repo "$REPO4" "git@github.com:torvalds/linux.git"
REPO5="${TEST_ROOT}/spoofed";       mk_repo "$REPO5" "git@evil.example.com:github.com/ekson73/some-repo.git"
REPO6="${TEST_ROOT}/no-remote";     mk_repo "$REPO6"
# The operator's personal-identity SSH ALIAS host (multi-identity-git-ssh-governance.md §3.3) —
# stored directly (not via ambient `~/.gitconfig` insteadOf expansion) so this case is
# deterministic on ANY machine/CI, whether or not that global rewrite is configured locally.
REPO7="${TEST_ROOT}/personal-ssh-alias"; mk_repo "$REPO7" "git@github.com-ekson73:ekson73/some-repo.git"

assert_equals "personal" "$(seed_active_world "$REPO1")" "ekson73 SSH remote -> personal"
assert_equals "personal" "$(seed_active_world "$REPO2")" "ekson73 HTTPS remote -> personal"
assert_equals "work"     "$(seed_active_world "$REPO3")" "vek-im SSH remote -> work"
assert_equals "unknown"  "$(seed_active_world "$REPO4")" "unrelated org (torvalds) -> unknown, NOT personal"
assert_equals "unknown"  "$(seed_active_world "$REPO5")" "spoofed remote (github.com as path substring) -> unknown"
assert_equals "unknown"  "$(seed_active_world "$REPO6")" "no origin remote -> unknown"
assert_equals "personal" "$(seed_active_world "$REPO7")" "ekson73's own personal-identity SSH alias (github.com-ekson73) -> personal"

# =============================================================================
# SECTION 2 — postflight-precompact.sh emits active_world on the skeleton
# =============================================================================
echo ""
echo "Testing postflight-precompact.sh active_world emission..."
echo ""

PRE_SEED_DIR="${TEST_ROOT}/pre-seed"; mkdir -p "$PRE_SEED_DIR"
echo '{"session_id":"test-session","trigger":"manual"}' | \
  CLAUDE_PROJECT_DIR="$REPO3" POSTFLIGHT_SEED_DIR="$PRE_SEED_DIR" POSTFLIGHT_SNAPSHOT_PRS=0 \
  bash "$PRECOMPACT" >/dev/null 2>&1 || true

PRE_SEED_FILE="${PRE_SEED_DIR}/continuation-seed.latest.json"
if [[ -f "$PRE_SEED_FILE" ]]; then
  assert_equals "work" "$(jq -r '.params.active_world // "MISSING"' "$PRE_SEED_FILE")" \
    "precompact skeleton carries active_world=work for a vek-im-origin repo"
  assert_equals "1.4.0" "$(jq -r '.data.contract_version // "MISSING"' "$PRE_SEED_FILE")" \
    "precompact skeleton stamps contract_version 1.4.0"
else
  ((TESTS_RUN++)) || true; ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} precompact wrote a seed file (none found — jq/lib dependency missing?)"
fi

# =============================================================================
# SECTION 3 — postflight-postcompact.sh version-bump-on-backfill matrix
# =============================================================================
echo ""
echo "Testing postflight-postcompact.sh version-bump-on-backfill (8-case matrix)..."
echo ""

# postcompact resolves its OWN repo only to confirm it's a git repo; POSTFLIGHT_SEED_DIR
# overrides seed_dir()'s path resolution, so any git repo works here.
POST_REPO="${TEST_ROOT}/postcompact-repo"; mk_repo "$POST_REPO"

write_seed_stub() { # write_seed_stub <file> <contract_version|""> — no params.active_world (unset)
  local file="$1" cv="$2"
  if [[ -n "$cv" ]]; then
    jq -n --arg cv "$cv" '{jsonrpc:"2.0",method:"session.continuation",params:{kind:"deterministic-snapshot"},data:{contract_version:$cv}}' > "$file"
  else
    jq -n '{jsonrpc:"2.0",method:"session.continuation",params:{kind:"deterministic-snapshot"},data:{}}' > "$file"
  fi
}

run_postcompact() { # run_postcompact <seed_dir>
  echo '{"compact_summary":"test summary","trigger":"manual"}' | \
    CLAUDE_PROJECT_DIR="$POST_REPO" POSTFLIGHT_SEED_DIR="$1" \
    bash "$POSTCOMPACT" >/dev/null 2>&1 || true
}

# input_contract_version:expected_contract_version_after_backfill
CASES=(
  "1.0.0:1.4.0"
  "1.1.0:1.4.0"
  "1.2.0:1.4.0"
  "1.3.0:1.4.0"
  ":1.4.0"      # missing contract_version entirely
  "1.4.0:1.4.0"
  "1.5.0:1.5.0" # FUTURE — must be preserved, not downgraded (round-5 regression)
  "2.0.0:2.0.0" # FUTURE — must be preserved, not downgraded (round-5 regression)
)

CASE_N=0
for c in "${CASES[@]}"; do
  CASE_N=$((CASE_N + 1))
  INPUT_CV="${c%%:*}"
  EXPECT_CV="${c##*:}"
  CASE_SEED_DIR="${TEST_ROOT}/case-${CASE_N}"; mkdir -p "$CASE_SEED_DIR"
  SEED_FILE="${CASE_SEED_DIR}/continuation-seed.latest.json"
  write_seed_stub "$SEED_FILE" "$INPUT_CV"
  run_postcompact "$CASE_SEED_DIR"
  ACTUAL_CV="$(jq -r '.data.contract_version // "MISSING"' "$SEED_FILE" 2>/dev/null)"
  ACTUAL_AW="$(jq -r '.params.active_world // "MISSING"' "$SEED_FILE" 2>/dev/null)"
  LABEL="${INPUT_CV:-<missing>}"
  assert_equals "$EXPECT_CV" "$ACTUAL_CV" "contract_version ${LABEL} -> ${EXPECT_CV} (case ${CASE_N})"
  assert_true "$([[ "$ACTUAL_AW" != "MISSING" && -n "$ACTUAL_AW" ]] && echo true || echo false)" \
    "active_world backfilled (non-empty) for contract_version ${LABEL} (case ${CASE_N})"
done

# ── Never-clobber: a seed that ALREADY has active_world set must not be overwritten,
#    and (since no backfill occurred) its stale contract_version must be left alone too.
NOCLOBBER_DIR="${TEST_ROOT}/no-clobber"; mkdir -p "$NOCLOBBER_DIR"
NOCLOBBER_FILE="${NOCLOBBER_DIR}/continuation-seed.latest.json"
jq -n '{jsonrpc:"2.0",method:"session.continuation",params:{kind:"deterministic-snapshot",active_world:"work"},data:{contract_version:"1.3.0"}}' > "$NOCLOBBER_FILE"
run_postcompact "$NOCLOBBER_DIR"
assert_equals "work" "$(jq -r '.params.active_world' "$NOCLOBBER_FILE")" \
  "existing active_world=work is never clobbered by the backfill (//=)"
assert_equals "1.3.0" "$(jq -r '.data.contract_version' "$NOCLOBBER_FILE")" \
  "contract_version is NOT bumped when no backfill occurred (nothing was missing)"

# =============================================================================
# SECTION 4 — reload-session.sh renders active_world FIRST (before the mission)
# =============================================================================
echo ""
echo "Testing reload-session.sh active_world rendering..."
echo ""

RELOAD_REPO="${TEST_ROOT}/reload-repo"; mk_repo "$RELOAD_REPO"
RELOAD_SEED_DIR="${TEST_ROOT}/reload-seed"; mkdir -p "$RELOAD_SEED_DIR"
jq -n '{jsonrpc:"2.0",method:"session.continuation",
        params:{kind:"rich-synthesis",active_world:"work",goal:"Ship the feature",captured_at:"2026-08-21T00:00:00Z"},
        data:{contract_version:"1.4.0"}}' > "${RELOAD_SEED_DIR}/continuation-seed.latest.json"

RELOAD_OUT="$(echo '{"source":"compact"}' | \
  CLAUDE_PROJECT_DIR="$RELOAD_REPO" POSTFLIGHT_SEED_DIR="$RELOAD_SEED_DIR" \
  bash "$RELOAD" 2>/dev/null)"
CTX="$(printf '%s' "$RELOAD_OUT" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)"

assert_true "$([[ "$CTX" == *"Active world: work (Two-Worlds boundary"* ]] && echo true || echo false)" \
  "additionalContext mentions the Two-Worlds boundary for active_world=work"

AW_LINE="$(printf '%s\n' "$CTX" | grep -n '^Active world:' | head -1 | cut -d: -f1)"
MISSION_LINE="$(printf '%s\n' "$CTX" | grep -n '^Mission:' | head -1 | cut -d: -f1)"
assert_true "$([[ -n "$AW_LINE" && -n "$MISSION_LINE" && "$AW_LINE" -lt "$MISSION_LINE" ]] && echo true || echo false)" \
  "active_world line renders BEFORE the mission line (foundational orientation ordering)"

# ── Case: no active_world in the seed -> line omitted entirely, no crash ──────
RELOAD_SEED_DIR2="${TEST_ROOT}/reload-seed-no-aw"; mkdir -p "$RELOAD_SEED_DIR2"
jq -n '{jsonrpc:"2.0",method:"session.continuation",
        params:{kind:"rich-synthesis",goal:"Ship the feature",captured_at:"2026-08-21T00:00:00Z"},
        data:{contract_version:"1.3.0"}}' > "${RELOAD_SEED_DIR2}/continuation-seed.latest.json"
RELOAD_OUT2="$(echo '{"source":"compact"}' | \
  CLAUDE_PROJECT_DIR="$RELOAD_REPO" POSTFLIGHT_SEED_DIR="$RELOAD_SEED_DIR2" \
  bash "$RELOAD" 2>/dev/null)"
CTX2="$(printf '%s' "$RELOAD_OUT2" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)"
assert_true "$([[ "$CTX2" != *"Active world:"* ]] && echo true || echo false)" \
  "no active_world in seed -> the line is omitted entirely (no 'Active world: (empty)' artifact)"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Results: ${TESTS_PASSED}/${TESTS_RUN} passed, ${TESTS_FAILED} failed"
echo "═══════════════════════════════════════════════════════════════════"

exit $((TESTS_FAILED > 0 ? 1 : 0))
