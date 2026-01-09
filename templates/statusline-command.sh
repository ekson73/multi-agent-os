#!/bin/bash

# /**
#  * Enriched Status Line for Claude Code with Multi-Agent-OS Integration
#  * @version 1.0.1
#  * @author Multi-Agent-OS Framework
#  * @context Displays model, project, branch, worktree, state, cost, and context metrics
#  * @reason Provides real-time visibility into session state and resource usage
#  * @impact Performance target: < 100ms total execution
#  */

set -euo pipefail

# Check jq dependency
if ! command -v jq &> /dev/null; then
  echo "Claude | jq not found"
  exit 0
fi

# Read JSON input from stdin
INPUT=$(cat)

# ============================================================================
# CORE DATA EXTRACTION
# ============================================================================

# Model info
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "Claude"')
MODEL_ID=$(echo "$INPUT" | jq -r '.model.id // ""')

# Extract version number from model ID (e.g., "4.5" from "claude-opus-4-5-20251101")
MODEL_VERSION=""
if [ -n "$MODEL_ID" ]; then
  MODEL_VERSION=$(echo "$MODEL_ID" | sed -E 's/.*-([0-9]+)-([0-9]+)-.*/\1.\2/')
  [ "$MODEL_VERSION" = "$MODEL_ID" ] && MODEL_VERSION=""  # Reset if no match
fi

# Workspace info with proper fallbacks
CWD=$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd // ""')
[ -z "$CWD" ] || [ "$CWD" = "null" ] && CWD=$(pwd)

PROJECT_DIR=$(echo "$INPUT" | jq -r '.workspace.project_dir // ""')
[ -z "$PROJECT_DIR" ] || [ "$PROJECT_DIR" = "null" ] && PROJECT_DIR="$CWD"

DIR=$(basename "$PROJECT_DIR")

# Session info
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
CC_SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

# Cost info
COST_USD=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0')

# Context window info
CONTEXT_MAX=$(echo "$INPUT" | jq -r '.context_window.context_window_size // 200000')
CONTEXT_INPUT=$(echo "$INPUT" | jq -r '.context_window.current_usage.input_tokens // 0')
CONTEXT_OUTPUT=$(echo "$INPUT" | jq -r '.context_window.current_usage.output_tokens // 0')

# ============================================================================
# CALCULATED METRICS
# ============================================================================

# Context usage percentage
CONTEXT_USED_PCT=0
if [ "$CONTEXT_MAX" -gt 0 ]; then
  CONTEXT_USED_PCT=$((CONTEXT_INPUT * 100 / CONTEXT_MAX))
fi

# Until auto-compact percentage (threshold ~95%)
UNTIL_COMPACT=$((95 - CONTEXT_USED_PCT))
[ "$UNTIL_COMPACT" -lt 0 ] && UNTIL_COMPACT=0

# Context indicator with visual semaphore
CONTEXT_INDICATOR=""
if [ "$CONTEXT_USED_PCT" -ge 85 ]; then
  CONTEXT_INDICATOR="🔴"
elif [ "$CONTEXT_USED_PCT" -ge 70 ]; then
  CONTEXT_INDICATOR="🟠"
elif [ "$CONTEXT_USED_PCT" -ge 50 ]; then
  CONTEXT_INDICATOR="🟡"
else
  CONTEXT_INDICATOR="🟢"
fi

# ============================================================================
# GIT BRANCH DETECTION
# ============================================================================

BRANCH=""
if [ -d "$CWD/.git" ] || git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "")
fi

# ============================================================================
# WORKTREE DETECTION
# ============================================================================

IN_WORKTREE=""
WORKTREE_NAME=""
SHORT_ID=""

