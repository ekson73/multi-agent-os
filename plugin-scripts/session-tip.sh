#!/usr/bin/env bash
# /**
#  * MAOS-Tips — session-start discoverability nudge (RULE: MAOS-Tips v1)
#  * @context ~116 MAOS agentic-tools (63 skills + 25 cmds + 28 agents) are hard to
#  *   discover. This hook surfaces ONE curated tip about a maos tool at session start
#  *   (startup/clear only) so the operator/community learns what exists + when to use it.
#  * @reason Discoverability. Native companyAnnouncements is org-server-side (not plugin-
#  *   writable); the hook channel is the community-portable substitute. Depth is the
#  *   concierge's job — a tip is a 1-line PUSH nudge + route (DRY).
#  * @impact Additive, advisory, never blocks (always exit 0). Degrades to no-op if tips/
#  *   or jq is absent. Silenceable (MAOS_TIPS=off / MAOS_NO_TIPS=1 / ~/.claude/.maos-no-tips).
#  * @security Catalog = static strings + boolean/count signals ONLY. Never reads file
#  *   contents, ticket bodies, or PII. --emit-announcements is print-only (operator pastes;
#  *   the plugin NEVER writes settings.json/companyAnnouncements — HUMAN_DOMAIN).
#  * @modes (default) SessionStart hook · --print · --emit-announcements [N] · --family <f>
#  */
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$SCRIPT_DIR")}"
CATALOG="${PLUGIN_ROOT}/tips/catalog.json"

# Reuse governance lib helpers when present (json_escape, log_audit, EXIT_SUCCESS);
# session-tip is a session-lifecycle hook (top-level), not governance, so it sources
# the shared lib from governance/lib rather than living under governance/.
LIB="${SCRIPT_DIR}/governance/lib/common.sh"
# shellcheck source=/dev/null
[ -f "$LIB" ] && source "$LIB" 2>/dev/null || true
EXIT_OK="${EXIT_SUCCESS:-0}"

# --- fallbacks if the lib is unavailable (never hard-depend) -------------------
if ! declare -f json_escape >/dev/null 2>&1; then
  json_escape() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/}"; s="${s//$'\t'/\\t}"; printf '%s' "$s"; }
fi
if ! declare -f log_audit >/dev/null 2>&1; then
  log_audit() { :; }
fi

STATE_DIR="${HOME:-/tmp}/.claude/maos"
STATE="${STATE_DIR}/tips-state.json"
DEFAULT_STATE='{"last_session_id":"","seen":[],"last_shown_ts":0}'

# --- opt-out (any of three) ---------------------------------------------------
_tips_off() {
  [ "${MAOS_TIPS:-}" = "off" ] && return 0
  [ "${MAOS_NO_TIPS:-0}" = "1" ] && return 0
  [ -n "${HOME:-}" ] && [ -f "${HOME}/.claude/.maos-no-tips" ] && return 0
  return 1
}

# --- ready = jq + a valid catalog present (else silent no-op) ------------------
_ready() {
  command -v jq >/dev/null 2>&1 || return 1
  [ -f "$CATALOG" ] || return 1
  jq empty "$CATALOG" >/dev/null 2>&1 || return 1
  return 0
}

# --- state (JSON; symlink-guarded atomic write, mirrors auto-name-session.sh) --
read_state() {
  if [ -L "$STATE" ]; then printf '%s' "$DEFAULT_STATE"; return; fi
  if [ -f "$STATE" ] && jq empty "$STATE" >/dev/null 2>&1; then cat "$STATE"; else printf '%s' "$DEFAULT_STATE"; fi
}
write_state() {  # $1 = json
  [ -n "${HOME:-}" ] || return 0
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  [ -L "$STATE" ] && return 0   # refuse to follow a symlink
  local tmp; tmp="$(mktemp "${STATE_DIR}/.tips-state.XXXXXX" 2>/dev/null)" || return 0
  if printf '%s\n' "$1" > "$tmp" 2>/dev/null; then
    [ -L "$STATE" ] && { rm -f "$tmp"; return 0; }
    mv "$tmp" "$STATE" 2>/dev/null || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
}

# --- render helpers (route = the family's concierge) --------------------------
render_human() {  # $1 = id
  jq -r --arg id "$1" '
    .families as $fam
    | (.tips[] | select(.id==$id)) as $t
    | ($fam[$t.family].route // $fam._default.route) as $r
    | "💡 MAOS Tip · \($t.tool): \($t.text) Try: \($t.invocation)  ·  more: /maos:\($r)"
  ' "$CATALOG"
}
render_agent() {  # $1 = id
  jq -r --arg id "$1" '
    .families as $fam
    | (.tips[] | select(.id==$id)) as $t
    | ($fam[$t.family].route // $fam._default.route) as $r
    | "MAOS-Tip surfaced: \($t.tool) (\($t.family)) — \($t.text) If the current work matches, route to \($t.invocation) or /maos:\($r)."
  ' "$CATALOG"
}

# --- arg parse (mode select happens BEFORE any stdin read) --------------------
MODE="hook"; FAMILY=""; N=10
while [ $# -gt 0 ]; do
  case "$1" in
    --print)                MODE="print" ;;
    --emit-announcements)   MODE="announce"
                            case "${2:-}" in ''|*[!0-9]*) ;; *) N="$2"; shift ;; esac ;;
    --emit-announcements=*) MODE="announce"; v="${1#*=}"; case "$v" in ''|*[!0-9]*) ;; *) N="$v" ;; esac ;;
    --family)               FAMILY="${2:-}"; shift ;;
    --family=*)             FAMILY="${1#*=}" ;;
    *) ;;
  esac
  shift
