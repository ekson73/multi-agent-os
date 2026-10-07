#!/usr/bin/env bash
# /**
#  * Dogfood Test — auto-pilot skill
#  * @context Two scripted scenarios exercising the prompt-construction surface
#  *          of skills/auto-pilot/SKILL.md without spawning real Task agents.
#  * @reason Validate backward-compat of delegation-dna-prompt v1.1 + skill wiring
#  * @impact Catches regressions in delegate.sh + DNA payload block + converge ref
#  */

set -euo pipefail

PLUGIN_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DELEGATE="${PLUGIN_ROOT}/plugin-scripts/gaac/delegate.sh"
SKILL="${PLUGIN_ROOT}/skills/auto-pilot/SKILL.md"
CMD="${PLUGIN_ROOT}/commands/auto-pilot.md"
DNA_PROMPT="${PLUGIN_ROOT}/protocols/delegation/delegation-dna-prompt.md"
CONVERGE_SKILL="${PLUGIN_ROOT}/skills/converge/SKILL.md"

ERRORS=0

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; ERRORS=$((ERRORS + 1)); }

echo "========================================"
echo "  Dogfood — auto-pilot (2 cycles)"
echo "========================================"
echo ""

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------
echo "Preconditions..."
for f in "$DELEGATE" "$SKILL" "$CMD" "$DNA_PROMPT" "$CONVERGE_SKILL"; do
    if [ -f "$f" ]; then
        pass "exists: ${f#$PLUGIN_ROOT/}"
    else
        fail "missing: ${f#$PLUGIN_ROOT/}"
    fi
done
[ -x "$DELEGATE" ] && pass "delegate.sh executable" || fail "delegate.sh not executable"
echo ""

# ---------------------------------------------------------------------------
# Cycle 1 — sequential / L1-cautious, depth=0
# ---------------------------------------------------------------------------
echo "Cycle 1 — sequential / L1-cautious..."

# 1a. init still exits 0 with non-empty stdout (DNA v1.1 is additive; init unchanged)
if INIT_OUT=$(env -u TICKET bash "$DELEGATE" init --provider=none 2>/dev/null) && [ -n "$INIT_OUT" ]; then
    pass "delegate.sh init exits 0 with non-empty stdout"
else
    fail "delegate.sh init failed or empty"
fi

# 1b. dna emits the new v1.1 header
if DNA_OUT=$(bash "$DELEGATE" dna 2>/dev/null) && echo "$DNA_OUT" | grep -q "DNA Payload v1.1"; then
    pass "delegate.sh dna output contains 'DNA Payload v1.1' header"
else
    fail "delegate.sh dna output missing 'DNA Payload v1.1' header"
fi

# 1c. DNA payload spec lists all required fields
for field in parent_agent_id depth mode autonomy_band goal_root attempts_remaining escalation_triggers; do
    if grep -q "^${field}:" "$DNA_PROMPT"; then
        pass "DNA payload field present: ${field}"
    else
        fail "DNA payload field missing: ${field}"
    fi
done

# 1d. depth hard-cap 2 documented (both skill + DNA prompt)
if grep -q "hard-cap 2" "$DNA_PROMPT" && grep -q "depth ≤ 2" "$SKILL"; then
    pass "depth hard-cap 2 documented in skill + DNA prompt"
else
    fail "depth hard-cap 2 not consistently documented"
fi
echo ""

# ---------------------------------------------------------------------------
# Cycle 2 — debate-converge: skill cites converge with the right CLI signature
# ---------------------------------------------------------------------------
echo "Cycle 2 — debate-converge..."

# 2a. skill references converge by path
if grep -q "skills/converge/SKILL.md" "$SKILL"; then
    pass "auto-pilot SKILL.md references converge by path"
else
    fail "auto-pilot SKILL.md missing converge reference"
fi

# 2b. converge skill exposes the documented CLI shape (converge <files> --output)
if grep -q "^converge .* --output" "$CONVERGE_SKILL"; then
    pass "converge skill exposes 'converge ... --output' CLI shape"
else
    fail "converge skill does not expose '--output' CLI; auto-pilot doc may be stale"
