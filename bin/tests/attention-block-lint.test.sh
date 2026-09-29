#!/usr/bin/env bash
# Tests for bin/attention-block-lint (Pharos). Run: bash bin/tests/attention-block-lint.test.sh
set -u
LINT="$(cd "$(dirname "$0")/.." && pwd)/attention-block-lint"
pass=0; fail=0
check() { # name expected_verdict expected_rc <<< text
  local name="$1" want="$2" want_rc="$3" out rc
  out="$("$LINT" --json)"; rc=$?
  got="$(printf '%s' "$out" | python3 -c 'import json,sys;print(json.load(sys.stdin)["verdict"])')"
  if [ "$got" = "$want" ] && [ "$rc" = "$want_rc" ]; then pass=$((pass+1)); echo "ok   $name";
  else fail=$((fail+1)); echo "FAIL $name: got=$got rc=$rc want=$want/$want_rc"; fi
}

check "buried question, no block" missing_block 2 <<'T'
Fiz a limpeza. Quer que eu remova também os brokers órfãos?
Segue o resto do relatório.
T

check "buried go request en" missing_block 2 <<'T'
Everything is staged. Should I merge the PR now.
T

check "proper attention block at end" ok 0 <<'T'
Limpeza concluída, 41 GB liberados.

> **🔔 PRECISA DE VOCÊ (2)**
> 1. **🛑 AUTORIZAR** — encerrar 7 brokers órfãos · responda `1 sim` / `1 não`
> 2. **🔶 DECIDIR** — região · `2A` sa-east-1 (recomendado) · `2B` us-east-1
> ➕ +1 registrado no backlog (não precisa de você agora)
T

check "clear line, no asks" ok 0 <<'T'
PR #42 mergeado, checks verdes.

> **✅ NADA PRECISA DE VOCÊ**
T

check "clear line but ask buried above" inconsistent_clear_with_asks 2 <<'T'
Posso aplicar a migração em hml?

> **✅ NADA PRECISA DE VOCÊ** — tudo certo.
T

check "block followed by trailing prose" block_not_last 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **✋ AÇÃO MANUAL** — rotacionar URL do Zapier
Ah, e mais uma coisa sobre o disco.
T

check "empty attention header" empty_attention_block 2 <<'T'
> **🔔 PRECISA DE VOCÊ (0)**
T

check "over cap (4 items)" over_cap 2 <<'T'
> **🔔 PRECISA DE VOCÊ (4)**
> 1. **🛑 AUTORIZAR** — a · `1 sim`
> 2. **🔶 DECIDIR** — b · `2A`
> 3. **✋ AÇÃO MANUAL** — c
> 4. **✋ AÇÃO MANUAL** — d
T

check "question inside code fence ignored" no_block_no_asks 0 <<'T'
Resultado:
```
read -p "Continue? " x
```
Pronto.
T

check "quoted operator question ignored" no_block_no_asks 0 <<'T'
> você perguntou: "terminou?"
Sim, terminou — evidência abaixo.
T

check "plain status, nothing asked" no_block_no_asks 0 <<'T'
Disco em 88%, memória 51% livre.
T

check "legacy color circles are not items" malformed_item 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔴 AUTORIZAR** — x · `1 sim` / `1 não`
T

check "asking item without reply token" malformed_item 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — encerrar processos, ok?
T

check "item without verb word" malformed_item 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶** — escolher região · `1A` / `1B`
T

check "manual step needs no token" ok 0 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **✋ AÇÃO MANUAL** — rotacionar a URL do Zapier
T

check "clear header followed by an item" inconsistent_clear_with_asks 2 <<'T'
> **✅ NADA PRECISA DE VOCÊ**
> 1. **🛑 AUTORIZAR** — x · `1 sim`
T

check "reply token bound to wrong item" malformed_item 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — x · `2 sim`
T

check "unknown marker in mixed block" malformed_item 2 <<'T'
> **🔔 PRECISA DE VOCÊ (2)**
> 1. **🛑 AUTORIZAR** — x · `1 sim`
> 2. **🔴 DECIDIR** — y · `2A`
T

check "item depends on PR with no status line" dependency_unexplained 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — fazer X depois do merge do #463 · `1A` / `1B`
T

check "dependency explained on a wait line" ok 0 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — fazer X depois do merge do #463 · `1A` / `1B`
> ⏳ #463 — comigo (agente): 2ª rodada de revisão dos bots; merge automático quando verde · nada a fazer por você
T

check "dependency prefix does not match longer id" dependency_unexplained 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — depois do #46 · `1A` / `1B`
> ⏳ #463 — comigo: outra coisa
T

check "UTF-8 is not a ticket" ok 0 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — converter arquivos para UTF-8 · `1 sim` / `1 não`
T

check "duplicate item numbers" misnumbered_items 2 <<'T'
> **🔔 PRECISA DE VOCÊ (2)**
> 1. **🛑 AUTORIZAR** — a · `1 sim`
> 1. **🔶 DECIDIR** — b · `1A`
T

check "header count disagrees with items" header_count_mismatch 2 <<'T'
> **🔔 PRECISA DE VOCÊ (9)**
> 1. **🛑 AUTORIZAR** — a · `1 sim`
T

check "unrelated code span next to reply token" ok 0 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — rodar `make deploy` nos brokers · responda `1 sim`
T

echo "--- $pass passed, $fail failed"
[ "$fail" -eq 0 ]
