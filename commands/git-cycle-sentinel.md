---
name: git-cycle-sentinel
description: Rode o ciclo-git completo (add · worktree · pr-cycle · merge · boy-scout) como processo autônomo — o agente só SALVA, a sentinela cicla; repo-aware, idempotente; gate não se pula (sem dismiss, sem --no-verify, sem --admin, sem bypass de assinatura); merge só com --match-head-commit
---

# /git-cycle-sentinel Command

Dispara a **sentinela do ciclo-git**: o agente apenas **salva** (escreve arquivos no FS) e a
sentinela roda o ciclo-git completo (stage scoped → worktree isolado → commit assinado → push
refspec-literal → PR → fila de merge → boy-scout) como **processo autônomo**, devolvendo ao
agente **uma linha de status** e pings apenas quando precisa de uma decisão. Thin entry point
sobre a [`git-cycle-sentinel` skill](../skills/git-cycle-sentinel/SKILL.md).

> Surfaces at runtime as `/<plugin>:git-cycle-sentinel` (namespace do plugin, declarado em `.claude-plugin/plugin.json`).
> Naming: nome dado pelo agente de nomeação do projeto (`git-cycle-sentinel`; rejected runner-up `git-cycle-offloader` — "offloader"
> implicaria VM remota, drift epistemológico). Operador pode sobrescrever (`[C-naming]`).

## Usage

```
/git-cycle-sentinel [--repo <path>] --scope <globs> --theme <slug> [--async] [--merge-engine <e>] [--dry-run] [--json]
```

## O que faz (as 5 fases da norma harmonizada)

| Fase | Ação | Delega a |
|------|------|----------|
| **1 STAGE** | scoped-add (nunca `-A` cego) · gitleaks · `status -sb` limpo | `ship`/`pr` · `corpus-git-persistence-discipline` |
| **2 WORKTREE** | preflight fail-closed · raiz fora da default segue em worktree nova a partir de `origin/<default>` · `.githooks/` com `core.hooksPath` vazio vira config local · pre-commit explícito antes do commit · branch `agent/<owner>-<theme>` | `worktree-policy` · `worktree-gate.sh` · `anti-conflict` |
| **3 PR-CYCLE** | **une** proteção clássica + rulesets (403 estrito = desconhecido, sem forte-parcial) → classifica (PR · checks · ator contorna) → lê automações que mesclam → commit assinado + trailer `idmp: <theme>-<repo>-<YYYYMMDD>` → PR; [NÃO MESCLAR] abre rascunho com `do-not-merge` | `gh api` · `pr-review-protocol` · `ai-code-review-bots-rotation` · `converge` |
| **4 MERGE** | update-branch por rebase se histórico linear · merge só com `--match-head-commit` (checks verdes, zero thread, `APPROVED` justificado, sem refutação aberta, sem [NÃO MESCLAR], sem conta proibida; desconhecido bloqueia) → **Merge Queue** / mergify / hierarchical | `hierarchical-merge` · `mergify-*` · `definition-of-well-done` · `converge` |
| **5 BOY-SCOUT** | remove worktree+branch → `ff-only` sync da raiz → triage Eisenhower | `sync-to-git` · `ship` · `careful` |

## Comportamento (obedece-ou-supre, nunca regride)

- **Portão lido pela união** da proteção clássica com os rulesets (a regra mais restritiva vence),
  antes de empurrar. 403, 5xx, timeout ou outro erro conta como **desconhecido**. **Regra estrita
  do 403**: sem leitura da proteção clássica não há merge autônomo e não existe "forte-parcial"; o
  resumo `branches/<b>` só lista checks a esperar e nunca libera merge. Um 404 sozinho não prova
  portão fraco. Exemplo de repo: `owner/repo`.
- **Classificação** em três eixos: PR obrigatório, checks obrigatórios, e se o ator consegue
  contornar. Forte = os três, sem contorno (proteção clássica com as mesmas regras equivale a
  ruleset). Fraco para o ator **não libera nada**: sem `--admin`, sem bypass, sem push direto na base.
- **Gate não se pula**: sem dismiss de review, sem pular check obrigatório, sem `--no-verify`, sem
  bypass de assinatura (inclusive temporário), sem `gh pr merge --admin`.
- **Assinatura verificada de fato** no ambiente que commita. Onde o repo exige e o ambiente não
  assina, não commita dali. Não regride e não força onde `gpgsign=false`.
- **Preflight**: raiz fora da default (outra branch, HEAD destacado, worktrees anexadas) não é
  trocada nem limpa. O trabalho segue numa worktree nova a partir de `origin/<default>`, preservando
  o que está na raiz.
- **`.githooks`**: em clone novo, no preflight, se o diretório existe e `core.hooksPath` não está
  definido, ativar com `git config core.hooksPath .githooks` (config local). Husky, pre-commit ou
  outro hooksPath existente é respeitado.
- **Pre-commit explícito**: depois do stage, rodar o hook e só commitar com saída 0
  (`.githooks/pre-commit`, `pre-commit run` ou `.husky/pre-commit`). Falha vai para self-heal, nunca
  para contorno.
- **Merge preso ao SHA**: só com `--match-head-commit`, checks obrigatórios verdes, zero thread
  aberta, `APPROVED` justificado de aprovador que está no registro do projeto, sem refutação justificada em
  aberto, sem marcador [NÃO MESCLAR] nem label `do-not-merge`, e sem conta proibida no portão. A
  linha de status cita o SHA do head e o SHA do merge. Portão desconhecido nunca mescla sozinho.
  Decisão técnica é autônoma; política, credenciais, gastos, irreversível, produção e ampliação de
  acesso exigem aprovação explícita do humano dono.
