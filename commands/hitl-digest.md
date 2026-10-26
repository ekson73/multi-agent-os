---
name: hitl-digest
description: Render the HITL DIGEST on demand — the operator's "take the needle out of the haystack" block (só os pontos de atenção humana — credencial · gasto · irreversível · envio · negócio — ⏫ alta e 👤 domínio-humano primeiro). Thin command over the synopsis-panel engine (synopsis-fuse.py --hitl-only), which reads the punch-list.md SSOT ledger and renders the hitl-digest house-style. Reimplements NOTHING — no ledger, no render. Read-only.
---

# /hitl-digest Command

Render the **HITL DIGEST** — the operator-facing block that separates the human-attention
items (what the operator must *know* or *decide*) from the rest of the work, on demand instead of
only at end-of-turn. Metáfora de origem: *"tire a agulha do palheiro"* (ressaltar a decisão/info
importante do meio do textão).

This is a **thin entry point** over the [`synopsis-panel` skill](../skills/synopsis-panel/SKILL.md)
run in HITL-only mode — `bin/synopsis-fuse.py --hitl-only`. It **reimplements nothing**:

| What it does (thin) | What it DOES NOT do (calls the SSOT) |
|---|---|
| interpret scope/filter/format from the operator's words | **does not** maintain the HITL ledger → `hitl-punch-list.py` + `punch-list.md` (external ledger SSOT) |
| invoke `synopsis-fuse.py --hitl-only` and present the result | **does not** render the panel itself → `synopsis-fuse.py` (hitl-digest house-style) |
| order ⏫ alta + 👤 domínio-humano first, cap at the top items | **does not** classify severity → `hitl-punch-list.py` (5 types, IDs H-NNNN) |

> **O que É e o que NÃO É** — é o **atalho** que faltava: o motor de render HITL-only já
> existe (`synopsis-fuse.py --hitl-only`, PR #512) e o ledger já existe (`punch-list.md`, o
> SSOT externo); só não havia o command `/hitl-digest` que o operador aciona quando quiser. Este
> arquivo é esse atalho — **não** um novo motor, **não** um novo ledger.

## §0 — BEING > Rules
Serve a intenção do operador: ver, sob demanda, só os pontos que precisam dele. Se um passo/gate
obstruir entregar o digest AGORA, pule-o, registre `Skipped <passo> — BEING > Rules`, prossiga.
É **read-only**: o script só lê os SSOT, funde e desenha. Resolver/fechar um HITL continua
operator-gated no próprio ledger (só o humano resolve; silêncio nunca é aceite).

## Usage

```text
/hitl-digest [--scope current|session|repo|vault|all] [--format tree|mermaid|html|json]
             [--with-pendencies] [--hitl-md PATH] [--title TEXT]
```

## Parameters

| Param | Default | Effect |
|-------|---------|--------|
| `--scope` | `all` | recorte do panorama (repassado ao `work-compass` quando `--with-pendencies`) |
| `--format` | `tree` | `tree` (chat/terminal) · `mermaid` · `html` (página autônoma) · `json` (envelope p/ agente) |
| `--with-pendencies` | off | inclui a N-Tree de pendências com os HITL anexados; **off = só o ramo HITL** (o digest puro) |
| `--hitl-md PATH` | descobre | caminho do `punch-list.md` SSOT; omitido ⇒ o motor descobre o ledger automaticamente (via sua própria convenção de busca), que resolve a cópia do **working tree**. O digest sempre diz **qual arquivo leu** e **avisa** quando ele divergir da versão rastreada — leia o aviso antes de citar a fila |
| `--title TEXT` | *(pt-BR default)* | rótulo do digest |

## Parte cognitiva (o agente decide antes de rodar o script)
A skill é **híbrida**: antes do script determinístico, o agente interpreta —
1. **Escopo / world** — o pedido é do panorama todo, da sessão, do repo atual, do vault? → `--scope`.
2. **Só o digest ou digest + pendências?** — digest puro (agulhas) ⇒ sem `--with-pendencies`;
   "o que precisa de mim junto do que está pendente" ⇒ `--with-pendencies`.
3. **Público / formato** — humano no chat (tree/mermaid), humano no browser (html), agente (json)? → `--format`.

A parte **determinística** é o `synopsis-fuse.py`: funde e desenha de forma reproduzível, com
self-heal (erro → envelope de repair-request para um ai-harness).

## O que o command executa (determinístico)

