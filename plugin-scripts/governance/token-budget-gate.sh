#!/usr/bin/env bash
# token-budget-gate.sh
# GaaS Motor 1: detects context bloat before delegation
# Integrates with RULE-009 of Sentinel (Token Bloat — severity LOW)
# Non-blocking (RULE-009 has auto_block: false) — suggests compression
#
# MEASUREMENT NOTE:
#   wc -c measures characters, not tokens. Heuristic: ~4 chars/token for English.
#   Threshold 4000c ~ ~1000 tokens. For mixed content (code + prose + unicode),
#   variance is high. Acceptable as MVP advisory. Future evolution: use tiktoken
#   or chars/4 as explicit estimate.
#
# PROV: https://github.com/ekson73/multi-agent-os/blob/main/plugin-scripts/governance/token-budget-gate.sh
# Version: 1.0.0 | Created: 2026-04-10
# Protocol: RULE-009 (Token Bloat)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source shared libraries if available
if [[ -f "${LIB_DIR}/common.sh" ]]; then
  source "${LIB_DIR}/common.sh"
fi

# Read input from stdin
INPUT=$(cat)

# Extract tool name
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

# Only applies to Task (delegation) tool calls
if [[ "$TOOL" != "Task" ]]; then
  echo "{}"
  exit 0
fi

# Measure spawn prompt length (chars as heuristic for tokens)
SPAWN_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null || echo "")
SPAWN_PROMPT_LENGTH=${#SPAWN_PROMPT}
THRESHOLD=4000

if [[ "$SPAWN_PROMPT_LENGTH" -gt "$THRESHOLD" ]]; then
  # Advisory suggestion — non-blocking (aligned with RULE-009 auto_block: false)
  echo "{\"decision\":\"allow\",\"reason\":\"token-budget-gate: spawn context ${SPAWN_PROMPT_LENGTH}c exceeds ${THRESHOLD}c threshold (~$((SPAWN_PROMPT_LENGTH / 4)) tokens est.). Consider response-compression:full for sub-agent.\",\"hookSpecificOutput\":{\"sentinel_rule\":\"RULE-009\",\"suggestion\":\"response-compression:full\",\"context_chars\":${SPAWN_PROMPT_LENGTH},\"estimated_tokens\":$((SPAWN_PROMPT_LENGTH / 4)),\"threshold_chars\":${THRESHOLD}}}"
else
  echo "{}"
fi