fi

# 2c. auto-pilot documents max_rounds ≤ 3 to match converge's max_rounds cap
if grep -q "max_rounds ≤ 3" "$SKILL" && grep -q "max_rounds" "$CONVERGE_SKILL"; then
    pass "auto-pilot debate-converge mode honors converge max_rounds cap"
else
    fail "max_rounds ≤ 3 not aligned between auto-pilot and converge"
fi
echo ""

# ---------------------------------------------------------------------------
# Cycle 3 — DNA payload v1.2: authority fields are optional and additive
# ---------------------------------------------------------------------------
echo "Cycle 3 — DNA payload v1.2 (authority)..."

# 3a. the two new fields are in the payload spec
for field in depth_remaining authority_scope; do
    if grep -q "^${field}:" "$DNA_PROMPT"; then
        pass "DNA payload v1.2 field present: ${field}"
    else
        fail "DNA payload v1.2 field missing: ${field}"
    fi
done

# 3b. both are documented as optional, and absence is fail-closed (leaf, no extra authority)
if grep -q "DNA Payload v1.2" "$DNA_PROMPT" \
   && grep -qi "optional" "$DNA_PROMPT" \
   && grep -qi "absent.*leaf\|leaf.*absent" "$DNA_PROMPT"; then
    pass "v1.2 fields documented as optional with fail-closed absence"
else
    fail "v1.2 optional/fail-closed semantics not documented"
fi

# 3c. authority_scope is bounded by the parent (subset, never widens)
if grep -qi "subset" "$DNA_PROMPT" && grep -qi "never widen" "$DNA_PROMPT"; then
    pass "authority_scope documented as subset of parent, never widened"
else
    fail "authority_scope bound (subset / never widen) not documented"
fi

# 3d. consumers unaffected: delegate.sh still emits the doc verbatim, and the
#     v1.1 header + every v1.1 field is still there (old readers keep working)
if DNA_OUT=$(bash "$DELEGATE" dna 2>/dev/null) \
   && echo "$DNA_OUT" | grep -q "DNA Payload v1.1" \
   && echo "$DNA_OUT" | grep -q "^depth_remaining:"; then
    pass "delegate.sh dna emits v1.1 header and v1.2 fields"
else
    fail "delegate.sh dna output lost the v1.1 header or the v1.2 fields"
fi

# 3e. no runtime script parses the payload fields (they are prompt text, not a wire format);
#     if this ever changes, the new reader must be added to this test
readers=$(grep -rlE "depth_remaining|authority_scope" "${PLUGIN_ROOT}/plugin-scripts" "${PLUGIN_ROOT}/bin" "${PLUGIN_ROOT}/hooks" 2>/dev/null || true)
if [ -z "$readers" ]; then
    pass "no runtime script parses the v1.2 fields (additive by construction)"
else
    fail "runtime readers of v1.2 fields found — extend this test to cover them: $readers"
fi
echo ""

# ---------------------------------------------------------------------------
# Cross-cutting
# ---------------------------------------------------------------------------
echo "Cross-cutting checks..."

# Sentinel rule references must resolve to actual rule IDs in the rules file
SENTINEL_RULES="${PLUGIN_ROOT}/sentinel/detection_rules.md"
for rule in RULE-001 RULE-002 RULE-009; do
    if grep -q "$rule" "$SKILL" && grep -q "$rule" "$SENTINEL_RULES"; then
        pass "Sentinel $rule referenced and exists"
    else
        fail "Sentinel $rule reference broken (skill or rules file)"
    fi
done

# Reciprocity: delegate-governance links back to auto-pilot
if grep -q "skills/auto-pilot/SKILL.md" "${PLUGIN_ROOT}/skills/delegate-governance/SKILL.md"; then
    pass "delegate-governance reciprocally links auto-pilot"
else
    fail "delegate-governance missing reciprocal link"
fi
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "========================================"
if [ "$ERRORS" -eq 0 ]; then
    echo "  Status: ✓ PASSED (3 cycles green)"
    exit 0
else
    echo "  Status: ✗ FAILED — $ERRORS error(s)"
    exit 1
fi
