#!/usr/bin/env bash
# Test: agents/wacli-delegate.md — the wacli-delegate contract's mechanically-verifiable parts.
# ----------------------------------------------------------------------------
# wacli-delegate is a behavioral (Markdown) spec, not executable code, so this script does not
# "run the agent". It durably tests the ONE part of the contract that is deterministic and
# reproducible without an LLM: plan_digest canonicalization (a self-contained sorted-key/UTF-8/
# no-whitespace rule, not a general RFC 8785/JCS conformance claim - see the contract's own
# "Plan digest canonicalization" section). It also self-tests agents/fixtures/fake-wacli-stub.sh,
# the synthetic fixture used for LLM-driven contract-behavior evals (see
# agents/WACLI-DELEGATE-EVAL-REPORT.md for that run's results). Wired into CI by
# .github/workflows/wacli-delegate-contract-tests.yml.
#
# Function     : pin the deterministic parts of the wacli-delegate contract (plan_digest canonical
#                bytes, target/payload digest recomputation rule) and the fake stub's behaviour.
# Spec         : agents/wacli-delegate.md §"Plan digest canonicalization" + §"Execute" ·
#                agents/fixtures/fake-wacli-stub.sh header · agents/WACLI-DELEGATE-EVAL-REPORT.md
# Idempotent   : yes — read-only over the tree; the only writes are mktemp files removed on EXIT.
# Portability  : Bash 3.2+ · python3 · shasum|sha256sum · mktemp. No org-specific content.
# Layer purity : community-clean — synthetic account/target/payload values only.
#
# NOT `set -e`: this is an assertion harness — every check records its own outcome via ok/no and
# the script must keep going past a failing assertion to report the full picture (same pattern as
# tests/governance/test-postflight-active-world.sh and tests/converge/run.sh). Every command whose
# failure matters feeds an assertion; nothing can fail silently and still reach the PASS line.
set -uo pipefail
TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t 'wacli-contract')"
trap 'rm -rf "$TMPD"' EXIT
HERE="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACT="$HERE/agents/wacli-delegate.md"
STUB="$HERE/agents/fixtures/fake-wacli-stub.sh"
EVAL_REPORT="$HERE/agents/WACLI-DELEGATE-EVAL-REPORT.md"
fail=0
ok() { printf '  ok   %s\n' "$1"; }
no() { printf '  FAIL %s\n' "$1"; fail=1; }

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}';
  else sha256sum | awk '{print $1}'; fi
}

echo "test-wacli-delegate-contract:"

[ -f "$CONTRACT" ] || { echo "  FAIL contract file not found: $CONTRACT"; exit 2; }
[ -x "$STUB" ] || { echo "  FAIL fake stub not found/executable: $STUB"; exit 2; }
[ -f "$EVAL_REPORT" ] || { echo "  FAIL eval report referenced by this script's own header not found: $EVAL_REPORT"; exit 2; }

# ---- 1. plan_digest golden vector reproduces from the contract's own documented bytes --------
GOLDEN_LINE="$(grep -n '^{"account"' "$CONTRACT" | head -1 | cut -d: -f1)"
if [ -z "$GOLDEN_LINE" ]; then
  no "golden vector JSON line found in contract"
else
  GOLDEN_JSON="$(sed -n "${GOLDEN_LINE}p" "$CONTRACT")"
  GOLDEN_DIGEST="$(printf '%s' "$GOLDEN_JSON" | sha256_of)"
  EXPECTED_DIGEST="$(grep -o '[0-9a-f]\{64\}' "$CONTRACT" | tail -1)"
  if [ "$GOLDEN_DIGEST" = "$EXPECTED_DIGEST" ]; then
    ok "plan_digest golden vector reproduces: $GOLDEN_DIGEST"
  else
    no "golden vector mismatch: computed=$GOLDEN_DIGEST expected=$EXPECTED_DIGEST"
  fi
fi

# ---- 2. golden vector byte length matches the contract's own documented claim -----------------
#         (extracted dynamically from the "(N bytes, no trailing newline)" sentence so this check
#         can never drift out of sync with the contract prose again, per the #709-byte incident).
GOLDEN_BYTES="$(printf '%s' "$GOLDEN_JSON" | wc -c | tr -d ' ')"
CLAIMED_BYTES="$(grep -o '([0-9]\{1,\} bytes, no trailing newline)' "$CONTRACT" | grep -o '[0-9]\{1,\}' | head -1)"
if [ -z "$CLAIMED_BYTES" ]; then
  no "could not find the contract's own byte-length claim to check against"
