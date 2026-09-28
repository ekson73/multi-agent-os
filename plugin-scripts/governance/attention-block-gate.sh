#!/usr/bin/env bash
# attention-block-gate v1.0.0 (UX-reviewed shapes 🛑🔶✋) — Stop hook for the Pharos operator-attention block.
#
# WHY: operators miss the approvals / decisions / GO requests an agent buries in
#   the middle of a long answer ("agulha no palheiro"). The convention
#   (skills/operator-attention-block/SKILL.md) puts every such item in ONE fixed
#   block as the last thing on screen. A convention an amnesic agent forgets is
#   not a mechanism, so this hook checks every turn with bin/attention-block-lint.
#
# WHAT it does, per turn:
#   1. Lints `last_assistant_message`.
#   2. verdict in {missing_block, inconsistent_clear_with_asks, empty_attention_block,
#      block_not_last, over_cap} → inject additionalContext ONCE per prompt so the
#      agent restates the asks in the block before stopping.
#   3. verdict ok + block has items → desktop notification (macOS), once per prompt,
#      so an operator away from the terminal knows something waits for them.
#
# SAFETY (same contract as question-batch-gate):
#   * Never blocks: always exit 0, never exit 2.
#   * Loop-safe: one-shot per prompt_id via ATOMIC mkdir; no marker ⇒ no injection.
#   * Fail-safe: missing python3/jq/lint, bad payload, unset HOME ⇒ exit 0 silently.
#   * Path-safe: session_id/prompt_id are untrusted; strict allowlist + length bound.
#   * Measurable: every invocation appends to ledger.jsonl (skips included).
#   * Kill-switches: MAOS_ATTENTION_GATE=0 (whole hook) · MAOS_ATTENTION_NOTIFY=0 (notify only).
set -uo pipefail 2>/dev/null || true

[ "${MAOS_ATTENTION_GATE:-1}" = "0" ] && exit 0
[ -n "${HOME-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
LINT="$SCRIPT_DIR/../../bin/attention-block-lint"
[ -x "$LINT" ] || LINT="$(command -v attention-block-lint 2>/dev/null || true)"
[ -n "$LINT" ] && [ -x "$LINT" ] || exit 0

STATE_DIR="${MAOS_ATTENTION_STATE_DIR:-$HOME/.claude/state/attention-block-gate}"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
LEDGER="$STATE_DIR/ledger.jsonl"

payload="$(cat 2>/dev/null)" || exit 0
msg="$(printf '%s' "$payload" | jq -r '.last_assistant_message // ""' 2>/dev/null)" || exit 0
sid="$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)" || sid=""
pid="$(printf '%s' "$payload" | jq -r '.prompt_id  // ""' 2>/dev/null)" || pid=""

log() { # verdict fired note
  printf '{"t":"%s","verdict":"%s","fired":%s,"note":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$3" >>"$LEDGER" 2>/dev/null || true
}

[ -n "$msg" ] || { log "empty_message" false ""; exit 0; }

result="$(printf '%s' "$msg" | "$LINT" --json 2>/dev/null)" || true
verdict="$(printf '%s' "$result" | jq -r '.verdict // "lint_error"' 2>/dev/null)" || verdict="lint_error"
items="$(printf '%s' "$result" | jq -r '.items // 0' 2>/dev/null)" || items=0
reds="$(printf '%s' "$result" | jq -r '.red_items // 0' 2>/dev/null)" || reds=0
case "$items$reds" in *[!0-9]*) items=0; reds=0 ;; esac

action=""
case "$verdict" in
  missing_block|inconsistent_clear_with_asks|empty_attention_block|block_not_last|over_cap) action="inject" ;;
  ok) [ "$items" -gt 0 ] && action="notify" ;;
esac
[ -n "$action" ] || { log "$verdict" false ""; exit 0; }

safe_id() { case "$1" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac; [ "${#1}" -le 128 ]; }
safe_id "$pid" || { log "$verdict" false "unsafe_or_absent_prompt_id"; exit 0; }
safe_id "$sid" || { log "$verdict" false "unsafe_session_id"; exit 0; }

marker="$STATE_DIR/${#sid}.${sid}.${#pid}.${pid}.${action}.marker.d"
if ! mkdir "$marker" 2>/dev/null; then
  if [ -d "$marker" ]; then log "$verdict" false "idempotent"; else log "$verdict" false "marker_claim_failed"; fi
  exit 0
fi
find "$STATE_DIR" -maxdepth 1 -type d -name '*.marker.d' -mtime +7 -exec rm -rf {} + 2>/dev/null || true

if [ "$action" = "notify" ]; then
  log "$verdict" true "notify"
  [ "${MAOS_ATTENTION_NOTIFY:-1}" = "0" ] && exit 0
  [ "$(uname -s 2>/dev/null)" = "Darwin" ] || exit 0
  title="🔔 ${items} item(ns) precisam de você"
  [ "$reds" -gt 0 ] && title="🔴 ${items} item(ns) precisam de você (${reds} bloqueante)"
  body="Veja o bloco no fim da resposta do agente."
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "Agente" -subtitle "$title" -message "$body" -sound default >/dev/null 2>&1 &
  else
    osascript -e "display notification \"$body\" with title \"Agente\" subtitle \"$title\" sound name \"Glass\"" >/dev/null 2>&1 &
  fi
  exit 0
fi

log "$verdict" true "inject"
read -r -d '' advice <<EOF || true
🔔 attention-block-gate (Pharos): verdict=${verdict}.

This turn asks the operator for something (approval · decision · answer · manual step) without surfacing it in the fixed attention block, so he will likely miss it. Before stopping, END your message with the block (skills/operator-attention-block/SKILL.md):

> **🔔 PRECISA DE VOCÊ (N)**
> 1. **🛑 AUTORIZAR** — <what, 1 line> · responda \`1 sim\` / \`1 não\`
> 2. **🔶 DECIDIR** — <what> · \`2A\` <option> (recomendado) · \`2B\` <option>
> 3. **✋ AÇÃO MANUAL** — <what the human must do by hand>
> ➕ +N registrados em <backlog> (não precisam de você agora)   ← only if >3

Rules: blank line before it, NO \`---\` above it · it is the LAST thing in the message (no prose after it) · ≤3 items · reply tokens prefixed with the item number · shape AND word, never color alone (🛑 blocking/security · 🔶 decision · ✋ manual). If after self-answering nothing actually needs him, replace it with the bare line: > **✅ NADA PRECISA DE VOCÊ**

(Advisory only — nothing is blocked. Heuristic detection. One injection per prompt. Disable: MAOS_ATTENTION_GATE=0.)
EOF

jq -cn --arg ctx "$advice" '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:$ctx}}' 2>/dev/null || true
exit 0
