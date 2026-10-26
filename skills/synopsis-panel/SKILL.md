---
name: synopsis-panel
description: |
  Funde a N-Tree de pendências do work-compass com o ledger HITL do punch-list em UM
  único painel — uma árvore onde cada item HITL aparece sinalizado (⏫/👤) junto da
  pendência a que pertence — e renderiza esse painel para HUMANO (árvore markdown ·
  mermaid-mindmap · HTML autônomo, estilo hitl-digest) E para AGENTE (um envelope JSON
  unificado). É uma skill FINA: NÃO reimplementa agregação, ledger nem Eisenhower —
  CHAMA os motores SSOT (work-compass --json, hitl-punch-list.py/punch-list.md,
  eisenhower) e autora só a camada de fusão+render. Híbrido: parte cognitiva interpreta
  escopo/filtro/world; parte determinística é o script de fusão+render. Use quando o
  operador pedir "painel unificado de pendências e HITL", "o que está pendente + o que
  precisa de mim num só lugar", "árvore de pendências com os gates humanos marcados",
  "synopsis panel", "unified pendencies + HITL view". Read-only; o script nunca decide
  nem muta — só funde e desenha.
prompt_version: "0.1.0"
type: skill
spec: AAIF / agentskills.io
applicable_hosts: [Claude Code, Cursor, GitHub Copilot, Aider, any AAIF-compliant agent]
allowed-tools: [Bash, Read]
cycles_completed: 0
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: work-landscape
  cross_link_slug: synopsis-panel
  dogfood_status: forged-not-yet-dogfooded
triggers:
  - synopsis panel
  - painel unificado pendencias hitl
  - pendencias e hitl num so painel
  - unified pendencies and hitl view
  - arvore de pendencias com gates humanos
  - o que esta pendente e o que precisa de mim
---

# synopsis-panel

> **synopsis** ← grego *sún* ("juntos") + *ópsis* ("um ver") = *um-ver-do-todo-junto*:
> todas as partes numa só visão. É exatamente o que este artefato faz — traz dois
> streams separados (a N-Tree de pendências + o ledger HITL) para UM só painel.
> Fusão + render fino. **Compõe** os motores existentes — reimplementa **nenhum**.
> Cross-link slug: `[[synopsis-panel]]`.

## §0 — BEING > Rules (foundational)
Esta skill serve a intenção do operador: ver, num só lugar, o que está pendente E o que
precisa dele (HITL). Se um passo/gate obstruir entregar esse painel AGORA, pule-o, registre
`Skipped <passo> — BEING > Rules`, prossiga. É **read-only**: o script nunca decide, muta,
merge, aprova ou fecha nada — só lê os SSOT, funde e desenha. Qualquer ação de escrita
continua operator-gated nos próprios motores (work-compass `--route` imprime comando,
nunca executa; HITL só o humano resolve).

## O que é (e, explícito, o que NÃO é)
É a **menor coisa** que entrega a lacuna medida no DDR: ninguém juntava a árvore de
pendências e o painel HITL **no mesmo artefato**, e nenhum dos dois emitia HTML gerado.
Esta skill autora só isso — a camada de **fusão + 3 renders humanos + 1 envelope JSON**.

| Faz | NÃO faz (chama o SSOT) |
|---|---|
| funde pendências ↔ HITL num modelo único | **não** agrega trabalho → `work-compass-aggregate.py` |
| sinaliza cada item HITL (⏫ gate · 👤 human-domain) na árvore | **não** mantém o ledger HITL → `hitl-punch-list.py` + `punch-list.md` (SSOT) |
| preserva a ordem de prioridade | **não** classifica Q1→Q4 → `eisenhower` (via work-compass `--sort eisenhower`) |
| renderiza árvore markdown · mermaid · HTML · JSON | **não** inventa HTML novo de dados — desenha o que os motores produzem |

## Composição (reuso, zero duplicação — a prova anti-over-eng)
```text
             ┌─────────────────────────────┐
pendências → │ work-compass-aggregate.py   │ --json --sort eisenhower  (SSOT: agregação + 7 CPT + 10 heurísticas + Eisenhower)
             └─────────────────────────────┘
HITL       → ┌─────────────────────────────┐
             │ hitl-punch-list.py          │ lê punch-list.md          (SSOT: 5 tipos, IDs H-NNNN, severidade)
             └─────────────────────────────┘
                         │  (net-new: SÓ ISTO)
                         ▼
             ┌─────────────────────────────┐
             │ bin/synopsis-fuse.py        │  fusão → 4 renders (tree·mermaid·html·json)
             └─────────────────────────────┘
```
- **Agregação / N-Tree / Eisenhower** ← `../../bin/work-compass-aggregate.py --json --sort eisenhower` (SSOT; não reimplementar).
- **Ledger HITL** ← `hitl-punch-list.py` lendo `hitl/punch-list.md` (SSOT; os 5 tipos credencial/gasto/irreversível/envio/negócio; o script só **lê**, nunca recomputa severidade).
- **House-style visual** ← estilo painel `hitl-digest` (cards, severidade 🟡/🟠/🔴, marcador ⏫ para gate, 👤 para human-domain).