if echo "$CWD" | grep -q "\.worktrees/"; then
  WORKTREE_NAME=$(echo "$CWD" | sed 's/.*\.worktrees\///' | cut -d'/' -f1)
  IN_WORKTREE="true"

  # Extract short ID (first 4 chars) if worktree name has format: {shortId}-{feature}
  SHORT_ID=$(echo "$WORKTREE_NAME" | cut -d'-' -f1)
  [ ${#SHORT_ID} -eq 4 ] || SHORT_ID=""
fi

# ============================================================================
# MULTI-AGENT-OS SESSION STATE
# ============================================================================

SESSION_STATE=""
SESSION_REGISTRY="$PROJECT_DIR/.worktrees/sessions.json"

if [ -f "$SESSION_REGISTRY" ]; then
  # Try to find active session by short ID from worktree or session UUID
  if [ -n "$SHORT_ID" ]; then
    SESSION_STATE=$(jq -r ".active_sessions[] | select(.session_id | contains(\"$SHORT_ID\")) | .state // empty" "$SESSION_REGISTRY" 2>/dev/null || echo "")
  fi
  
  # Fallback: get first active session state if no specific match
  if [ -z "$SESSION_STATE" ]; then
    SESSION_STATE=$(jq -r ".active_sessions[0].state // empty" "$SESSION_REGISTRY" 2>/dev/null || echo "")
  fi
fi

TERM_WIDTH=${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}

# ============================================================================
# STATUSLINE RENDERING
# ============================================================================

if [ "$TERM_WIDTH" -ge 120 ]; then
  # ========================================
  # WIDE FORMAT (>= 120 cols)
  # ========================================

  printf "\033[1m%s" "$MODEL"
  [ -n "$MODEL_VERSION" ] && printf " %s" "$MODEL_VERSION"
  printf "\033[0m"

  # Project name
  printf " │ \033[36m%s\033[0m" "$DIR"

  # Branch
  if [ -n "$BRANCH" ]; then
    printf " │ \033[33m∠%s\033[0m" "$BRANCH"
  fi

  # Worktree
  if [ -n "$WORKTREE_NAME" ]; then
    printf " │ \033[32m🔧%s\033[0m" "$WORKTREE_NAME"
  fi

  # Session state
  if [ -n "$SESSION_STATE" ]; then
    case "$SESSION_STATE" in
      active)   printf " │ \033[32m⏱active\033[0m" ;;
      paused)   printf " │ \033[33m⏸paused\033[0m" ;;
      archived) printf " │ \033[90m📦archived\033[0m" ;;
      *)        printf " │ \033[35m⏱%s\033[0m" "$SESSION_STATE" ;;
    esac
  fi

  # Cost
  printf " │ \033[35m💰\$%.3f\033[0m" "$COST_USD"

  # Context usage
  printf " │ %s\033[34m%d%%\033[0m" "$CONTEXT_INDICATOR" "$CONTEXT_USED_PCT"

  # Until compact
  if [ "$UNTIL_COMPACT" -le 10 ]; then
    printf " │ \033[31m⏳%d%% left\033[0m" "$UNTIL_COMPACT"
  elif [ "$UNTIL_COMPACT" -le 25 ]; then
    printf " │ \033[33m⏳%d%% left\033[0m" "$UNTIL_COMPACT"
  else
    printf " │ \033[90m⏳%d%% left\033[0m" "$UNTIL_COMPACT"
  fi

else
  # ========================================
  # COMPACT FORMAT (< 120 cols)
  # ========================================

  printf "\033[1m%s\033[0m" "$MODEL"

  # Project/Branch
  printf " | \033[36m%s\033[0m" "$DIR"
  [ -n "$BRANCH" ] && printf "/\033[33m%s\033[0m" "$BRANCH"

  # Worktree (short)
  [ -n "$WORKTREE_NAME" ] && printf " | \033[32mwt:%s\033[0m" "$WORKTREE_NAME"

  # State (short)
  if [ -n "$SESSION_STATE" ]; then
    case "$SESSION_STATE" in
      active)   printf " | \033[32m●\033[0m" ;;
      paused)   printf " | \033[33m⏸\033[0m" ;;
      archived) printf " | \033[90m📦\033[0m" ;;
      *)        printf " | \033[35m%s\033[0m" "$SESSION_STATE" ;;
    esac
  fi

  # Cost + Context (compact)
  printf " | \$%.2f | %s%d%%↗%d%%" "$COST_USD" "$CONTEXT_INDICATOR" "$CONTEXT_USED_PCT" "$UNTIL_COMPACT"

fi

echo