elif [ "$GOLDEN_BYTES" = "$CLAIMED_BYTES" ]; then
  ok "golden vector is $GOLDEN_BYTES bytes, matching the contract's own claim"
else
  no "golden vector byte length drifted: got $GOLDEN_BYTES, contract claims $CLAIMED_BYTES"
fi

# ---- 3. canonicalization is deterministic: re-serializing the same object (key order shuffled) ----
#         via python json.dumps(sort_keys=True) must reproduce byte-identical output.
RECANON="$(python3 -c "
import json
obj = json.loads('''$GOLDEN_JSON''')
print(json.dumps(obj, sort_keys=True, separators=(',', ':'), ensure_ascii=False), end='')
")"
if [ "$RECANON" = "$GOLDEN_JSON" ]; then
  ok "canonicalization is idempotent under independent re-serialization"
else
  no "canonicalization is NOT idempotent - independent re-serialization produced different bytes"
fi

# ---- 3b. Execute gate 6 (parameter binding): target_digest / payload_digest in the golden plan
#          MUST equal plain SHA-256 of the raw unmasked values the contract documents for the
#          vector. This pins the recomputation rule an executor applies to the ACTUAL parameters
#          before the command: a request that keeps the approved plan but swaps the recipient or
#          text must fail this exact comparison (PLAN_MISMATCH).
RAW_TARGET="$(grep -o 'target_digest = sha256("[^"]*")' "$CONTRACT" | tail -1 | sed 's/.*sha256("\(.*\)")/\1/')"
RAW_PAYLOAD="$(grep -o 'payload_digest = sha256("[^"]*")' "$CONTRACT" | tail -1 | sed 's/.*sha256("\(.*\)")/\1/')"
PLAN_TARGET_DIGEST="$(printf '%s' "$GOLDEN_JSON" | grep -o '"target_digest":"[0-9a-f]\{64\}"' | grep -o '[0-9a-f]\{64\}')"
PLAN_PAYLOAD_DIGEST="$(printf '%s' "$GOLDEN_JSON" | grep -o '"payload_digest":"[0-9a-f]\{64\}"' | grep -o '[0-9a-f]\{64\}')"
if [ -z "$RAW_TARGET" ] || [ -z "$RAW_PAYLOAD" ]; then
  no "contract no longer documents the golden vector's raw target/payload (sha256(\"...\") lines)"
else
  [ "$(printf '%s' "$RAW_TARGET" | sha256_of)" = "$PLAN_TARGET_DIGEST" ] \
    && ok "golden target_digest recomputes from the raw unmasked target (parameter-binding rule)" \
    || no "golden target_digest does NOT recompute from the documented raw target"
  [ "$(printf '%s' "$RAW_PAYLOAD" | sha256_of)" = "$PLAN_PAYLOAD_DIGEST" ] \
    && ok "golden payload_digest recomputes from the raw payload text (parameter-binding rule)" \
    || no "golden payload_digest does NOT recompute from the documented raw payload"
  # negative: a swapped recipient with the plan left intact must NOT match
  [ "$(printf '%s' "${RAW_TARGET}-swapped" | sha256_of)" != "$PLAN_TARGET_DIGEST" ] \
    && ok "a swapped target no longer matches the approved target_digest" \
    || no "digest collision on swapped target (impossible unless sha256_of is broken)"
fi

# ---- 4. fake stub: deterministic, synthetic-only, refuses unknown accounts -------------------
VERSION_OUT="$("$STUB" --version)"
[ "$VERSION_OUT" = "wacli 0.18.1-fake-test-stub" ] && ok "stub --version deterministic" || no "stub --version drifted: $VERSION_OUT"

DOCTOR_OUT="$("$STUB" --account acct-test doctor)"
echo "$DOCTOR_OUT" | grep -q '"AUTHENTICATED":true' && ok "stub doctor returns fixed AUTHENTICATED state" || no "stub doctor output drifted"

if "$STUB" --account some-real-sounding-alias doctor >/dev/null 2>"$TMPD/stub_err"; then
  no "stub accepted an unknown account instead of refusing"
else
  grep -q ACCOUNT_NOT_FOUND "$TMPD/stub_err" && ok "stub refuses any account name other than acct-test" || no "stub refused for the wrong reason"
fi

if "$STUB" --account acct-test send text --to x --text y >/dev/null 2>"$TMPD/stub_send"; then
  no "stub allowed a send to succeed (must always refuse in this fixture)"
