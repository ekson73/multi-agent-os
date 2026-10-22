# git-cycle-sentinel — mecânica (referência sob demanda)

> Carregada pela `SKILL.md` só quando for executar ou depurar §A6, §A7, repo-awareness, self-heal
> ou o fluxo completo. As regras normativas continuam na `SKILL.md`; em conflito, vale a `SKILL.md`.

## §A6 — mecânica do parse owner/repo (não-decorativa)
O modo-falha concreto que este guard **recusa**: tratar `git@github.com-meualias:owner/repo.git`
como se o owner fosse `github.com-meualias` (o alias de host colado no owner) ou assumir cegamente
`github.com`. A sentinela deriva owner/repo de `git remote get-url <remote>` com uma normalização
que remove protocolo **e host (inclusive host-alias)** antes do owner, e tira o `.git`:

```
url=$(git -C "$REPO" remote get-url "${REMOTE:-origin}")
# tira https://<host>/  |  ssh://<host>/  |  qualquer prefixo scp-style [user@]host: (inclusive
# host-alias puro sem user, ex. "github.com-meualias:")  |  e o sufixo .git
slug=$(printf '%s' "$url" | sed -E 's#^(https?://[^/]+/|ssh://[^/]+/|[^/@]+@[^:/]+:|[^/@:]+:)##; s#\.git/?$##')
# slug == "owner/repo"; RECUSA (STOP-ERROR) se não casar ^[^/]+/[^/]+$
printf '%s' "$slug" | grep -Eq '^[^/]+/[^/]+$' || die "owner/repo não derivável de $url"
```

As alternativas scp-style `[^/@]+@[^:/]+:` (forma **com user** `<user>@<host>:`, ex. um remote SSH
padrão ou com host-alias) e `[^/@:]+:` (forma **sem user** `<host-alias>:`, ex. um alias de
`~/.ssh/config`) cobrem toda forma de host/host-alias — o alias **nunca** entra no owner, nem na forma
`<user>@<alias>:` nem na forma `<alias>:owner/repo` pura (o furo que a 1ª versão do §A6 deixava
passar). O guard **bloqueia** o push quando o slug não casa `owner/repo` (em vez de seguir com um
alvo de `gh api` errado).

**Preservar o host para a verificação** — a sonda `gh api` tem de rodar contra o **mesmo host** que
receberá o push, não o `github.com` default; senão, num remote de GitHub Enterprise (ou host custom),
`gh api repos/<slug>` validaria um repo homônimo em `github.com` ou pararia num 404 do host errado.
Resolve-se o host **de um alias** via `git` (que já consulta o `~/.ssh/config`) e passa-se via
`--hostname`:

```
# host real por trás de um alias (resolve HostName do ssh_config); fallback para o host literal
rawhost=$(printf '%s' "$url" | sed -E 's#^(https?|ssh)://##; s#^[^/@]*@##; s#[:/].*$##')
apihost=$(ssh -G "$rawhost" 2>/dev/null | awk '/^hostname /{print $2; exit}'); apihost=${apihost:-$rawhost}
# normaliza endpoints de TRANSPORTE SSH de volta ao host de API (o setup porta-443 mapeia
# github.com -> ssh.github.com; a API não vive em ssh.<host>)
apihost=$(printf '%s' "$apihost" | sed -E 's#^ssh\.##')
gh api --hostname "$apihost" "repos/$slug" >/dev/null 2>&1 || die "repo $slug não resolve em $apihost"
```

404/erro aqui → STOP-ERROR, não push. (O `ssh -G` resolve só o HostName; um endpoint de transporte
como `ssh.github.com` é normalizado de volta ao host de API `github.com`.)

## §A7 — sonda de idempotência (não-decorativa)
O modo-falha concreto que este guard **recusa**: uma re-entrega assíncrona (mesma `idempotency_key`)
abrir um **segundo** PR/commit/comentário. Antes de **cada** mutação a sentinela sonda o estado e
pula o passo já feito:

