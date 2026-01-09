#!/usr/bin/env bash
# /**
#  * Session Start Hook - MAOS (Multi-Agent OS)
#  * @context Claude Code plugin hook - executes at session initialization
#  * @reason Initialize audit logging, auto-install templates, validate environment
#  * @impact Ensures all multi-agent protocols are active from session start
#  * @version 1.2.0
#  */

set -euo pipefail

# =============================================================================
# CONSTANTS
# =============================================================================

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
PLUGIN_VERSION="1.2.0"
CLAUDE_DIR="${HOME}/.claude"
AUDIT_DIR="${CLAUDE_DIR}/audit"
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%Y%m%d)-$(openssl rand -hex 2)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# =============================================================================
# AUTO-INSTALL: STATUSLINE
# =============================================================================

install_statusline() {
  local src="${PLUGIN_ROOT}/templates/statusline-command.sh"
  local dest="${CLAUDE_DIR}/statusline-command.sh"
  local settings="${CLAUDE_DIR}/settings.json"
  local installed=false
  local updated=false

  # Check if source template exists
  if [ ! -f "$src" ]; then
    return 0  # Template not available, skip silently
  fi

  # Install or update statusline script
  if [ ! -f "$dest" ]; then
    cp "$src" "$dest"
    chmod +x "$dest"
    installed=true
  else
    # Check if update needed (compare checksums)
    local src_hash=$(md5 -q "$src" 2>/dev/null || md5sum "$src" | cut -d' ' -f1)
    local dest_hash=$(md5 -q "$dest" 2>/dev/null || md5sum "$dest" | cut -d' ' -f1)
    if [ "$src_hash" != "$dest_hash" ]; then
      cp "$src" "$dest"
      chmod +x "$dest"
      updated=true
    fi
  fi

  # Configure settings.json if needed
  if [ -f "$settings" ]; then
    # Check if statusline already configured
    if ! grep -q '"statusline"' "$settings" 2>/dev/null; then
      configure_statusline_settings "$settings"
    fi
  else
    # Create minimal settings.json with statusline
    cat > "$settings" << SETTINGS
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "statusline": {
    "command": "bash ${dest}"
  }
}
SETTINGS
    installed=true
  fi

  # Return status for logging
  if [ "$installed" = true ]; then
    echo "installed"
  elif [ "$updated" = true ]; then
    echo "updated"
  else
    echo "ok"
  fi
}

configure_statusline_settings() {
  local settings="$1"
  local dest="${CLAUDE_DIR}/statusline-command.sh"
  
  # Use jq if available for safe JSON manipulation
  if command -v jq &> /dev/null; then
    local tmp=$(mktemp)
    jq --arg cmd "bash ${dest}" '. + {statusline: {command: $cmd}}' "$settings" > "$tmp" && mv "$tmp" "$settings"
  fi
  # If jq not available, skip - user can configure manually
}

# =============================================================================
# AUDIT LOGGING
# =============================================================================

initialize_audit() {
  mkdir -p "$AUDIT_DIR"
  
  local session_log="${AUDIT_DIR}/session_${SESSION_ID}.jsonl"
  
  cat >> "$session_log" << AUDIT
{"event":"session_start","timestamp":"${TIMESTAMP}","session_id":"${SESSION_ID}","plugin":"maos","version":"${PLUGIN_VERSION}"}
AUDIT
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  # Initialize audit logging
  initialize_audit
  
  # Auto-install statusline (silent, non-blocking)
  local statusline_status
  statusline_status=$(install_statusline 2>/dev/null || echo "skip")
  
  # Output to Claude Code
  cat << OUTPUT
{
  "status": "success",
  "message": "MAOS initialized",
  "session_id": "${SESSION_ID}",
  "version": "${PLUGIN_VERSION}",
  "auto_install": {
    "statusline": "${statusline_status}"
  },
  "protocols": {
    "sentinel": "v1.0.0",
    "worktree_policy": "v1.1",
    "anti_conflict": "v3.2",
    "hierarchical_merge": "v1.0"
  },
  "instructions": "Follow Anti-Conflict Protocol phases. Use git worktrees for file modifications. Check tasks.md before editing shared files."
}
OUTPUT
}

main "$@"
exit 0