- **Update-branch**: com histórico linear exigido, nunca por merge. Usar
  `gh pr update-branch --rebase` (só na branch própria, pela regra de force-push) ou não atualizar.
- **[NÃO MESCLAR]**: PR de teste ou marcado abre como rascunho, com label `do-not-merge` e sem
  auto-merge. O merge é recusado com o marcador no título ou com a label. Automação que possa
  mesclar ignorando isso → fechar o PR após o teste.
- **Automações que mesclam**: lidas, sem mutar (fila de merge, `allow_auto_merge`, Mergify, apps de
  aprovação, bots e workflows que chamem `gh pr merge`). Registradas em `merge_automations`.
- **Aprovação**: o registro de aprovadores capacitados é artefato do projeto (`login`, `id`,
  `type: Bot`). Quem não está nele não conta, e projeto sem registro não tem aprovador
  (`STOP-HITL`). A lista de contas proibidas prevalece. A sentinela lê o registro e não o edita.
  `APPROVED` com corpo vazio não conta sem um comentário de justificativa da mesma conta vinculado
  ao SHA do head. Revisor que só comenta não fecha o ciclo. Revisor sem cota, com rate limit ou que
  não completou a revisão não conta, mesmo com check "pass"/"success".
- **Refutação**: uma refutação justificada e em aberto bloqueia o merge até convergência unânime
  registrada no PR (`skills/converge/SKILL.md`). Maioria ou limiar não bastam.
- **Force-push**: nunca na branch default. Em branch, só na criada pelo próprio agente e com
  `--force-with-lease`.
- **Contas**: contas de outro domínio ou organização não aprovam nem atuam. Conta proibida (lista
  fora do repo) não é usada, pedida como reviewer nem posta em allowlist, `CODEOWNERS` ou workflow.
  Se aparecer no repo, bloqueia **só o merge autônomo**; branch, commit e PR seguem. Se o pedido
  contradiz a lista, a lista vence e o caso vai para `STOP-HITL`.
- **Idempotente** (A7): trailer canônico `idmp: <theme>-<repo>-<YYYYMMDD>` (com espaço); a leitura
  também aceita a forma sem espaço. Marcador de PR e comentário:
  `<!--idmp:<theme>-<repo>-<YYYYMMDD>-->`. Re-execução não duplica commit, PR nem comentário.
- **Self-heal**: harness só por assinatura já paga, sem chave de API cobrada por uso, teto de 6
  tentativas. Irreparável ou HUMAN_DOMAIN escala com a linha de status.
- **Processos**: encerra só pelo PID que ela mesma iniciou ou pela própria porta.

## Exemplos

```
/git-cycle-sentinel --scope "src/**" --theme fix-login          # ciclo completo, async, repo atual
/git-cycle-sentinel --scope "docs/x.md" --theme docs --dry-run  # preflight + classifica repo + plano (não muta)
/git-cycle-sentinel --merge-engine merge-queue --theme feat-y   # força a GitHub Merge Queue como motor
```

## Output

```
🛡️  git-cycle-sentinel
─────────────────────────────────────────────────
repo      owner/repo               gate  strong|weak|unknown   model  trunk
signed    verified-in-env          worktree  agent/owner-theme
push      refspec-literal OK       merge  --match-head-commit (APPROVED justificado, sem refutação)
version   0.2.0                    body_sha256  <sha do corpo>
pr        #<n>                     head <sha>  merge <sha>  idmp theme-repo-YYYYMMDD  status CYCLED
─────────────────────────────────────────────────
<!--ORCH-STATUS: STOP-DONE -->
```

## Integration

- Skill: [`skills/git-cycle-sentinel/SKILL.md`](../skills/git-cycle-sentinel/SKILL.md) (o orquestrador, v0.2.0, pai único).
  Detalhes sob demanda: [`references/mecanica.md`](../skills/git-cycle-sentinel/references/mecanica.md) e
  [`references/rastreabilidade.md`](../skills/git-cycle-sentinel/references/rastreabilidade.md).
- Overlay por repo: seção `## git-cycle` no `AGENTS.md` (ou no `CONTRIBUTING.md`; só sem os dois,
  `.github/git-cycle.md`), com sete chaves fechadas (inclui `aprovacoes_minimas`, que só sobe);
  aperta, nunca afrouxa o piso da skill; afrouxamento ou chave desconhecida gera aviso, e afrouxamento
  vira `STOP-HITL` antes do merge.
- Push em lote (P7): commits locais agrupados e push por lote, para não disparar os revisores
  automáticos a cada commit.
- Quem pode o quê: o executor de código clona no ambiente de execução, cria a branch, commita,
  empurra e abre o PR. O coordenador sem credencial própria lê o portão, comenta, rotula e pode
  mesclar PR técnico se os guardrails passarem, pelo conector, e pede ao executor o que mutar.
  Ninguém faz checkout nas máquinas do usuário. `--admin`, dismiss, `--no-verify` e bypass de
  assinatura são nunca. A tabela completa está na skill.
- Convergência de refutação: [`skills/converge/SKILL.md`](../skills/converge/SKILL.md).
- Genesis: skill de pipeline de ferramentas agênticas do projeto (método e autoria) + agente de nomeação do projeto (nome).
- Composes (delega, não reimplementa): `worktree-policy` · `anti-conflict` · `hierarchical-merge` ·
  `sync-to-git` · `plugin-scripts/governance/worktree-gate.sh` · GitHub Merge Queue / `mergify-*`.
- SSOT da norma: `[[git-cycle-norma-harmonizada-2026-10-21]]` · `[[git-cycle-offloader-2026-10-21]]` (notas de pesquisa no vault de conhecimento do mantenedor, fora do repo).
