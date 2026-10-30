---
name: git-cycle-sentinel
description: Rode o ciclo-git completo (add · worktree · pr-cycle · merge · boy-scout) como processo autônomo — o agente só SALVA, a sentinela cicla; repo-aware, idempotente, nunca regride assinatura, nunca --no-verify com pre-commit
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
| **2 WORKTREE** | preflight fail-closed · raiz nunca é worktree · branch `agent/<owner>-<theme>` | `worktree-policy` · `worktree-gate.sh` · `anti-conflict` |
| **3 PR-CYCLE** | **lê o ruleset ANTES de empurrar** → classifica forte/fraco → commit assinado → PR (se forte) | `gh api` · `pr-review-protocol` · `ai-code-review-bots-rotation` |
| **4 MERGE** | rebase+retry (base móvel) → push refspec-literal → **Merge Queue** / mergify / hierarchical | `hierarchical-merge` · `mergify-*` · `definition-of-well-done` |
| **5 BOY-SCOUT** | remove worktree+branch → `ff-only` sync da raiz → triage Eisenhower | `sync-to-git` · `ship` · `careful` |

## Comportamento (obedece-ou-supre, nunca regride)

- **Portão forte → obedece** (ruleset com `pull_request`/checks/assinatura, ex. vkl): abre PR,
  espera checks strict, resolve threads, assina, nunca `--no-verify`.
- **Portão fraco → supre** (os outros repos): no-direct-main, scoped-add, gitleaks, worktree em
  software.
- **Nunca regride assinatura** (A4): assina onde o repo assina/exige; não força onde `gpgsign=false`.
- **Idempotente** (A7): re-execução não duplica commit/PR/comentário (`idempotency_key`).
- **Self-heal**: passo script que falha (rebase/push/check) é despachado a um ai-harness para
  resolver, dentro do teto de 6 tentativas; irreparável/HUMAN_DOMAIN → escala com a linha de status.

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
repo      ekson73/multi-agent-os   gate  weak(local-GaaS)   model  trunk
signed    false(gpgsign=false — não forçado)   worktree  agent/owner-theme
push      refspec-literal OK       merge  merge-queue → enfileirado
pr        #123                     status CYCLED
─────────────────────────────────────────────────
<!--ORCH-STATUS: STOP-DONE -->
```

## Integration

- Skill: [`skills/git-cycle-sentinel/SKILL.md`](../skills/git-cycle-sentinel/SKILL.md) (o orquestrador).
- Genesis: `skills/agentic-tool-pipeline` → `skills/agentic-tool-forge` + `skills/anima`.
- Composes (delega, não reimplementa): `worktree-policy` · `anti-conflict` · `hierarchical-merge` ·
  `sync-to-git` · `plugin-scripts/governance/worktree-gate.sh` · GitHub Merge Queue / `mergify-*`.
- SSOT da norma: `[[git-cycle-norma-harmonizada-2026-10-21]]` · `[[git-cycle-offloader-2026-10-21]]` (EKO-154).
