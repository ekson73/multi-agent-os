#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# MAOS Governance: single-conductor-scan.sh
# Purpose: SessionStart enforcement of the C1 single-conductor invariant (RULE-011).
#   MAOS is the only always-on L0/L2/L3 conductor. At session start, scan the
#   PROJECT scope (this checkout's .claude/skills/plugins) and the USER scope
#   (~/.claude) for the footprint of a competing always-on manager
#   (bmad-method · superpowers · gstack · ECC · base · ruflo — lib/conductors.txt)
#   and emit a RULE-011 c1_conductor_scan{detected_conductors[], scope, decision}
#   LOGGED field. decision ∈ {clean, taint, refuse}:
#     refuse  — a competitor co-resident in THIS PROJECT (real duplicate-hooks
#               conflict) → loud warning; route it via agentic-tool-intake.
#     taint   — a competitor present only USER-globally (operator's own env) →
#               advisory note; the session is NOT disrupted.
#     clean   — none found.
#   This is the runtime half of the cascade-resolved HYBRID enforcement (the
#   advisory cross-harness rule lives in agentic-tool-intake; the BLOCKING CI
#   floor is harness-agnostic). It NEVER aborts the session (always exit 0) —
#   the teeth are the logged decision + the surfaced warning (warn→correct→block).
# Version: 1.0.0
# Protocol: ADR-006 §4 · moe-hub-architecture Invariant 1 · maos-hub spec RULE-011
#
# Opt-out: MAOS_NO_CONDUCTOR_SCAN=1 → skip the scan entirely (report nothing).
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/conductor-scan.sh"

EXIT_OK="${EXIT_SUCCESS:-0}"

# Opt-out.
if [ "${MAOS_NO_CONDUCTOR_SCAN:-0}" = "1" ]; then
    exit "$EXIT_OK"
fi

# Scopes. PROJECT = the checkout Claude Code started in; USER = ~/.claude.
PROJECT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# HOME-safe under `set -u`: prefer CLAUDE_CONFIG_DIR; else ~/.claude when HOME is
# set; else degrade to no user-scope (an unbound $HOME must NOT abort the hook —
# the "always exit 0" contract). A missing user scope just yields no user hits.
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    USER_CLAUDE="$CLAUDE_CONFIG_DIR"
elif [ -n "${HOME:-}" ]; then
    USER_CLAUDE="$HOME/.claude"
else
    USER_CLAUDE=""
fi

# Run the pure scan (never fails the hook — default to a clean verdict on error).
SCAN_JSON="$(csc_scan "$PROJECT" "$USER_CLAUDE" 2>/dev/null || echo '{"rule":"RULE-011","event":"c1_conductor_scan","detected_conductors":[],"scope":"none","decision":"clean"}')"

# Extract the fields from our OWN controlled JSON (grep/sed — no jq dependency).
DECISION="$(printf '%s' "$SCAN_JSON" | sed -n 's/.*"decision":"\([a-z]*\)".*/\1/p')"
SCOPE="$(printf '%s' "$SCAN_JSON" | sed -n 's/.*"scope":"\([a-z]*\)".*/\1/p')"
DETECTED="$(printf '%s' "$SCAN_JSON" | sed -n 's/.*"detected_conductors":\[\([^]]*\)\].*/\1/p' | tr -d '"' )"
[ -n "$DECISION" ] || DECISION="clean"

# Audit (no-op unless an audit dir exists) — the RULE-011 LOGGED FIELD.
log_audit "c1_conductor_scan" "$SCAN_JSON" || true

# Human summary → stderr (visible, non-blocking).
case "$DECISION" in
    refuse)
        echo "🚨 RULE-011 single-conductor REFUSE: competing always-on manager(s) co-resident in THIS project: ${DETECTED}. MAOS must be the only conductor — route them via /maos:agentic-tool-intake (adapt/sub-agent/abandon), never stack runtimes (ADR-006 §4)." >&2
        ;;
    taint)
        echo "⚠️  RULE-011 single-conductor TAINT: competing manager(s) present user-globally: ${DETECTED}. Advisory only (session not disrupted); avoid co-activating them as resident layers in this project." >&2
        ;;
    *)
        echo "🛡️  RULE-011 single-conductor: clean (no competing always-on manager detected)." >&2
        ;;
esac

# Machine context → stdout as SessionStart additionalContext (surfaced to the agent).
case "$DECISION" in
    refuse)
        CTX="C1 single-conductor RULE-011 decision=refuse scope=${SCOPE} — competing always-on manager(s) co-resident in THIS project: ${DETECTED}. MAOS is the sole conductor: do NOT stack their runtimes; route via /maos:agentic-tool-intake (adapt/sub-agent/abandon) in an isolated worktree (ADR-006 §4)." ;;
    taint)
        CTX="C1 single-conductor RULE-011 decision=taint scope=${SCOPE} — competing manager(s) present user-globally: ${DETECTED}. Advisory: do not co-activate them as resident layers in this project." ;;
    *)
        CTX="C1 single-conductor RULE-011 decision=clean — MAOS is the sole always-on conductor." ;;
esac
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$(json_escape "$CTX")"

exit "$EXIT_OK"