```bash
# resolve o motor a partir da raiz do plugin (NÃO de $0: um command .md não é um script
# executável, então $0 é o shell/arg, não este arquivo). CLAUDE_PLUGIN_ROOT é a convenção
# do Claude Code; o fallback para a raiz do git cobre execução fora do runtime do plugin.
FUSE="${CLAUDE_PLUGIN_ROOT:-$(git rev-parse --show-toplevel)}/skills/synopsis-panel/bin/synopsis-fuse.py"

# DIGEST PURO (default) — só os gates humanos, sem rodar o coletor de pendências.
# O compass vazio ({} via stdin) curto-circuita a agregação: o digest HITL não
# depende da N-Tree, então não há por que esperar o work-compass. Rápido e read-only.
echo '{}' | python3 "$FUSE" --hitl-only --compass-json - --format tree

# digest puro em página HTML autônoma (estilo hitl-digest, dark/light)
echo '{}' | python3 "$FUSE" --hitl-only --compass-json - --format html > hitl-digest.html

# DIGEST + PENDÊNCIAS (--with-pendencies): aí SIM o coletor roda (mais lento). Cada HITL é
# anexado à pendência a que pertence. --pending-only mantém o foco HITL: só os nós que
# carregam um HITL (ou flag) permanecem na árvore, então o resultado é o digest HITL com as
# pendências a que os gates pertencem — NÃO o painel de sinopse completo.
python3 "$FUSE" --scope all --include pending --pending-only --format tree
```

> **Por que o compass vazio no caminho puro** — medido na fonte: o `synopsis-fuse.py` sempre
> carrega o compass no `main()`; sem `--compass-json` ele invoca o `work-compass` vivo (lento, pode
> travar). O digest HITL puro não precisa da N-Tree, então passar `{}` via stdin dá o resultado
> na hora. O `--hitl-only` mantém só o ramo dos gates humanos (⏫ severidade · 👤 human-domain);
> um HITL órfão (sem pendência casada) **nunca é descartado** — vai para o ramo próprio.
> O caminho padrão deste command é o puro; use `--with-pendencies` apenas quando quiser a N-Tree junto.

> **Leia o cabeçalho antes de citar a fila.** Todo digest nomeia o ledger que leu e avisa
> quando ele divergir da versão rastreada:
>
> ```
> > HITL ledger: `/Users/<you>/Projects/eko-engram/hitl/punch-list.md`
> >
> > ⚠ ledger read from the WORKING TREE and it diverges from the tracked version:
> >   MODIFIED relative to HEAD; the repo is 21 commit(s) BEHIND its upstream.
> ```
>
> Medido em 2026-10-26: com um vault 21 commits atrás e o ledger modificado, o digest
> rendeu **16 abertos** — o mesmo total da versão rastreada, com três itens já fechados
> aparecendo e três reais escondidos, um deles o mais grave da fila. **O total bater é o
> que esconde o erro**, então o total nunca serve de prova de frescura. Se o aviso
> aparecer, meça a versão rastreada antes de reportar:
>
> ```bash
> git -C ~/Projects/eko-engram show '@{upstream}:hitl/punch-list.md' > /tmp/ledger.md
> echo '{}' | python3 "$FUSE" --hitl-only --compass-json - --hitl-md /tmp/ledger.md --format tree
> ```

## Examples

```text
/hitl-digest                                   # o digest puro (agulhas), árvore no chat
/hitl-digest --format html                     # página autônoma estilo hitl-digest
/hitl-digest --with-pendencies --scope repo    # pendências do repo + os HITL anexados
/hitl-digest --format json                     # envelope JSON p/ outro agente consumir
```

## Fronteiras (o que este command NÃO faz)
- **Não muta o ledger.** Criar/fechar/reabrir um item HITL é no `hitl-punch-list.py` + `punch-list.md`;
  resolver é do humano. Este command só **lê e desenha**.
- **Não inventa HITL.** Só entram os 5 tipos do SSOT (`credencial` · `gasto` · `irreversivel` ·
  `envio` · `negocio`); decisão técnica o agente toma e registra, não vira HITL.
- **Não reimplementa render nem agregação.** Delega a `synopsis-fuse.py` (render) + `work-compass`
  (agregação/Eisenhower, só com `--with-pendencies`).

## §Refs
- Motor (composto, não reimplementado): `../skills/synopsis-panel/bin/synopsis-fuse.py`
  (`synopsis-panel`, PR #512) rodado em `--hitl-only`.
- Ledger SSOT: `hitl-punch-list.py` + `hitl/punch-list.md` (external ledger; 5 tipos, IDs H-NNNN).
- House-style: spec `hitl-digest` (painel 52-col, severidade 🟡/🟠/🔴, ⏫ gate · 👤 human-domain).
- Governança: `worktree-policy` · `hierarchical-merge` · `CONTRIBUTING.md`.

## License
MIT (matches multi-agent-os repo `LICENSE`).