- **formato** — trailer canônico `idmp: <theme>-<repo>-<AAAAMMDD>` (com espaço, no bloco de
  trailers, ex. `git commit --trailer "idmp: docs-fix-myrepo-20261022"`). Marcador no corpo de PR e
  comentário: `<!--idmp:docs-fix-myrepo-20261022-->`. Na leitura aceitar também a forma antiga sem
  espaço e keys antigas fora do formato, só para reconhecer artefato já feito; nunca gerar key nova
  fora do formato.
- **commit** — `git log --format=%H -n1 -F --grep="<key>" origin/<base>..HEAD` (a key vai no
  trailer do commit), confirmando a linha com `git interpret-trailers --parse`; **escopado ao range não-mergeado da branch** (`origin/<base>..HEAD`), **nunca**
  à história alcançável inteira — senão uma key reusada numa branch mergeada-e-deletada ainda seria
  alcançável de `HEAD` e daria falso-positivo, pulando um commit legítimo. O `-F` (fixed-string)
  casa a key **literalmente** (`.*` não casa qualquer marcador), mas casa substring (a key
  `docs-fix-myrepo-20261022` acharia também `docs-fix-myrepo-20261022-b`); por isso confirmar a linha de trailer exata `^idmp: ?<key>$`. Se já existe nesse range para esta
  `<key>`, **não** recommita.
- **PR** — `gh pr list --head <branch> --state all --json number,body,state` e **só reusa** o número
  se o corpo carregar o marcador `<!--idmp:<key>-->` **desta** key (ou o head OID casar o atual);
  **nunca** reusa só por casar o nome de branch — a branch determinística `agent/<owner>-<theme>` é
  reciclada, e `--state all` traz PRs já MERGED/CLOSED de ciclos passados; reusar um deles abriria o
  comentário/merge no PR errado. Também buscar a key em PRs de **qualquer** branch e estado:
  `gh pr list --state all --search "idmp:docs-fix-myrepo-20261022 in:body"`. Achou **MERGED** → no-op; achou
  **CLOSED** sem merge → não reabrir nem recriar em silêncio (`STOP-HITL` ou key nova por pedido
  explícito); achou **OPEN** → reusar. Sem match do marcador → abre PR novo.
- **comentário de review** — procura o marcador `<!--idmp:<key>-->` nos comentários antes de postar;
  presente → skip.

**Key estável entre reruns (persistência é a regra, derivação é só o seed)** — nenhuma derivação de
estado git é estável entre reruns assíncronos: `headSha` muda ao commitar, e `baseSha` muda porque a
própria Fase 4 faz `fetch`+`rebase origin/<base>` (A2), então `origin/<base>` avança entre a 1ª
entrega e o retry. Logo a regra primária é **persistir** a key: a 1ª invocação deriva um seed
(`<theme>-<repo>-<AAAAMMDD>` da 1ª invocação; o antigo `hash(repo + theme + baseSha)` segue aceito
como key explícita), **grava** essa key no trailer do commit e no corpo
do PR (`<!--idmp:<key>-->`), e **todo rerun relê a key persistida** desses artefatos em vez de
re-derivar. Só quando ainda não há nenhum artefato (a verdadeira 1ª vez) o seed é usado.
`--idempotency-key` explícito sempre vence e é o caminho recomendado para entregas async. A sonda
roda **antes** da mutação; sem ela a mutação é
**recusada** (não é "best-effort"). Isto torna A7 verificável: um segundo run com a mesma key não
produz nenhum objeto novo (prova: contagem de PR/commit/comentário idêntica ao 1º run).

> **Não-regressão de assinatura (A4) é inviolável**: a norma C1 é *condicional ao repo* — assinar
> onde 5/6 já assinam e onde o ruleset exige (`required_signatures` no ruleset ou na proteção clássica); **não** forçar
> assinatura em multi-agent-os enquanto `gpgsign=false` ali. A sentinela **respeita** o estado
> medido, nunca o inverte.

