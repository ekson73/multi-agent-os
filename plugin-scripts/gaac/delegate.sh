#!/usr/bin/env bash
# /**
#  * Delegate Governance CLI (GaaS/GaaC)
#  * @context Cross-provider delegation prompt emitter
#  * @reason Stop agents re-deciding "gh vs acli vs maos-mcp-hub" per call
#  * @impact Delegator/delegated agents consume a single invokable surface
#  *
#  * PROV: https://github.com/ekson73/multi-agent-os/blob/main/plugin-scripts/gaac/delegate.sh
#  * Version: 1.0.0 | Created: 2026-04-18
#  * Protocol: protocols/delegation/{provider-matrix,delegation-*-prompt}.md
#  */

set -euo pipefail

# Resolve plugin root (mirrors plugin-scripts/pre-delegate.sh pattern)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
PROTOCOL_DIR="${PLUGIN_ROOT}/protocols/delegation"

# ----------------------------------------------------------------------------
# Usage
# ----------------------------------------------------------------------------
usage() {
  cat >&2 <<'EOF'
Usage: delegate.sh <phase> [--ticket KEY] [--provider auto|jira|linear|github|bitbucket|gitlab]

Phases:
  init      Emit the pre-delegation prompt (for delegator to pass to sub-agent).
  dna       Emit the mid-flight guardrails prompt (context refresh).
  finalize  Emit the cleanup + handoff + learning prompt (post-delegation).

Flags:
  --ticket KEY     Override ticket id (else env TICKET; else none).
  --provider P     Override VCS provider detection (else auto from git remote).

Env:
  CLAUDE_PLUGIN_ROOT  Path to plugin root. Defaults to two dirs above this script.
  TICKET              Fallback for --ticket.

Examples:
  plugin-scripts/gaac/delegate.sh init --ticket=VKS-1706
  plugin-scripts/gaac/delegate.sh dna
  plugin-scripts/gaac/delegate.sh finalize --provider=github
EOF
}

# ----------------------------------------------------------------------------
# Arg parsing
# ----------------------------------------------------------------------------
PHASE="${1:-}"
if [[ -z "$PHASE" ]]; then
  usage
  exit 2
fi
case "$PHASE" in
  init|dna|finalize) shift ;;
  -h|--help|help) usage; exit 0 ;;
  *) echo "error: unknown phase '$PHASE' (expected init|dna|finalize)" >&2; usage; exit 2 ;;
esac

TICKET="${TICKET:-}"
PROVIDER_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ticket) TICKET="${2:-}"; shift 2 ;;
    --ticket=*) TICKET="${1#--ticket=}"; shift ;;
    --provider) PROVIDER_OVERRIDE="${2:-}"; shift 2 ;;
    --provider=*) PROVIDER_OVERRIDE="${1#--provider=}"; shift ;;
    *) echo "error: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

# ----------------------------------------------------------------------------
# Provider detection (deterministic — no guessing)
# ----------------------------------------------------------------------------

# Ticket provider from key prefix
TICKET_PROVIDER="auto"
case "${TICKET}" in
  VKS-*|VKS_*) TICKET_PROVIDER="jira" ;;
  VKO-*|EKO-*) TICKET_PROVIDER="linear" ;;
  "") TICKET_PROVIDER="none" ;;
  *) TICKET_PROVIDER="auto" ;;
esac

# VCS provider from git remote, or from override flag
if [[ -n "$PROVIDER_OVERRIDE" ]]; then
  VCS_PROVIDER="$PROVIDER_OVERRIDE"
else
  REMOTE_URL="$(git config --get remote.origin.url 2>/dev/null || echo '')"
  case "$REMOTE_URL" in
    *bitbucket.org*) VCS_PROVIDER="bitbucket" ;;
    *github.com*) VCS_PROVIDER="github" ;;
    *gitlab.com*) VCS_PROVIDER="gitlab" ;;
    *) VCS_PROVIDER="none" ;;
  esac
fi

WORKTREE_PATH="$(git rev-parse --show-toplevel 2>/dev/null || echo 'main — RO only')"

# Short agent-hex for this delegation (random 4 hex chars; non-cryptographic is fine for id)
AGENT_HEX="$(
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import secrets; print(secrets.token_hex(2))"
  else
    head -c 4 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' | head -c 4
  fi
)"

# ----------------------------------------------------------------------------
# Emit dynamic header + prompt body
# ----------------------------------------------------------------------------
PROMPT_FILE="${PROTOCOL_DIR}/delegation-${PHASE}-prompt.md"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "error: prompt file not found: $PROMPT_FILE" >&2
  echo "hint: check protocols/delegation/ in plugin root ($PLUGIN_ROOT)" >&2
  exit 3
fi

# Dynamic header — delegated agent echoes this first line back
cat <<EOF
## Delegation Context (GaaS/GaaC — phase: ${PHASE})

TICKET=${TICKET:-(none — ad-hoc)} TICKET_PROVIDER=${TICKET_PROVIDER} VCS_PROVIDER=${VCS_PROVIDER} WORKTREE=${WORKTREE_PATH} AGENT_HEX=${AGENT_HEX} PARENT_SESSION=${CLAUDE_SESSION_ID:-unknown}

Matrix reference: protocols/delegation/provider-matrix.md
Full prompt follows below.

---

EOF

cat "$PROMPT_FILE"
