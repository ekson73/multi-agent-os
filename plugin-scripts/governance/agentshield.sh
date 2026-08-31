#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance: agentshield.sh
# Purpose: PreToolUse enforcement of the C6 content-security invariant (RULE-012).
#   The BLOCKING leg of the cascade-resolved HYBRID enforcement (sibling of WT1's
#   advisory SessionStart conductor-scan). On every Bash / Task tool call, scan
#   the channel payload and emit a RULE-012 c6_egress_check{channel, classification,
#   secret_match, decision} LOGGED FIELD. Unlike C1 (advisory, never aborts), C6 is
#   a BLOCKING gate (exit 2 + JSON-RPC error) when:
#     secret_match≠null              → a leaked credential (classification=secret)
#     egress host ∉ allowlist (set)  → exfil to an un-allowlisted host (=egress)
#     git --no-verify (Bash)         → bypass of the secret-at-rest floor (=hook_bypass)
#   Channels: Bash → .tool_input.command (channel=tool_input); Task →
#   .tool_input.prompt (channel=model_output — model-generated text fed to a
#   sub-agent; the keystone DoD-gate: a planted secret here MUST block).
#
#   Availability-safe by design: a malformed input or scan error defaults to
#   ALLOW (an unparseable tool call must not wedge the agent) — but a MATCHED
#   secret ALWAYS blocks (as_check checks the secret first, deterministically).
#   Leak-safe: the raw payload is never serialized; secret_match reports the KIND
#   of secret (e.g. "anthropic_key"), never the value (see lib/agentshield-scan.sh).
# Version: 1.0.0
# Protocol: ADR-006 §4 content-security (C6) · moe-hub-architecture · maos-hub spec RULE-012
#
# Opt-out: MAOS_NO_AGENTSHIELD=1 → skip the gate entirely (allow, report nothing).
# Egress allowlist (opt-in): MAOS_AGENTSHIELD_ALLOWLIST="github.com,pypi.org …"
#   (whitespace/comma-separated host suffixes). EMPTY (default) → egress NOT
#   enforced; only secrets + --no-verify block.
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/json-rpc.sh"
source "${LIB_DIR}/agentshield-scan.sh"

EXIT_OK="${EXIT_SUCCESS:-0}"

# Opt-out.
if [ "${MAOS_NO_AGENTSHIELD:-0}" = "1" ]; then
    exit "$EXIT_OK"
fi

# Nested json paths (.tool_input.command / .tool_input.prompt) → jq is required.
# require_jq emits an allow-JSON + exits EXIT_ERROR (non-blocking) when jq is
# absent, so a jq-less environment degrades to no-op rather than blocking work.
require_jq

TOOL_INPUT=$(cat)
# `|| true`: json_get exits non-zero on MALFORMED json (jq parse error); under
# `set -e` that would abort BEFORE the allow fallback, contradicting the
# availability-safe contract (an unparseable tool call must degrade to ALLOW, not
# wedge the agent). The guard makes each extraction yield empty → the `*) allow`
# fallback (empty TOOL_NAME) or a clean as_check (empty PAYLOAD).
TOOL_NAME="$(json_get "$TOOL_INPUT" '.tool_name' || true)"
ALLOWLIST="${MAOS_AGENTSHIELD_ALLOWLIST:-}"

CHANNEL=""
PAYLOAD=""
BYPASS=""
case "$TOOL_NAME" in
    Bash)
        CHANNEL="tool_input"
        PAYLOAD="$(json_get "$TOOL_INPUT" '.tool_input.command' || true)"
        BYPASS="$(as_bash_bypass "$PAYLOAD")"
        ;;
    Task)
        CHANNEL="model_output"
        PAYLOAD="$(json_get "$TOOL_INPUT" '.tool_input.prompt' || true)"
        ;;
    *)
        # Not a channel we gate (defensive — hooks.json only wires Bash|Task) → allow.
        exit "$EXIT_OK"
        ;;
esac