done

_tips_off && exit "$EXIT_OK"
_ready    || exit "$EXIT_OK"

# --- MODE: emit-announcements (print-only; operator pastes into settings) ------
if [ "$MODE" = "announce" ]; then
  jq --argjson n "$N" '[ .tips[] | "💡 MAOS Tip · \(.tool): \(.text) (try \(.invocation))" ] | .[0:$n]' "$CATALOG"
  cat >&2 <<'EOF'

# ^ Paste the JSON array above to replicate the native "Message from <org>:" startup
#   banner. The plugin NEVER writes these for you (settings = HUMAN_DOMAIN). You apply:
#   • Solo / this machine  → ~/.claude/settings.json  →  "companyAnnouncements": [ ...array... ]
#   • Org-wide (real "Message from <org>:" bar) → your Anthropic Console managed-settings policy.
EOF
  exit "$EXIT_OK"
fi

# --- MODE: print (on-demand /maos:tip — random, family-filterable, non-mutating)
if [ "$MODE" = "print" ]; then
  ID="$(jq -r --arg fam "$FAMILY" '[.tips[] | select(($fam=="") or (.family==$fam)) | .id] | .[]' "$CATALOG" \
        | awk 'BEGIN{srand()} {a[NR]=$0} END{if(NR>0) print a[int(rand()*NR)+1]}')"
  if [ -z "$ID" ]; then echo "No MAOS tips found${FAMILY:+ for family '$FAMILY'}." >&2; exit "$EXIT_OK"; fi
  render_human "$ID"
  exit "$EXIT_OK"
fi

# --- MODE: hook (default) -----------------------------------------------------
INPUT="$(cat 2>/dev/null || printf '{}')"
SRC="$(printf '%s' "$INPUT" | jq -r '.source // "startup"' 2>/dev/null || printf 'startup')"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""'   2>/dev/null || printf '')"

# Only fire on a genuinely new/cleared session — skip resume & compact (context
# is already warm; a tip there is noise). CI never gets a tip.
case "$SRC" in startup|clear) ;; *) exit "$EXIT_OK" ;; esac
[ "${CI:-}" = "true" ] && exit "$EXIT_OK"

ST="$(read_state)"
LAST_SID="$(printf '%s' "$ST" | jq -r '.last_session_id // ""' 2>/dev/null || printf '')"
# Idempotency: if SessionStart double-fires for the same session_id, tip only once.
[ -n "$SID" ] && [ "$SID" = "$LAST_SID" ] && exit "$EXIT_OK"

# Optional throttle: MAOS_TIPS_EVERY=Nd → at most one tip per N days.
EVERY="${MAOS_TIPS_EVERY:-}"
if printf '%s' "$EVERY" | grep -qE '^[0-9]+d$'; then
  DAYS="${EVERY%d}"
  LAST_TS="$(printf '%s' "$ST" | jq -r '.last_shown_ts // 0' 2>/dev/null || printf '0')"
  NOW="$(date +%s)"; MIN=$(( DAYS * 86400 ))
  if [ "$LAST_TS" -gt 0 ] 2>/dev/null && [ $(( NOW - LAST_TS )) -lt "$MIN" ]; then exit "$EXIT_OK"; fi
fi

# Select: rotation with no-repeat. eligible = all ids − seen; empty ⇒ recycle.
SEEN="$(printf '%s' "$ST" | jq -c '.seen // []' 2>/dev/null || printf '[]')"
ELIG="$(jq -r --argjson seen "$SEEN" '[.tips[].id] - $seen | .[]' "$CATALOG" 2>/dev/null || printf '')"
if [ -z "$ELIG" ]; then
  ID="$(jq -r '.tips[0].id' "$CATALOG")"
  NEW_SEEN="$(jq -cn --arg id "$ID" '[$id]')"
else
  ID="$(printf '%s' "$ELIG" | head -1)"
  NEW_SEEN="$(printf '%s' "$ST" | jq -c --arg id "$ID" '(.seen // []) + [$id]')"
fi
[ -n "$ID" ] || exit "$EXIT_OK"

HUMAN="$(render_human "$ID")"
AGENT="$(render_agent "$ID")"

printf '\n%s\n' "$HUMAN" >&2
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$(json_escape "$AGENT")"
log_audit "maos_tip_surfaced" "$(printf '{"tip":"%s","session":"%s"}' "$(json_escape "$ID")" "$(json_escape "$SID")")" 2>/dev/null || true

NEW_STATE="$(jq -cn --arg sid "$SID" --argjson seen "$NEW_SEEN" --argjson ts "$(date +%s)" \
  '{last_session_id:$sid, seen:$seen, last_shown_ts:$ts}')"
write_state "$NEW_STATE"

exit "$EXIT_OK"
