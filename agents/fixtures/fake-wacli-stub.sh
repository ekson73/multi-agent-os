#!/usr/bin/env bash
# Deterministic FAKE `wacli` CLI stub for wacli-delegate contract testing.
# NEVER touches a real account, real store, or real network. Synthetic content only.
# Install on PATH ahead of a real `wacli` (if any) when running contract-behavior tests:
#   PATH="$(dirname "$0"):$PATH" wacli --account acct-test doctor
#
# Function     : stand in for the real `wacli` binary with fixed, synthetic answers so the
#                wacli-delegate contract can be exercised without any account, store, or network.
# Spec         : agents/wacli-delegate.md (admission/classification/execute gates) ·
#                tests/test-wacli-delegate-contract.sh (mechanical assertions over this stub).
# Idempotent   : yes — pure function of argv; writes nothing, exit code + stdout/stderr only.
# Portability  : Bash 3.2+ (no associative arrays / mapfile); no external tools required.
# Layer purity : community-clean — one synthetic account (`acct-test`), fake JIDs redacted,
#                no org-specific names, numbers, or credentials.
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

# Expect: wacli --account NAME [--read-only] [--json] <cmd> <rest...>
# `--read-only`/`--json` are documented global options that may appear between `--account NAME`
# and the actual command (see agents/wacli-delegate.md's
# `wacli --account ACCOUNT --read-only --json ...` invocation form) — they must be consumed
# before CMD is determined, or a correctly-formed call misclassifies as UNKNOWN_FAKE_COMMAND.
# json_str: JSON-string escaping for values interpolated into error envelopes. Bash arguments cannot
# carry NUL, but every other C0 control is escaped; backslash and quote are escaped first so generated
# escape sequences remain literal JSON syntax.
json_str() {
  local s="$1" control_code control_char escape_code
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  s="${s//$'\b'/\\b}"; s="${s//$'\f'/\\f}"; s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"
  for control_code in {1..31}; do
    case "$control_code" in 8|9|10|12|13) continue ;; esac
    printf -v escape_code '\\u%04x' "$control_code"
    printf -v control_char "\\$(printf '%03o' "$control_code")"
    s="${s//$control_char/$escape_code}"
  done
  printf '%s' "$s"
}
fail() {
  echo '{"error":"'"$(json_str "$1")"'","detail":"'"$(json_str "${2:-}")"'"}' >&2
  exit 1
}

if [[ "${1:-}" == "--account" ]]; then
  ACCOUNT="${2:-}"; shift 2 || true

  if [[ "$ACCOUNT" != "acct-test" ]]; then
    echo '{"error":"ACCOUNT_NOT_FOUND","account":"'"$(json_str "$ACCOUNT")"'"}' >&2
    exit 1
  fi

  while [[ "${1:-}" == "--read-only" || "${1:-}" == "--json" ]]; do
    shift
  done

  CMD="${1:-}"; shift || true

  case "$CMD" in
    doctor)
      if [[ "${1:-}" == "--help" ]]; then
        echo "wacli doctor --help (fake): reports AUTHENTICATED/CONNECTED/LOCKED/CONNECTION_STATE/MESSAGES/LAST_SYNC. Flags: --connect."
        exit 0
      fi
      if [[ "${1:-}" == "--connect" ]]; then shift; fi
      if [[ $# -gt 0 ]]; then
        fail "UNSUPPORTED_FLAG" "doctor $1"
      fi
      echo '{"AUTHENTICATED":true,"CONNECTED":false,"LOCKED":false,"CONNECTION_STATE":"local_only","MESSAGES":42,"LAST_SYNC":"2026-09-01T12:00:00Z"}'
      ;;
    auth)
      if [[ "${1:-}" == "--help" || "${2:-}" == "--help" ]]; then
        echo "wacli auth --help (fake): subcommands status, logout."
        exit 0
      fi
      case "${1:-}" in
        status)
          shift
          if [[ $# -gt 0 ]]; then
            fail "UNSUPPORTED_FLAG" "auth status $1"
          fi
          echo '{"authenticated":true,"jid":"[REDACTED-FAKE]"}'
          ;;
        *)
          fail "UNKNOWN_FAKE_SUBCOMMAND" "auth ${1:-}"
          ;;
      esac
      ;;
    messages)
      if [[ "${2:-}" == "--help" ]]; then
        echo "wacli messages search --help (fake): flags --query, --after, --before, --json."
        exit 0
      fi
      if [[ "${1:-}" != "search" ]]; then
        fail "UNKNOWN_FAKE_SUBCOMMAND" "messages ${1:-}"
      fi
      shift || true
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --query|--after|--before)
            [[ $# -ge 2 ]] || fail "MALFORMED_FLAG" "$1 requires a value"
            shift 2
            ;;
          --json)
            shift
            ;;
          *)
            fail "UNSUPPORTED_FLAG" "messages search $1"
            ;;
        esac
      done
      # deterministic fixture: exactly 2 fake matches, synthetic content only
      echo '{"matches":[{"id":"fake-msg-1","timestamp":"2026-08-15T10:22:00Z","snippet":"[fake] release date decision noted"},{"id":"fake-msg-2","timestamp":"2026-08-16T09:05:00Z","snippet":"[fake] release date confirmed"}],"count":2}'
      ;;
    send)
      if [[ "${2:-}" == "--help" ]]; then
        echo "wacli send text --help (fake): flags --to, --text."
        exit 0
      fi
      if [[ "${1:-}" != "text" ]]; then
        fail "UNKNOWN_FAKE_SUBCOMMAND" "send ${1:-}"
      fi
      # Always refuses: exercises the "approved plan reaches the backend but the backend
      # itself fails" path (status=error/UPSTREAM_ERROR), never a fabricated send success.
      echo '{"error":"REFUSED_BY_FAKE_STUB","message":"fake stub never sends; this call should never happen in a dry-run/plan test"}' >&2
      exit 1
      ;;
    *)
      echo '{"error":"UNKNOWN_FAKE_COMMAND","cmd":"'"$(json_str "$CMD")"'"}' >&2
      exit 1
      ;;
  esac
  exit 0
fi

echo '{"error":"UNHANDLED_FAKE_ARGS"}' >&2
exit 1