# Compute the RULE-012 verdict. `|| as_json … allow` is the availability-safe
# default for an unexpected scan error — but the secret path inside as_check
# returns deterministically first, so a real secret is never masked by this.
# Precedence: secret > egress > hook_bypass (a --no-verify only escalates a call
# that as_check would otherwise have allowed — so a leaked secret keeps its
# higher-severity classification).
SCAN_JSON="$(as_check "$CHANNEL" "$PAYLOAD" "$ALLOWLIST" 2>/dev/null || as_json "$CHANNEL" "clean" "" "allow")"
if [ -n "$BYPASS" ]; then
    _ac_decision="$(printf '%s' "$SCAN_JSON" | sed -n 's/.*"decision":"\([a-z]*\)".*/\1/p')"
    if [ "$_ac_decision" != "block" ]; then
        SCAN_JSON="$(as_json "$CHANNEL" "hook_bypass" "" "block")"
    fi
fi

# Extract fields from our OWN controlled JSON (sed — values are fixed-vocab; no
# `\|` alternation, which BSD sed lacks). secret_match: only the quoted form
# matches (null → empty).
DECISION="$(printf '%s' "$SCAN_JSON" | sed -n 's/.*"decision":"\([a-z]*\)".*/\1/p')"
CLASSIFICATION="$(printf '%s' "$SCAN_JSON" | sed -n 's/.*"classification":"\([a-z_]*\)".*/\1/p')"
SECRET_MATCH="$(printf '%s' "$SCAN_JSON" | sed -n 's/.*"secret_match":"\([a-z_]*\)".*/\1/p')"
[ -n "$DECISION" ] || DECISION="allow"

# Audit — the RULE-012 LOGGED FIELD (no-op unless an audit dir exists).
log_audit "c6_egress_check" "$SCAN_JSON" || true

if [ "$DECISION" = "block" ]; then
    # Leak-safe block message — classification + signature-id only; never the value.
    case "$CLASSIFICATION" in
        secret)
            MSG="AgentShield RULE-012: a secret (${SECRET_MATCH}) was detected in the ${CHANNEL} of this ${TOOL_NAME} call — blocked to prevent exfiltration. Remove the credential (use an env var / secret manager reference); never embed it in a command or a sub-agent prompt."
            SUGGEST="Strip the ${SECRET_MATCH}; reference it via an env var or secret manager, then retry." ;;
        egress)
            MSG="AgentShield RULE-012: this ${TOOL_NAME} call targets an egress host outside the configured allowlist (MAOS_AGENTSHIELD_ALLOWLIST) — blocked."
            SUGGEST="Add the intended host to MAOS_AGENTSHIELD_ALLOWLIST, or remove the egress, then retry." ;;
        hook_bypass)
            MSG="AgentShield RULE-012: 'git --no-verify' bypasses the secret-at-rest verification hooks — blocked. Commit/push without --no-verify so the gitleaks floor can run."
            SUGGEST="Re-run the git command WITHOUT --no-verify." ;;
        *)
            MSG="AgentShield RULE-012: content-security gate blocked this ${TOOL_NAME} call (${CLASSIFICATION})."
            SUGGEST="Review and remove the flagged content, then retry." ;;
    esac

    local_sm="null"
    [ -n "$SECRET_MATCH" ] && local_sm="\"${SECRET_MATCH}\""
    EXTRA="\"classification\":\"${CLASSIFICATION}\",\"channel\":\"${CHANNEL}\",\"secret_match\":${local_sm},\"rule\":\"RULE-012\",\"protocol\":\"ADR-006 content-security (C6)\""

    log_audit "c6_egress_check_block" "$SCAN_JSON" || true
    json_error "-32004" "$MSG" "PreToolUse:${TOOL_NAME}" "$SUGGEST" "$EXTRA"
    # Concise human line (stderr) — avoids json-rpc.sh's C04-specific human_error banner.
    echo "🛡️  AgentShield RULE-012 BLOCK (${CLASSIFICATION}) on channel=${CHANNEL} for ${TOOL_NAME}." >&2
    exit "$EXIT_BLOCKED"
fi

exit "$EXIT_OK"
