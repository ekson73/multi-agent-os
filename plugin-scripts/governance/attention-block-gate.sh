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
#   2. any warning verdict of bin/attention-block-lint (see its WARN set) → inject
#      additionalContext ONCE per Stop cycle so the
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
set -euo pipefail

# Shared governance scaffold (AGENTS.md hook convention). Sourcing failure must not
# break a turn: this is an advisory Stop hook, so degrade to the pre-gate baseline.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/lib"
# shellcheck source=/dev/null
source "${LIB_DIR}/common.sh" 2>/dev/null || exit 0
# shellcheck source=/dev/null
source "${LIB_DIR}/json-rpc.sh" 2>/dev/null || exit 0

[ "${MAOS_ATTENTION_GATE:-1}" = "0" ] && exit 0
[ -n "${HOME-}" ] || exit 0

# Ledger FIRST, before any dependency check, so every invocation — including the
# dependency-missing skips — leaves a row (a silent skip is indistinguishable from a
# healthy quiet turn otherwise). printf only: jq may be the missing dependency.
STATE_DIR="${MAOS_ATTENTION_STATE_DIR:-$HOME/.claude/state/attention-block-gate}"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
LEDGER="$STATE_DIR/ledger.jsonl"
log() { # verdict fired note
  printf '{"t":"%s","verdict":"%s","fired":%s,"note":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$3" >>"$LEDGER" 2>/dev/null || true
}

command -v jq >/dev/null 2>&1 || { log "skipped" false "jq_missing"; exit 0; }
command -v python3 >/dev/null 2>&1 || { log "skipped" false "python3_missing"; exit 0; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
LINT="$SCRIPT_DIR/../../bin/attention-block-lint"
[ -x "$LINT" ] || LINT="$(command -v attention-block-lint 2>/dev/null || true)"
{ [ -n "$LINT" ] && [ -x "$LINT" ]; } || { log "skipped" false "lint_missing"; exit 0; }

payload="$(cat 2>/dev/null || true)"
msg="$(printf '%s' "$payload" | jq -r '.last_assistant_message // ""' 2>/dev/null || true)"
sid="$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null || true)"
pid="$(printf '%s' "$payload" | jq -r '.prompt_id  // ""' 2>/dev/null || true)"
cont="$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"

[ -n "$msg" ] || { log "empty_message" false ""; exit 0; }

result="$(printf '%s' "$msg" | "$LINT" --json 2>/dev/null || true)"
verdict="$(printf '%s' "$result" | jq -r '.verdict // "lint_error"' 2>/dev/null || echo lint_error)"
items="$(printf '%s' "$result" | jq -r '.items // 0' 2>/dev/null || echo 0)"
reds="$(printf '%s' "$result" | jq -r '.red_items // 0' 2>/dev/null || echo 0)"
case "$items$reds" in *[!0-9]*|'') items=0; reds=0 ;; esac

action=""
case "$verdict" in
  missing_block|inconsistent_clear_with_asks|empty_attention_block|block_not_last|over_cap|malformed_item|dependency_unexplained|misnumbered_items|header_count_mismatch) action="inject" ;;
  ok) if [ "$items" -gt 0 ]; then action="notify"; fi ;;
esac
[ -n "$action" ] || { log "$verdict" false ""; exit 0; }

safe_id() { case "$1" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac; [ "${#1}" -le 128 ]; }
safe_id "$sid" || { log "$verdict" false "unsafe_session_id"; exit 0; }

# Dedup key. The harness omits prompt_id intermittently (~35% of real Stop events,
# measured by the sibling question-batch-gate), so a prompt_id-only guard would
# silently miss a third of turns. Fallback: bind to the Stop cycle (see below).
# Loop-safety without prompt_id: never INJECT when this Stop is already a hook-driven
# continuation (stop_hook_active=true) — the one reminder already happened.
if safe_id "$pid"; then
  key="p${#pid}.${pid}"
else
  # No prompt_id: the only reliable Stop-cycle boundary the harness provides is
  # stop_hook_active (false on the first Stop of a cycle, true on a hook-driven
  # continuation). Act on the first Stop, never on a continuation. No persistent
  # marker: a message-digest key would wrongly suppress a LATER turn that repeats
  # the same text (bot review, PR #463 rounds 2-3).
  if [ "$cont" = "true" ]; then log "$verdict" false "continuation_no_prompt_id"; exit 0; fi
  key=""
fi

if [ -n "$key" ]; then
  marker="$STATE_DIR/${#sid}.${sid}.${key}.${action}.marker.d"
  if ! mkdir "$marker" 2>/dev/null; then
    if [ -d "$marker" ]; then log "$verdict" false "idempotent"; else log "$verdict" false "marker_claim_failed"; fi
    exit 0
  fi
fi
find "$STATE_DIR" -maxdepth 1 -type d -name '*.marker.d' -mtime +7 -exec rm -rf {} + 2>/dev/null || true

if [ "$action" = "notify" ]; then
  if [ "${MAOS_ATTENTION_NOTIFY:-1}" = "0" ]; then log "$verdict" false "notify_disabled"; exit 0; fi
  if [ "$(uname -s 2>/dev/null || true)" != "Darwin" ]; then log "$verdict" false "notify_unsupported_os"; exit 0; fi
  log "$verdict" true "notify"
  title="🔔 ${items} item(ns) precisam de você"
  if [ "$reds" -gt 0 ]; then title="🛑 ${items} item(ns) precisam de você (${reds} bloqueante)"; fi
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

If an item depends on another artifact (a PR, a ticket), add a line \`> ⏳ #N — <owner>: <state> · <what the human must do, or "nada a fazer por você">\` so the dependency is never invisible.

Rules: blank line before it, NO \`---\` above it · it is the LAST thing in the message (no prose after it) · ≤3 items · reply tokens prefixed with the item number · shape AND word, never color alone (🛑 blocking/security · 🔶 decision · ✋ manual). If after self-answering nothing actually needs him, replace it with the bare line: > **✅ NADA PRECISA DE VOCÊ**

(Advisory only — nothing is blocked. Heuristic detection. One injection per prompt. Disable: MAOS_ATTENTION_GATE=0.)
EOF

jq -cn --arg ctx "$advice" '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:$ctx}}' 2>/dev/null || true
exit 0
