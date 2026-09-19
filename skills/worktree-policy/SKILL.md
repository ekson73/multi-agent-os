---
name: worktree-policy
description: Enforce mandatory git worktree usage for multi-agent file modifications
version: 1.1.0
---

# Worktree Policy Skill

## Purpose

Enforce the mandatory use of git worktrees for all file modifications in multi-agent environments. Worktrees provide complete isolation between agents working on different features.

## When to Use

- Before any file modification
- When starting a new task
- When another agent is already working
- Before editing protected files

## Trigger Phrases

- "edit this file"
- "modify the code"
- "update the document"
- "make changes to"

## Core Rule

```
WORKTREE IS MANDATORY FOR ALL FILE MODIFICATIONS
Overhead: ~3 seconds | Benefit: Complete isolation
```

## Valid Exceptions (Only 3)

1. **READ-ONLY**: Analysis without file modification
2. **APPEND-ONLY**: tasks.md, sessions.json (add lines only)
3. **USER EXPLICIT REQUEST**: Documented in tasks.md

## Worktree Commands

### Create Worktree
```bash
# A base e RESOLVIDA e VALIDADA -- criar do HEAD atual herdaria commits
# alheios da branch em que o repo principal por acaso estiver.
BASE_REF="${BASE_REF_OVERRIDE:-$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)}"
git ls-remote --exit-code --heads origin "$BASE_REF" >/dev/null \
  || { echo "fail-closed: base '$BASE_REF' nao existe em origin" >&2; exit 1; }
git fetch -q origin "$BASE_REF"

git worktree add .worktrees/{agent-hex}-{feature} -b {tipo}/{name} "origin/$BASE_REF"
cd .worktrees/{agent-hex}-{feature}

# PERSISTIR: variavel de shell nao sobrevive entre steps; a revisao local e a
# criacao do PR dependem desta base.
printf '%s\n' "$BASE_REF" > "$(git rev-parse --git-dir)/BASE_REF"
```

### List Worktrees
```bash
git worktree list
```

### Remove Worktree

⛔ **`rm -rf` NAO e remocao de worktree** — ignora toda checagem do git e apaga
WIP nao commitado (inclusive de outra sessao) sem aviso. Numa politica cujo
proposito e isolar agentes concorrentes, e a contradicao direta.

A remocao segura exige 4 guardas ANTES de destruir: PR `MERGED` · worktree
resolvido pelo REGISTRO (nunca por template) · `status --porcelain
--untracked-files=all --ignored` vazio · ponta == `headRefOid` do PR.

```bash
# Procedimento canonico e completo: rules/pr-governance-unified.md Step 12.
# Resumo seguro, DEPOIS das 4 guardas:
git worktree remove "$WT_REAL"   # sem --force; worktree sujo e fail-closed

# ⚠️ A delecao precisa ser ATOMICA. Num run multi-agente outra sessao pode
# avancar `refs/heads/$BRANCH` DEPOIS das guardas (que nao sao atomicas), e
# `git branch -D` apagaria esse commit. `update-ref -d <ref> <old>` so remove
# se a ref ainda valer o esperado; caso contrario recusa e preserva.
git update-ref -d "refs/heads/$BRANCH" "$MERGED_OID" || {
  echo "fail-closed: '$BRANCH' avancou durante a limpeza — preservada" >&2
  exit 1; }
```

## Naming Standards

### Directory
```
.worktrees/{agent-short}-{feature-kebab}/
```

### Branch
```
{tipo}/{escopo}-{agent-hex}
```

| Type | Use |
|------|-----|
| `feature/` | New functionality |
| `bugfix/` | Bug correction |
| `hotfix/` | Urgent fix |
| `docs/` | Documentation |
| `refactor/` | Refactoring |
| `chore/` | Maintenance |

## Lifecycle

```
CREATE → WORK → VALIDATE QA → MERGE → CLEANUP
```

## Retention Policy

⛔ **Tempo decorrido NAO autoriza remocao.** Um worktree antigo pode conter trabalho
nao commitado ou ignorado de outra sessao; apaga-lo por prazo e perda de dados
disfarcada de higiene. Os prazos abaixo disparam REVISAO, nunca destruicao
automatica -- a remocao continua condicionada as 4 guardas do Step 12.

| Evento | Acao | Prazo |
|--------|------|-------|
| PR merged | Elegivel a cleanup guardado (Step 12) | 24h |
| Tarefa concluida | Elegivel a cleanup guardado (Step 12) | 72h |
| Worktree parece stale | REVISAR: de quem e? ha WIP/ignorados? | imediato |
| Maximo absoluto | ESCALAR ao dono, com inventario do conteudo | 7 dias |

No maximo absoluto a acao e **escalar**, nao forcar: liste o que ha dentro
(`status --porcelain --untracked-files=all --ignored`) e devolva a decisao a quem
criou o worktree. Se o dono nao responder, o conteudo e preservado -- nunca
descartado por prazo.

## Enforcement

If you are editing a file without being in a worktree:
1. STOP immediately
2. Create worktree
3. Continue from there

---

*Skill based on Worktree Policy v1.1 | multi-agent-os*
