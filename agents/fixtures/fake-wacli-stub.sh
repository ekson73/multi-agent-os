#!/usr/bin/env bash
# Deterministic FAKE `wacli` CLI stub for wacli-delegate contract testing.
# NEVER touches a real account, real store, or real network. Synthetic content only.
# Install on PATH ahead of a real `wacli` (if any) when running contract-behavior tests:
#   PATH="$(dirname "$0"):$PATH" wacli --account acct-test doctor
set -euo pipefail

if [[ "${1:-}" == "--version" ]]; then
  echo "wacli 0.18.1-fake-test-stub"
  exit 0
fi

if [[ "${1:-}" == "--help" ]]; then
  echo "fake-wacli test stub: supports accounts, doctor, auth status, messages search, send text (refuses)"
  exit 0
fi

if [[ "${1:-}" == "accounts" && "${2:-}" == "list" ]]; then
  echo '[{"name":"acct-test","kind":"personal"}]'
  exit 0
fi

# Expect: wacli --account NAME <rest...>
if [[ "${1:-}" == "--account" ]]; then
  ACCOUNT="$2"; shift 2
  CMD="${1:-}"; shift || true

  if [[ "$ACCOUNT" != "acct-test" ]]; then
    echo '{"error":"ACCOUNT_NOT_FOUND","account":"'"$ACCOUNT"'"}' >&2
    exit 1
  fi

  case "$CMD" in
    doctor)
      if [[ "${1:-}" == "--help" ]]; then
        echo "wacli doctor --help (fake): reports AUTHENTICATED/CONNECTED/LOCKED/CONNECTION_STATE/MESSAGES/LAST_SYNC. Flags: --connect."
        exit 0
      fi
      echo '{"AUTHENTICATED":true,"CONNECTED":false,"LOCKED":false,"CONNECTION_STATE":"local_only","MESSAGES":42,"LAST_SYNC":"2026-09-01T12:00:00Z"}'
      ;;
    auth)
      if [[ "${1:-}" == "--help" || "${2:-}" == "--help" ]]; then
        echo "wacli auth --help (fake): subcommands status, logout."
        exit 0
      fi
      if [[ "${1:-}" == "status" ]]; then
        echo '{"authenticated":true,"jid":"[REDACTED-FAKE]"}'
      fi
      ;;
    messages)
      if [[ "${2:-}" == "--help" ]]; then
        echo "wacli messages search --help (fake): flags --query, --after, --before, --json."
        exit 0
      fi
      if [[ "${1:-}" == "search" ]]; then
        # deterministic fixture: exactly 2 fake matches, synthetic content only
        echo '{"matches":[{"id":"fake-msg-1","timestamp":"2026-08-15T10:22:00Z","snippet":"[fake] release date decision noted"},{"id":"fake-msg-2","timestamp":"2026-08-16T09:05:00Z","snippet":"[fake] release date confirmed"}],"count":2}'
      fi
      ;;
    send)
      if [[ "${2:-}" == "--help" ]]; then
        echo "wacli send text --help (fake): flags --to, --text."
        exit 0
      fi
      # Always refuses: exercises the "approved plan reaches the backend but the backend
      # itself fails" path (status=error/UPSTREAM_ERROR), never a fabricated send success.
      echo '{"error":"REFUSED_BY_FAKE_STUB","message":"fake stub never sends; this call should never happen in a dry-run/plan test"}' >&2
      exit 1
      ;;
    *)
      echo '{"error":"UNKNOWN_FAKE_COMMAND","cmd":"'"$CMD"'"}' >&2
      exit 1
      ;;
  esac
  exit 0
fi

echo '{"error":"UNHANDLED_FAKE_ARGS"}' >&2
exit 1
