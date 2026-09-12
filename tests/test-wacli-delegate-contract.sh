#!/usr/bin/env bash
# Test: agents/wacli-delegate.md — the wacli-delegate contract's mechanically-verifiable parts.
# ----------------------------------------------------------------------------
# wacli-delegate is a behavioral (Markdown) spec, not executable code, so this script does not
# "run the agent". It durably tests the ONE part of the contract that is deterministic and
# reproducible without an LLM: plan_digest canonicalization (RFC-8785-style canonical JSON ->
# SHA-256). It also self-tests agents/fixtures/fake-wacli-stub.sh, the synthetic fixture used for
# LLM-driven contract-behavior evals (see agents/wacli-delegate.EVAL-REPORT.md for that run's
# results). Portable (bash 3.2 + python3 + shasum/sha256sum, whichever is present).
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACT="$HERE/agents/wacli-delegate.md"
STUB="$HERE/agents/fixtures/fake-wacli-stub.sh"
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

# ---- 4. fake stub: deterministic, synthetic-only, refuses unknown accounts -------------------
VERSION_OUT="$("$STUB" --version)"
[ "$VERSION_OUT" = "wacli 0.18.1-fake-test-stub" ] && ok "stub --version deterministic" || no "stub --version drifted: $VERSION_OUT"

DOCTOR_OUT="$("$STUB" --account acct-test doctor)"
echo "$DOCTOR_OUT" | grep -q '"AUTHENTICATED":true' && ok "stub doctor returns fixed AUTHENTICATED state" || no "stub doctor output drifted"

if "$STUB" --account some-real-sounding-alias doctor >/dev/null 2>/tmp/stub_err_$$; then
  no "stub accepted an unknown account instead of refusing"
else
  grep -q ACCOUNT_NOT_FOUND /tmp/stub_err_$$ && ok "stub refuses any account name other than acct-test" || no "stub refused for the wrong reason"
fi
rm -f /tmp/stub_err_$$

if "$STUB" --account acct-test send text --to x --text y >/dev/null 2>/tmp/stub_send_$$; then
  no "stub allowed a send to succeed (must always refuse in this fixture)"
else
  grep -q REFUSED_BY_FAKE_STUB /tmp/stub_send_$$ && ok "stub send path always refuses (exercises UPSTREAM_ERROR handling)" || no "stub send refused for the wrong reason"
fi
rm -f /tmp/stub_send_$$

echo
if [ "$fail" -eq 0 ]; then
  echo "test-wacli-delegate-contract: PASS"
else
  echo "test-wacli-delegate-contract: FAIL"
fi
exit "$fail"