## Repo-awareness (o coração híbrido)
A sentinela lê o estado de cada repo e adapta ENFORCE vs APPLY ao que aquele repo **realmente tem**.
Perfis de exemplo (a medição original está em `[[git-cycle-norma-harmonizada-2026-10-21]]` §1):

| Perfil de repo (exemplo genérico) | Portão | `gpgsign` | `hooksPath` | Modelo | Postura da sentinela |
|---|---|---|---|---|---|
| ruleset com pull_request + checks + signatures | **FORTE** | true | `.githooks` ativo | Gitflow | **OBEDECE**: PR + checks strict + assina + resolve threads + back-merge re-medido; nunca `--no-verify` |
| proteção clássica com PR/review obrigatório + checks strict + enforce_admins, sem ruleset | **FORTE** (garantia efetiva equivalente) | conforme lido | conforme lido | trunk | **OBEDECE**: PR + checks; nunca push direto; nunca `--admin` |
| proteção clássica com PR + checks, `enforce_admins=false`, ator admin | **fraco para o ator** | conforme lido | conforme lido | trunk | **OBEDECE** aos checks e PR assim mesmo + SUPRE guardrails; nunca `--admin` |
| multi-agent-os (este repo) | fraco para o ator admin (clássica com PR + checks, `enforce_admins=false`) | lido ao vivo¹ | GaaS/hooks.json | trunk | **SUPRE** guardrails; assina (gpgsign lido **ao vivo**) |
| sem ruleset, sem proteção, hooks escritos mas não ligados | **mais fraco** | conforme lido | unset | trunk | SUPRE **tudo** em software (não assume que o hook protege) |
| espelho no GitHub com gate real em outra forja | fraco no GitHub | conforme lido | unset | trunk | SUPRE no GitHub; detecta a outra forja |

**Regra**: portão **forte → obedecer**; portão **fraco → suprir** (no-direct-main, scoped-add,
gitleaks, worktree). A lista acima é *ilustrativa* (perfis genéricos), **não** um cap nem a fonte de
decisão — a sentinela **relê o estado ao vivo** (`gh api .../rules/branches` + `.../rulesets/<id>` + `gh api .../branches/<b>/protection`
+ `.permissions` + `git config commit.gpgsign` + assinatura de teste + `core.hooksPath`) a cada run e decide pela leitura viva, nunca pela tabela
congelada (`pref.agentic_tools_hybrid_no_cap`).

> ¹ Snapshot 2026-10-21 da norma registrava multi-agent-os `gpgsign=false`; re-medido no dogfood
> cycle-1 (2026-10-21) está **`true`**. A *regra* A4 (espelhar o estado vivo) produz "assina em MAOS"
> corretamente — foi a célula congelada que envelheceu, não a decisão. Prova de que ler-ao-vivo >
> tabela. No dogfood D1 (2026-10-22), num ambiente de agente diferente, `commit.gpgsign`,
> `gpg.format` e `user.signingkey` estavam vazios e o commit de teste com `-S` falhou: a
> capacidade de assinar depende do **ambiente** que commita, por isso o A4 exige o teste real.

## Arquitetura HÍBRIDA (determinístico + cognitivo + self-heal)
Per o mandato do operador (`pref.tool_hybrid_and_selfheal_mandate`):

- **Determinístico (script)** — preflight fail-closed · classificação forte/fraco por ruleset ·
  refspec literal · rebase+retry bounded · `idempotency_key` skip · gitleaks · `ff-only` sync ·
  os gates ENFORCE que já são scripts (`worktree-gate.sh`, hooks). Estes são **chamados**, não
  reescritos.
- **Cognitivo (julgamento APPLY)** — classificar achado de review (correction vs style) · conferir
  legitimidade do aprovador (autor≠approver, contas proibidas, outro domínio) · julgar artefato de merge estrutural · questionar-e-corrigir instrução
  obsoleta · triage Eisenhower das pontas soltas no boy-scout.