> **Prova (grep the run):** `bin/synopsis-fuse.py` NÃO contém coletores, parsing de
> sessão/git/gh, nem lógica de severidade/Eisenhower — ele **chama** work-compass e
> **lê** o punch-list. A única lógica nova é a fusão (juntar um item HITL à pendência
> certa por token de Link/ID) + os renderers.

## Parte cognitiva (o que o agente decide antes de rodar o script)
A skill é **híbrida**: antes do script determinístico, o agente interpreta —
1. **Escopo / world** — o pedido é do panorama todo, da sessão, do repo atual, do vault?
   → mapeia para `--scope {current|session|repo|vault|all}`.
2. **Filtro** — só pendências vivas ou tudo? só os nós que têm gate/flag?
   → `--include {pending|all}` · `--pending-only` · `--hitl-only`.
3. **Público / formato** — humano no browser (HTML), humano no chat (árvore markdown ou
   mermaid), ou agente (JSON)? → `--format`.
4. **Título / contexto** — um rótulo que diga de que panorama é este painel → `--title`.

A parte **determinística** é tudo abaixo disto: o `synopsis-fuse.py` funde e desenha de
forma reproduzível, com self-heal (erro → envelope de repair-request para um ai-harness).

## Uso (determinístico — o script)
```bash
# caminho rápido: deixa o script chamar os motores (roda os coletores vivos; mais lento)
bin/synopsis-fuse.py --scope all --include pending --format tree

# caminho barato: passe payloads já capturados (sem re-rodar coletores)
work-compass-aggregate.py --json --sort eisenhower --pendency-scope repo --include pending > /tmp/wc.json
bin/synopsis-fuse.py --compass-json /tmp/wc.json --hitl-md ~/eko-engram/hitl/punch-list.md --format html > painel.html

# só o painel HITL (os gates humanos), em árvore.
# O `--compass-json -` com `{}` no stdin NÃO é opcional aqui: sem ele o script invoca o
# work-compass vivo e roda os coletores (minutos). O digest HITL não precisa da N-Tree.
# O ledger é o vault NORMAL, passado explicitamente (o comando /hitl-digest faz o mesmo):
# a descoberta padrão do motor resolve ~/Projects/eko-engram, que é OUTRO clone.
echo '{}' | bin/synopsis-fuse.py --hitl-only --compass-json - --hitl-md ~/eko-engram/hitl/punch-list.md --format tree

# envelope JSON unificado para outro agente consumir
bin/synopsis-fuse.py --format json
```

### Flags
| Flag | Default | Significado |
|---|---|---|
| `--compass-json F\|-` | — (chama o motor) | payload `work-compass --json` pronto, ou `-` stdin; omitido ⇒ chama o motor vivo |
| `--hitl-md F` | descobre (o comando `/hitl-digest` passa o **vault normal** `~/eko-engram/hitl/punch-list.md` explicitamente) | caminho do `punch-list.md` SSOT. A descoberta resolve a cópia do **working tree** — certo para quem está editando o ledger de propósito. Por isso todo render **diz qual arquivo leu** e **avisa** quando ele está modificado contra o `HEAD` ou o repo está atrás do upstream (ver abaixo) |
| `--hitl-json F\|-` | — | array HITL já parseado (pula o parse do md); vazio/ausente = sem ledger (válido) |
| `--format` | `tree` | `tree` · `mermaid` · `html` · `json` |
| `--scope` | `all` (pendências) · `session` (ledger HITL, em `--hitl-only`) | `current\|session\|repo\|vault\|all`. Escopo de **pendência** (repassado ao work-compass) e, em `--hitl-only`, escopo do **ledger HITL**: sem `--scope` o digest mostra só os itens desta conversa; `--scope all` traz o ledger inteiro, legados inclusive; qualquer outro valor **nunca** amplia |
| `--session-id ID[,ID]` | resolvido do ambiente | identidade da conversa que invocou o render (comparação **exata** — um id é opaco, `A` ≠ `a`). Ordem: `--session-id` → `MAOS_SELF_SESSION_ID` → `CLAUDE_CODE_SESSION_ID` → `CLAUDE_SESSION_ID` → headers nativos de `PI_SESSION_FILE` com ancestrais `parentSession` explícitos. `PI_SESSION_ID` é deliberadamente ignorado: é por *processo*. Overrides não expandem para ancestrais. Sem identidade resolvida o escopo de sessão **falha fechado** (nada mostrado + motivo) |
| `--include` | `pending` | `pending` (só não-resolvidas) · `all` |
| `--hitl-only` | off | renderiza só o ramo HITL |
| `--pending-only` | off | mantém nós flagged / com HITL |
| `--title` | *(pt-BR default)* | rótulo do painel |
| `--self-heal` | off | em erro, emite um repair-request estruturado em stderr (M.O. híbrido de self-heal) |

