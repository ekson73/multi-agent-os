#!/usr/bin/env bash
# Tests for plugin-scripts/governance/attention-block-gate.sh (Pharos Stop hook).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/plugin-scripts/governance/attention-block-gate.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export MAOS_ATTENTION_STATE_DIR="$TMP/state" MAOS_ATTENTION_NOTIFY=0
pass=0; fail=0
run() { jq -cn --arg m "$1" --arg p "$2" '{last_assistant_message:$m,session_id:"s1",prompt_id:$p}' | bash "$HOOK"; }
expect() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }

out="$(run 'Fiz tudo. Quer que eu apague os brokers?' p1)"; rc=$?
expect "injects on buried ask"      '[ $rc -eq 0 ] && printf "%s" "$out" | grep -q additionalContext'
out="$(run 'Fiz tudo. Quer que eu apague os brokers?' p1)"
expect "one-shot per prompt"         '[ -z "$out" ]'
out="$(run $'Pronto.\n\n> **✅ NADA PRECISA DE VOCÊ** — ok.' p2)"
expect "silent on clear line"        '[ -z "$out" ]'
out="$(run $'Pronto.\n\n> **🔔 PRECISA DE VOCÊ (1)**\n> 1. **🛑 AUTORIZAR** — x · `1 sim`' p3)"
expect "no injection when block ok"  '[ -z "$out" ]'
expect "notify logged for ok block"  'grep -q "\"note\":\"notify\"" "$TMP/state/ledger.jsonl"'
out="$(jq -cn '{last_assistant_message:"Should I merge?",session_id:"../../x",prompt_id:"p4"}' | bash "$HOOK")"
expect "rejects unsafe session_id"   '[ -z "$out" ] && [ ! -e "$TMP/x" ]'
out="$(jq -cn --arg m 'Quer que eu siga?' '{last_assistant_message:$m,session_id:"s9"}' | bash "$HOOK")"
expect "injects without prompt_id (digest key)" 'printf "%s" "$out" | grep -q additionalContext'
out="$(jq -cn --arg m 'Quer que eu siga?' '{last_assistant_message:$m,session_id:"s9"}' | bash "$HOOK")"
expect "digest key is one-shot"      '[ -z "$out" ]'
out="$(jq -cn --arg m 'Quer que eu siga?' '{last_assistant_message:$m,session_id:"s9"}' | MAOS_ATTENTION_DIGEST_TTL=0 bash "$HOOK")"
expect "stale digest marker re-claimable (new turn, same text)" 'printf "%s" "$out" | grep -q additionalContext'
out="$(jq -cn --arg m 'Outra: posso aplicar?' '{last_assistant_message:$m,session_id:"s9",stop_hook_active:true}' | bash "$HOOK")"
expect "no re-inject on continuation w/o prompt_id" '[ -z "$out" ]'
mkdir -p "$TMP/bin"; for c in dirname mkdir date cat; do ln -sf "$(command -v $c)" "$TMP/bin/$c"; done
out="$(PATH="$TMP/bin" /bin/bash "$HOOK" </dev/null)"; rc=$?
expect "dep-missing still ledgered"  '[ $rc -eq 0 ] && grep -q "jq_missing" "$TMP/state/ledger.jsonl"'
out="$(MAOS_ATTENTION_GATE=0 run 'Should I merge?' p5)"
expect "kill-switch honored"         '[ -z "$out" ]'
out="$(printf 'not json' | bash "$HOOK")"; rc=$?
expect "fail-safe on garbage"        '[ $rc -eq 0 ]'
echo "--- $pass passed, $fail failed"; [ "$fail" -eq 0 ]