- **Self-heal** — quando um passo script falha (ex. rebase conflita, push rejeitado por base-movel,
  check vermelho), a sentinela **não aborta cega**: captura o erro e o despacha a um ai-harness
  para resolver. **ai-harness** = só harnesses e modelos cobertos por assinaturas **já pagas** pelo
  operador (ex.: o agente de código incluído no plano), **sem chave de API cobrada por uso**; crédito
  pré-pago só em último caso e com aviso prévio ao operador. Fluxo (rebase→resolver→re-push; check vermelho→ler log→corrigir→re-push),
  dentro do teto de tentativas (regra das 6 tentativas). Erro irreparável/HUMAN_DOMAIN → escala
  com a linha de status + o próximo passo resumível.

## Como funciona (fluxo)
```text
agente escreve arquivos → dispara git-cycle-sentinel "<theme>" --scope <globs>
      │  Fase 1 STAGE     → scoped-add (nunca -A), gitleaks, status -sb limpo
      │  Fase 2 WORKTREE  → preflight fail-closed → worktree-policy/worktree-gate.sh → anti-conflict
      │  Fase 3 PR-CYCLE  → LÊ ruleset → classifica forte/fraco → commit assinado → PR (se forte)
      │  Fase 4 MERGE     → rebase+retry (base móvel) → push refspec-literal → Merge Queue / mergify / hierarchical
      │  Fase 5 BOY-SCOUT → remove worktree+branch → ff-only sync raiz → triage Eisenhower
      ▼
   devolve ao agente: UMA linha de status  (+ ping só em HITL/decisão)
   emite exatamente UM marcador STOP como última linha do turno
```

## Overview — por que existe (não reimplementa nada)

A pesquisa `[[git-cycle-offloader-2026-10-21]]` mediu na fonte: a **cobertura** das 5 fases do
ciclo-git **já existe e é madura** no host (skills `worktree-policy` · `anti-conflict` ·
`hierarchical-merge` · `sync-to-git` + `ship`/`pr` do gstack + hooks de governança GaaS + o CLI
`gt`). O que **não** existe é um disparo único que tire o ciclo do **contexto do agente** — hoje o
agente gasta tokens/contexto acionando cada passo. O veredito (sobrevivente à re-validação) foi:
**declarar-existente + WRAP fino híbrido**, nunca build do zero, nunca buy de produto único.

`git-cycle-sentinel` é esse wrap. Ele **orquestra o que já existe** atrás de um disparo
(preferencialmente assíncrono) e devolve ao agente **uma linha de status** no lugar de um ciclo
inteiro. Ele **reimplementa nada**: cada fase delega a um primitivo que já está no repo/host.

## Delegação (cita — NÃO reimplementa)
| Fase | Delega a (primitivo que já existe) |
|---|---|
| STAGE | `ship`/`pr` (gstack) · gitleaks local · `corpus-git-persistence-discipline` (regra) |
| WORKTREE | `worktree-policy` v1.1.0 · `plugin-scripts/governance/worktree-gate.sh` · `anti-conflict` v3.2.0 · `using-git-worktrees` · `preflight` |
| PR-CYCLE | `gh api` (ruleset) · `pr-review-protocol` · `ai-code-review-bots-rotation` · `question-then-correct` |
| MERGE | **GitHub Merge Queue** · `mergify-merge-queue`/`mergify-merge-protections` · `hierarchical-merge` v1.0.0 · `resolving-merge-conflicts` · `definition-of-well-done` |
| BOY-SCOUT | `sync-to-git` v1.0.0 · `ship` · `careful` (guardrails destrutivos) · `postflight` P1 SWEEP |

> **Anti-NIH**: a sentinela **emite invocações** desses primitivos; nunca inlina a lógica deles.
> Um primitivo opcional ausente degrada para o guardrail em software com um diagnóstico de 1 linha
> — nunca uma falha dura. `--dry-run` prova: um grep do run confirma só delegação + leitura de
> estado, zero reimplementação.