### Escopo do ledger HITL (de quem é cada gate)

O `punch-list.md` é **uma fila global**: os gates de todas as conversas estão no mesmo
arquivo. Renderizá-la inteira como "o que precisa de mim agora" responde a uma pergunta
que ninguém fez — medido em 2026-10-26, o digest puro devolveu **19 itens globais** para
uma conversa que tinha **2** gates seus.

- **O default em `--hitl-only` é a sessão**: só os itens cuja proveniência (a coluna
  `Sessão` do próprio ledger) nomeia esta conversa.
- **Só `--scope all` amplia** — pedido explícito, nunca inferido.
- **Item sem proveniência é legado**: entra no escopo global e nunca no da sessão.
  Mencionar o ID de um item no chat não o torna seu; a prova é o ledger. Um ledger
  escrito antes da coluna existir é lido assim: todas as suas linhas são legadas.
- **A comparação do id é exata** — só o espaço em volta é removido. Um id de sessão é um
  token opaco, então `A` e `a` são conversas diferentes.
- **Continuidade nativa do OMP**: no fallback `PI_SESSION_FILE`, lê só o header da
  sessão e dos arquivos nativos explicitamente referidos por `parentSession`.
  Um worker usa o root JSONL adjacente; recuperação sob novo ID inclui o ID de origem
  sem reescrever o ledger. Um UUID de pai resolve só o arquivo nativo de UUID exato na
  mesma coleção; único candidato continua a cadeia, nenhum inclui esse pai e encerra,
  múltiplos falham fechado. Ciclo, conflito de header/nome e referência ambígua também
  falham fechado. Não usa `providerPromptCacheKey`, cwd, título ou outras coleções.
- **Identidade ausente ⇒ falha fechado**: nada é mostrado e o motivo é dito. O render
  nunca cai no "tudo" e nunca afirma "não existem" — porque "não sei de quem é" não é
  "não existe".
- **Fora de `--hitl-only` o painel geral não muda**: ele continua sendo um panorama e
  mostra o ledger inteiro. O escopo de sessão é do *digest*.

No envelope JSON os mesmos fatos vêm em `meta.hitl_scope`, `meta.hitl_scope_reason`,
`meta.hitl_session_ids`, `meta.hitl_session_resolved`, `meta.hitl_session_source`,
`meta.hitl_scope_unresolved` e `meta.hitl_ledger_total` (o total **antes** do recorte,
para "0 mostrados" nunca ser lido como "0 existentes").

### Procedência do ledger (qual arquivo foi lido)

Todo render nomeia o ledger que leu, e avisa quando ele diverge da versão rastreada:

```
> HITL ledger: `/Users/<you>/eko-engram/hitl/punch-list.md`
>
> ⚠ ledger read from the WORKING TREE and it diverges from the tracked version:
>   MODIFIED relative to HEAD; the repo is 21 commit(s) BEHIND its upstream.
>   The item count can match while the items differ.
```

No envelope JSON os mesmos fatos vêm em `meta.hitl_source`, `meta.hitl_source_kind`,
`meta.hitl_source_dirty`, `meta.hitl_source_behind` e `meta.hitl_warning`.

**Por que avisar e não trocar o arquivo.** Medido em 2026-10-26: um vault 21 commits
atrás do upstream, com o ledger modificado, rendeu **16 abertos** — exatamente o mesmo
total da versão rastreada, com três itens já fechados aparecendo e três reais escondidos.
*O total bater é o que escondeu o erro.* Mas o motor é read-only e serve humano e agente:
substituir o arquivo por baixo de quem está editando o ledger de propósito seria pior que
o defeito. Então ele nunca troca o arquivo — ele **nomeia** e **avisa**. Um ledger limpo e
em dia não emite aviso nenhum (testado: `skills/synopsis-panel/tests/`).

