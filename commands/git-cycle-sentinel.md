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

> Surfaces at runtime as `/maos:git-cycle-sentinel` (Sandwich Namespacing per `.claude-plugin/plugin.json`).
> Naming: Anima-named (`git-cycle-sentinel`; rejected runner-up `git-cycle-offloader` — "offloader"
> implicaria VM remota, drift epistemológico). Operador pode sobrescrever (`[C-naming]`).

## Usage

```
/git-cycle-sentinel [--repo <path>] --scope <globs> --theme <slug> [--async] [--merge-engine <e>] [--dry-run] [--json]
```

## O que faz (as 5 fases da norma harmonizada)

| Fase | Ação | Delega a |
|------|------|----------|
| **1 STAGE** | scoped-add (nunca `-A` cego) · gitleaks · `status -sb` limpo | `ship`/`pr` · `corpus-git-persistence-discipline` |
| **2 WORKTREE** | preflight fail-closed · raiz fora da default segue em worktree nova a partir de `origin/<default>` · branch `agent/<owner>-<theme>` | `worktree-policy` · `worktree-gate.sh` · `anti-conflict` |
| **3 PR-CYCLE** | **une** proteção clássica + rulesets ANTES de empurrar → classifica (PR obrigatório · checks · ator contorna) → commit com assinatura verificada no ambiente → PR (se forte) | `gh api` · `pr-review-protocol` · `ai-code-review-bots-rotation` |
| **4 MERGE** | rebase+retry (base móvel) → push refspec-literal → merge só com `--match-head-commit` (checks verdes, zero thread; portão desconhecido bloqueia) → **Merge Queue** / mergify / hierarchical | `hierarchical-merge` · `mergify-*` · `definition-of-well-done` |
| **5 BOY-SCOUT** | remove worktree+branch → `ff-only` sync da raiz → triage Eisenhower | `sync-to-git` · `ship` · `careful` |

## Comportamento (obedece-ou-supre, nunca regride)

- **Portão lido pela união** da proteção clássica com os rulesets (a regra mais restritiva vence),
  antes de empurrar. 403, 5xx, timeout ou outro erro conta como **desconhecido** e bloqueia o merge
  autônomo; um 404 sozinho não prova portão fraco. Exemplo de repo: `owner/repo`.
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
- **Merge preso ao SHA**: só com `--match-head-commit`, checks obrigatórios verdes e zero thread
  aberta. A linha de status cita o SHA do head e o SHA do merge. Portão desconhecido nunca mescla
  sozinho. Decisão técnica é autônoma; política, credenciais, gastos, irreversível, produção e
  ampliação de acesso exigem aprovação explícita do humano dono.
- **Force-push**: nunca na branch default. Em branch, só na criada pelo próprio agente e com
  `--force-with-lease`.
- **Contas**: contas de outro domínio ou organização não aprovam nem atuam.
- **Idempotente** (A7): re-execução não duplica commit/PR/comentário (`idempotency_key`).
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
push      refspec-literal OK       merge  --match-head-commit (checks verdes, zero thread)
pr        #123                     head <sha>  merge <sha>  status CYCLED
─────────────────────────────────────────────────
<!--ORCH-STATUS: STOP-DONE -->
```

## Integration

- Skill: [`skills/git-cycle-sentinel/SKILL.md`](../skills/git-cycle-sentinel/SKILL.md) (o orquestrador, v0.2.0).
- Harness com agente de nuvem: o agente de nuvem cria a branch, commita, empurra e abre o PR; o
  coordenador verifica, decide o merge amarrado ao head e não faz checkout local.
- Genesis: `skills/agentic-tool-pipeline` → `skills/agentic-tool-forge` + `skills/anima`.
- Composes (delega, não reimplementa): `worktree-policy` · `anti-conflict` · `hierarchical-merge` ·
  `sync-to-git` · `plugin-scripts/governance/worktree-gate.sh` · GitHub Merge Queue / `mergify-*`.
- SSOT da norma: `[[git-cycle-norma-harmonizada-2026-10-21]]` · `[[git-cycle-offloader-2026-10-21]]` (EKO-154).
