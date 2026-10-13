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

check "attention header without (N) is a mismatch" header_count_mismatch 2 <<'T'
> **🔔 PRECISA DE VOCÊ**
> 1. **🛑 AUTORIZAR** — a · `1 sim`
T

check "bare wait line (no owner/state/action) does not explain a dependency" dependency_unexplained 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — mesclar depois do #463 · `1 sim` / `1 não`
> ⏳ #463
T

check "wait line missing the human-action clause is not enough" dependency_unexplained 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — mesclar depois do #463 · `1 sim` / `1 não`
> ⏳ #463 — comigo (agente): em revisão dos bots
T

check "full wait line explains the dependency" ok 0 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — mesclar depois do #463 · `1 sim` / `1 não`
> ⏳ #463 — comigo (agente): em revisão dos bots · nada a fazer por você
T

check "second clear header after an actionable block" multiple_status_headers 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — encerrar brokers · responda `1 sim` / `1 não`

> **✅ NADA PRECISA DE VOCÊ**
T

check "clear header with an ask after it" inconsistent_clear_with_asks 2 <<'T'
Pronto.

> **✅ NOTHING NEEDS YOU** — Should I merge?
T

check "unnumbered quoted ask inside the block" unnumbered_ask_in_block 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — apagar logs · responda `1 sim` / `1 não`
> Should I also delete the backups?
T

check "non-ask quoted note inside the block stays ok" ok 0 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — apagar logs · responda `1 sim` / `1 não`
> detalhes completos na seção 9 acima
T

check "truncated header without label and closing bold" malformed_header 2 <<'T'
> **🔔 (1)
> 1. **🛑 AUTORIZAR** — x · `1 sim`
T

check "header missing the closing bold" malformed_header 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)
> 1. **🛑 AUTORIZAR** — x · `1 sim`
T

check "substring boundary: #46 is not explained by a well-formed #463 line" dependency_unexplained 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — depois do #46 · `1A` / `1B`
> ⏳ #463 — comigo (agente): em revisão dos bots · nada a fazer por você
T

check "wait line explains its LEADING ref only, not a ref mentioned later" dependency_unexplained 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — mesclar depois do #463 · `1 sim` / `1 não`
> ⏳ #999 — comigo (agente): em revisão · #463 nada a fazer por você
T

check "malformed wait line carrying an ask is scanned" unnumbered_ask_in_block 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — apagar logs · responda `1 sim` / `1 não`
> ⏳ Should I delete the backups?
T

check "malformed overflow line carrying an ask is scanned" unnumbered_ask_in_block 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — apagar logs · responda `1 sim` / `1 não`
> ➕ Should I also delete the backups?
T

check "dependency inside a code span is still a dependency" dependency_unexplained 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — mesclar depois do `#463` · `1 sim` / `1 não`
T

check "separate quoted paragraph after the block breaks last-thing" block_not_last 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — apagar logs · responda `1 sim` / `1 não`

> outro parágrafo citado, sem relação com o bloco
T

check "duplicate reply token within one item is ambiguous" duplicate_reply_token 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — região · `1A` us-east · `1A` eu-west
T

check "duplicate yes/no reply token (whitespace-normalized)" duplicate_reply_token 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — apagar logs · responda `1 sim` / `1  sim`
T

check "distinct reply tokens stay ok" ok 0 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — região · `1A` us-east · `1B` eu-west
T

check "two explicit asks in prose, block surfaces only one" unsurfaced_asks 2 <<'T'
Should I merge PR #12 now?
Should I also delete the old release branch?

> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — merge do PR · responda `1 sim` / `1 não`
T

check "two explicit asks in one prose line (two sentences), one item" unsurfaced_asks 2 <<'T'
Quer que eu faça o merge? Posso aplicar a limpeza da branch antiga também?

> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — merge · responda `1 sim` / `1 não`
T

check "rhetorical bare questions do not count as asks" ok 0 <<'T'
Por que o build falhou? Porque o cache expirou. O que mudou? Só o lockfile.

> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — limpar cache · responda `1 sim` / `1 não`
T

check "each prose ask surfaced as its own item" ok 0 <<'T'
Should I merge PR #12 now?
Should I also delete the old release branch?

> **🔔 PRECISA DE VOCÊ (2)**
> 1. **🛑 AUTORIZAR** — merge do PR · responda `1 sim` / `1 não`
> 2. **🛑 AUTORIZAR** — apagar branch antiga · responda `2 sim` / `2 não`
T

check "extra asks routed to overflow backlog count as surfaced" ok 0 <<'T'
Should I merge PR #12 now?
Should I also delete the old release branch?

> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — merge do PR · responda `1 sim` / `1 não`
> ➕ +1 registrado no backlog (não precisa de você agora)
T

check "subject PR approval needs no wait line" ok 0 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🛑 AUTHORIZE** — merge PR #463 now · `1 yes` / `1 no`
T

check "inline subject ref is not a dependency" ok 0 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — mesclar o PR `#463` agora · `1 sim` / `1 não`
T

check "subject and after dependency are distinguished" ok 0 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🛑 AUTHORIZE** — merge PR #463 after PR `#42` · `1 yes` / `1 no`
> ⏳ #42 — agent: in review · nothing for you
T

check "dependency clause ends before next subject" ok 0 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🛑 AUTHORIZE** — after #42, merge PR #463 · `1 yes` / `1 no`
> ⏳ #42 — agent: in review · nothing for you
T

check "English blocked-on dependency still needs status" dependency_unexplained 2 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🔶 DECIDE** — release blocked-on `#42` · `1A` / `1B`
T

check "Portuguese blocked dependency still needs status" dependency_unexplained 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — release bloqueada pelo PR #42 · `1A` / `1B`
T

check "English depends-on dependency still needs status" dependency_unexplained 2 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🔶 DECIDE** — release depends on #42 · `1A` / `1B`
T

check "Portuguese apos dependency still needs status" dependency_unexplained 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — publicar após #42 · `1A` / `1B`
T

MAOS_ATTENTION_TICKET_PREFIXES="ABC" check "configured ticket dependency inside code span" dependency_unexplained 2 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🔶 DECIDIR** — publicar depois de `ABC-42` · `1A` / `1B`
T

MAOS_ATTENTION_TICKET_PREFIXES="ABC" check "configured ticket subject needs no wait line" ok 0 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🛑 AUTHORIZE** — close ABC-42 · `1 yes`
T

MAOS_ATTENTION_TICKET_PREFIXES="ABC" check "configured ticket exact leading wait ref explains dependency" ok 0 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🔶 DECIDE** — publish after `ABC-42` · `1A` / `1B`
> ⏳ `ABC-42` — agent: in review · nothing for you
T

MAOS_ATTENTION_TICKET_PREFIXES="ABC" check "unconfigured ticket prefix stays ignored" ok 0 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🔶 DECIDE** — publish after XYZ-42 · `1A` / `1B`
T

check "grouped replies reject another item number" malformed_item 2 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🛑 AUTHORIZE** — merge release · `1 yes / 2 no`
T

check "compact grouped letter replies reject another item" malformed_item 2 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🔶 DECIDE** — region · `1A/2B`
T

check "grouped replies for same item remain valid" ok 0 <<'T'
> **🔔 PRECISA DE VOCÊ (1)**
> 1. **🛑 AUTORIZAR** — mesclar · `1 sim / 1 não`
T

check "compact grouped letters and command spans remain valid" ok 0 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🔶 DECIDE** — run `make deploy` in region · `1A/1B`
T

check "grouped replies reject unnumbered alternative" malformed_item 2 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🛑 AUTHORIZE** — merge · `1 yes / no`
T

check "letter reply token must match completely" malformed_item 2 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🔶 DECIDE** — region · `1A-extra`
T

check "duplicate grouped replies remain ambiguous" duplicate_reply_token 2 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🔶 DECIDE** — region · `1A/1A`
T

check "bare numbered reply remains valid" ok 0 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🛑 AUTHORIZE** — merge · `1`
T

check "clear overflow cannot hide a question" inconsistent_clear_with_asks 2 <<'T'
> **✅ NOTHING NEEDS YOU**
> ➕ +1 Should I merge the release?
T

check "clear wellformed wait cannot hide a question" inconsistent_clear_with_asks 2 <<'T'
> **✅ NOTHING NEEDS YOU**
> ⏳ #42 — agent: ready · Should I merge the release?
T

check "clear wait status without an ask remains valid" ok 0 <<'T'
> **✅ NOTHING NEEDS YOU**
> ⏳ #42 — agent: in review · nothing for you
T

check "attention wait and overflow metadata remain valid" ok 0 <<'T'
> **🔔 NEEDS YOU (1)**
> 1. **🛑 AUTHORIZE** — release after #42 · `1 yes` / `1 no`
> ⏳ #42 — agent: in review · nothing for you
> ➕ +1 deferred to backlog: Should I delete the old branch?
T


echo "--- $pass passed, $fail failed"
[ "$fail" -eq 0 ]