## O modelo de fusão (a única lógica nova)
- Cada item HITL do `punch-list.md` é indexado por `ID` (H-NNNN) e pelo `Link`.
- Para cada pendência do work-compass, o script casa os tokens do item (id, título,
  `refs`) contra esse índice: **casou → o item HITL é anexado sob aquela pendência e
  sinalizado** (⏫ + glifo de severidade).
- Um item HITL que **não casa** com nenhuma pendência vai para um ramo próprio
  `HITL (human-domain 👤)` — **nunca é descartado** (um gate humano nunca some do painel).
- A ordem de prioridade vem do `--sort eisenhower` do work-compass (Q1→Q4), preservada.

## Saídas
- **tree** — árvore markdown enxuta (chat / terminal).
- **mermaid** — `mindmap` com classes `:::hitl`/`:::flag` para colorir severidade
  (mermaid mindmap é *experimental* p/ ícones — por isso degrada para a árvore estável;
  lição do DDR).
- **html** — página autônoma, estilo hitl-digest, dark/light automático, `<details>` por
  domínio, badges de gate. Zero dependência externa.
- **json** — UM envelope unificado `{artifact, title, schema, meta, tree:{domains, hitl_unattached}}`
  para consumo agente-a-agente (AAIF [C06]).

## §Quality Tests (self-validity)
1. **Self-Application** — forjada pelo pipeline MAOS: Stage-0 classificou "um painel que
   funde pendências + HITL" → INTENT → forge; o DDR já rodou EXPAND/FILTER/HARMONIZE e
   mediu a lacuna (ninguém funde os dois + ninguém emite HTML); `anima` nomeou
   (`synopsis-panel`, rejeitado `confluence-panel` por colisão de trademark Atlassian). ✅
2. **Non-Contradiction** — compõe work-compass + hitl-punch-list + eisenhower sem
   duplicá-los; consistente com o precedente thin-preset (work-compass "compõe, não
   reimplementa"). ✅
3. **Survival** — aplicada a si: ela advoga fundir-e-mostrar sem reimplementar; ela É uma
   camada de fusão fina sobre SSOT. ✅
4. **Bounded-Responsibility** — read-only · `--scope`/`--include`/`--*-only` limitam o
   recorte · self-heal em vez de crash · 0 escrita/mutação · DUED sunset. ✅
5. **Explicit-Exception** — §0 BEING>Rules + HITL absente degrada (válido) + motor
   ausente → self-heal repair-request. ✅
6. **Utility-Sunset** — §DUED. ✅

## §DUED Sunset (qualitativo)
Deprecar quando QUALQUER: o work-compass ganhar um renderer HTML + um ramo HITL nativos
(E6 — a lacuna fecha no motor) · o hitl-digest absorver a árvore de pendências (E6) · o
host entregar um painel unificado nativo (E1) · retratação do operador (E4) · ≥3
fusões falso-positivas (E5). Dormente-por-design caso contrário.

## §Refs
- Motores SSOT (compostos, não reimplementados): `../../bin/work-compass-aggregate.py`
  (`[[work-compass]]`) · `hitl-punch-list.py` + `hitl/punch-list.md` (eko-engram SSOT) ·
  `eisenhower` (via work-compass `--sort eisenhower`).
- House-style: `hitl-digest` spec (painel 52-col, severidade, ⏫/👤).
- Naming: `[[anima]]` (nomeou esta skill; soul↔body com `agentic-tool-forge`).
- Pipeline de forja: `[[agentic-tool-pipeline]]` (conduziu) · `[[agentic-tool-forge]]`.
- Governança: `[[worktree-policy]]` · `[[hierarchical-merge]]` · `CONTRIBUTING.md`.
- Cross-link slug: `[[synopsis-panel]]`.

## Changelog
| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-10-21 | Bootstrap — a camada fina de **fusão + render** que faltava: funde a N-Tree de pendências (`work-compass --json`) + o ledger HITL (`punch-list.md`) num só modelo e renderiza tree/mermaid/HTML (humano) + JSON (agente). Net-new = só o modelo de fusão (anexa HITL à pendência por token de Link/ID; HITL órfão vira ramo próprio, nunca descartado) + os 4 renderers + self-heal. Reimplementa zero: agregação/Eisenhower ← work-compass (SSOT), ledger ← hitl-punch-list (SSOT), visual ← hitl-digest house-style. Nomeada via `anima` (`synopsis-panel`; rejeitado `confluence-panel` por colisão trademark Atlassian, `ntree-hitl-panel` por gloss-independence fraca). Forjada via pipeline MAOS (o DDR rodou EXPAND→FILTER→HARMONIZE). **forged-not-yet-dogfooded** (bounded: thin layer + PR, sem dogfood/merge). |

## License
MIT (matches multi-agent-os repo `LICENSE`).