else
  grep -q REFUSED_BY_FAKE_STUB "$TMPD/stub_send" && ok "stub send path always refuses (exercises UPSTREAM_ERROR handling)" || no "stub send refused for the wrong reason"
fi

READONLY_SEARCH_OUT="$("$STUB" --account acct-test --read-only messages search)"
echo "$READONLY_SEARCH_OUT" | grep -q '"count":2' && ok "stub parses the documented '--account ACCOUNT --read-only ...' global-flag order before CMD" || no "stub misclassified --read-only as CMD instead of a global flag"

JSON_READONLY_SEARCH_OUT="$("$STUB" --account acct-test --read-only --json messages search --query hi)"
echo "$JSON_READONLY_SEARCH_OUT" | grep -q '"count":2' && ok "stub parses '--read-only --json' together before CMD" || no "stub misclassified --read-only/--json global-flag combination"

if "$STUB" --account acct-test auth logout >/dev/null 2>"$TMPD/stub_auth"; then
  no "stub silently allowed an unhandled auth subcommand instead of failing"
else
  grep -q UNKNOWN_FAKE_SUBCOMMAND "$TMPD/stub_auth" && ok "stub fails nonzero on an unsupported auth subcommand" || no "stub failed for the wrong reason on auth logout"
fi

if "$STUB" --account acct-test messages list >/dev/null 2>"$TMPD/stub_msg"; then
  no "stub silently allowed 'messages list' (only 'search' is supported) instead of failing"
else
  grep -q UNKNOWN_FAKE_SUBCOMMAND "$TMPD/stub_msg" && ok "stub fails nonzero on an unsupported messages subcommand" || no "stub failed for the wrong reason on messages list"
fi

if "$STUB" --account acct-test messages search --bogus-flag >/dev/null 2>"$TMPD/stub_flag"; then
  no "stub silently ignored an unsupported messages search flag instead of failing"
else
  grep -q UNSUPPORTED_FLAG "$TMPD/stub_flag" && ok "stub fails nonzero on an unsupported messages search flag" || no "stub failed for the wrong reason on an unsupported flag"
fi

if "$STUB" --account acct-test doctor --connect --bogus >/dev/null 2>"$TMPD/stub_doc"; then
  no "stub accepted surplus arguments after 'doctor --connect' instead of failing"
else
  grep -q UNSUPPORTED_FLAG "$TMPD/stub_doc" && ok "stub rejects surplus arguments after 'doctor --connect'" || no "stub failed for the wrong reason on 'doctor --connect --bogus'"
fi

if "$STUB" --account acct-test auth status --bogus >/dev/null 2>"$TMPD/stub_auth2"; then
  no "stub accepted surplus arguments after 'auth status' instead of failing"
else
  grep -q UNSUPPORTED_FLAG "$TMPD/stub_auth2" && ok "stub rejects surplus arguments after 'auth status'" || no "stub failed for the wrong reason on 'auth status --bogus'"
fi

# The fail() payload must stay valid JSON when an offending argument carries a carriage return.
# This verifies that CR is encoded as JSON's `\\r`, rather than emitted as a literal control byte.
CR_FLAG=$'--bad\rflag'
"$STUB" --account acct-test messages search "$CR_FLAG" >/dev/null 2>"$TMPD/stub_cr" || true
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["detail"] == "messages search " + sys.argv[2]' "$TMPD/stub_cr" "$CR_FLAG" 2>/dev/null \
  && ok "stub error envelope stays valid JSON for a carriage-return argument" \
  || no "stub error envelope is not valid JSON for a carriage-return argument"

# Bash argv cannot carry NUL. Exercise every other C0 byte in one hostile argument and require the
# decoded JSON value to round-trip exactly; CR remains covered independently above for legibility.
C0_CONTROLS=""
for C0_CODE in {1..31}; do
  printf -v C0_CHAR "\\$(printf '%03o' "$C0_CODE")"
  C0_CONTROLS+="$C0_CHAR"
done
"$STUB" --account acct-test messages search "$C0_CONTROLS" >/dev/null 2>"$TMPD/stub_c0" || true
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["detail"] == "messages search " + sys.argv[2]' "$TMPD/stub_c0" "$C0_CONTROLS" 2>/dev/null \
  && ok "stub error envelope stays valid JSON for every argv-representable C0 control" \
  || no "stub error envelope is not valid JSON for an argv-representable C0 control"

echo
if [ "$fail" -eq 0 ]; then
  echo "test-wacli-delegate-contract: PASS"
else
  echo "test-wacli-delegate-contract: FAIL"
fi
exit "$fail"
