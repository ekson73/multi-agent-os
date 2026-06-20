#!/usr/bin/env bash
# /**
#  * Session Start Hook - MAOS (Multi-Agent OS)
#  * @context Claude Code plugin hook - executes at session initialization
#  * @reason Initialize audit logging, install statusline capability, validate environment
#  * @impact Multi-agent protocols active from session start. Statusline wiring is
#  *         OPT-IN + never-overwrite (good-neighbor): the default only SUGGESTS the
#  *         capability, respecting the operator's freedom to choose their own status
#  *         line. Writes the canonical camelCase "statusLine" key with a "type" field
#  *         (lowercase "statusline" is silently ignored by Claude Code).
#  * @version 1.14.0
#  */

set -euo pipefail

# =============================================================================
# CONSTANTS
# =============================================================================

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
PLUGIN_VERSION="1.15.0"
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

  # --- Operator-freedom gate (good-neighbor: opt-in, never impose) -------------
  # OFF: explicit opt-out -> touch nothing at all.
  if [ "${MAOS_STATUSLINE:-}" = "off" ] || [ -f "${CLAUDE_DIR}/.maos-no-statusline" ]; then
    echo "off"; return 0
  fi

  # Template must be available.
  if [ ! -f "$src" ]; then
    echo "skip"; return 0
  fi

  # Install/update the renderer SCRIPT only (a file in ~/.claude; NOT a config
  # mutation -> harmless, keeps the capability ready if the operator opts in).
  if [ ! -f "$dest" ]; then
    cp "$src" "$dest"; chmod +x "$dest"
  else
    local src_hash dest_hash
    src_hash=$(md5 -q "$src" 2>/dev/null || md5sum "$src" | cut -d' ' -f1)
    dest_hash=$(md5 -q "$dest" 2>/dev/null || md5sum "$dest" | cut -d' ' -f1)
    if [ "$src_hash" != "$dest_hash" ]; then cp "$src" "$dest"; chmod +x "$dest"; fi
  fi

  # AUTO: only WIRE settings.json when the operator explicitly opted in.
  if [ "${MAOS_STATUSLINE:-}" = "auto" ] || [ -f "${CLAUDE_DIR}/.maos-statusline-optin" ]; then
    configure_statusline_settings "$settings" "$dest"
    return 0
  fi

  # DEFAULT (suggest): never mutate the operator's settings.json. Signal a hint
  # so main() can OFFER the capability without imposing it.
  echo "suggest"
}

# Opt-in writer. Uses the CANONICAL camelCase "statusLine" key WITH a "type"
# field (lowercase "statusline" is silently ignored by Claude Code). NEVER
# overwrites an existing functional statusLine; self-heals legacy lowercase cruft.
configure_statusline_settings() {
  local settings="$1"
  local dest="$2"

  if ! command -v jq >/dev/null 2>&1; then
    echo "manual"; return 0   # no jq -> let the operator configure manually
  fi

  # Fresh settings.json -> create with the correct key.
  if [ ! -f "$settings" ]; then
    cat > "$settings" << SETTINGS
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "statusLine": {
    "type": "command",
    "command": "bash \"${dest}\""
  }
}
SETTINGS
    echo "installed"; return 0
  fi

  # Respect an existing, functional statusLine (camelCase object) -> never overwrite.
  local kind
  kind=$(jq -r '
    if   (.statusLine | type) == "object" then "camel"
    elif (.statusline | type) == "object" then "lower"
    else "none" end' "$settings" 2>/dev/null || echo "err")
  case "$kind" in
    camel) echo "exists"; return 0 ;;   # operator already has one -> leave it alone
    err)   echo "skip";   return 0 ;;   # unreadable -> do not risk a write
  esac

  # kind = none | lower -> write canonical camelCase, dropping non-functional
  # lowercase cruft if present.
  cp "$settings" "${settings}.bak"
  local tmp
  tmp=$(mktemp)
  if jq --arg cmd "bash \"${dest}\"" \
        'del(.statusline) | .statusLine = {type: "command", command: $cmd}' \
        "$settings" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
    mv "$tmp" "$settings"; echo "configured"
  else
    rm -f "$tmp"; echo "skip"
  fi
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
  
  # Install statusline capability (opt-in wiring; never imposes -- good-neighbor)
  local statusline_status statusline_hint=""
  statusline_status=$(install_statusline 2>/dev/null || echo "skip")
  if [ "$statusline_status" = "suggest" ]; then
    statusline_hint="MAOS enriched statusline available (context meter, cost, git). To enable: export MAOS_STATUSLINE=auto (or: touch ~/.claude/.maos-statusline-optin), then start a new session. To silence: export MAOS_STATUSLINE=off."
  fi

  # Output to Claude Code
  cat << OUTPUT
{
  "status": "success",
  "message": "MAOS initialized",
  "session_id": "${SESSION_ID}",
  "version": "${PLUGIN_VERSION}",
  "auto_install": {
    "statusline": "${statusline_status}",
    "statusline_hint": "${statusline_hint}"
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
