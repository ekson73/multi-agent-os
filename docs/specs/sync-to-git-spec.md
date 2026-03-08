# sync-to-git Skill Specification

> **Version**: 1.0.0 (2026-01-23)
> **Status**: Draft
> **Author**: Claude-Code
> **Category**: claude-skill

## Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│  sync-to-git: Automação de sincronização Git para AI Agents           │
├────────────────────────────────────────────────────────────────────────┤
│  OBJETIVO: Coordenar operações Git entre local e remotes              │
│  SCOPE: fetch, pull, push, commit, branches, worktrees, PRs, merge    │
│  TARGET: GitHub, Bitbucket (extensível para GitLab)                   │
│  INTEGRATION: C04 (Git Worktree Protocol), C07 (PR Review Protocol)   │
└────────────────────────────────────────────────────────────────────────┘
```

## Problema

AI Agents executando em paralelo precisam:
1. Sincronizar estado do repositório antes de iniciar trabalho
2. Verificar conflitos potenciais com outros agentes
3. Fazer push de alterações sem impactar sessões paralelas
4. Criar PRs seguindo protocolo corporativo
5. Verificar status de PRs e reviews

**Sem padronização**, cada agente implementa lógica própria → inconsistência, conflitos, falhas.

## Solução

Um skill Claude Code que:
1. Abstrai operações Git complexas em comandos semânticos
2. Integra com protocolos existentes (C04, C07)
3. Suporta múltiplos remotes (GitHub, Bitbucket)
4. Fornece output estruturado (MCP-JSON-RPC)
5. Implementa gates de segurança (branch protection, dry-run)

## Arquitetura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         sync-to-git Skill                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │
│  │   COMMANDS   │  │    GATES     │  │   OUTPUT     │                   │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤                   │
│  │ sync-status  │  │ branch-gate  │  │ JSON-RPC     │                   │
│  │ sync-fetch   │  │ worktree-chk │  │ manifest     │                   │
│  │ sync-pull    │  │ conflict-det │  │ audit-log    │                   │
│  │ sync-push    │  │ pr-status    │  │ human-msg    │                   │
│  │ sync-commit  │  │ review-wait  │  │              │                   │
│  │ sync-pr      │  │              │  │              │                   │
│  │ sync-merge   │  │              │  │              │                   │
│  └──────────────┘  └──────────────┘  └──────────────┘                   │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                      CONFIGURATION                                 │ │
│  │  .sync-git.env | git config | CLI flags                            │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Comandos

### 1. sync-status

Verifica estado atual do repositório e remotes.

```bash
sync-to-git status [--json] [--remote <name>]
```

**Output:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "branch": "feat/my-feature",
    "is_worktree": true,
    "worktree_path": ".worktrees/my-feature",
    "parent_branch": "main",
    "ahead": 3,
    "behind": 0,
    "uncommitted": 2,
    "untracked": 1,
    "remote": "origin",
    "remote_url": "git@github.com:org/repo.git",
    "provider": "github",
    "last_fetch": "2026-01-23T10:30:00-03:00"
  }
}
```

### 2. sync-fetch

Busca alterações dos remotes sem aplicar.

```bash
sync-to-git fetch [--all] [--prune] [--json]
```

### 3. sync-pull

Atualiza branch local com remote.

```bash
sync-to-git pull [--rebase] [--no-rebase] [--json]
```

**Gates:**
- Verifica se há uncommitted changes
- Verifica se está em worktree (usa parent se necessário)
- Detecta conflitos potenciais

### 4. sync-push

Envia alterações para remote.

```bash
sync-to-git push [--force-with-lease] [--set-upstream] [--json]
```

**Gates:**
- NUNCA push --force para branches protegidas (main, master, develop)
- Verifica se branch existe no remote
- Valida que não há conflitos

### 5. sync-commit

Cria commit seguindo padrões.

```bash
sync-to-git commit -m "tipo(escopo): descrição" [--co-author] [--json]
```

**Features:**
- Adiciona Co-Author automaticamente
- Valida Conventional Commits
- Verifica se há staged changes

### 6. sync-pr

Cria Pull Request.

```bash
sync-to-git pr create --title "titulo" --body "corpo" [--base <branch>] [--json]
sync-to-git pr status [--json]
sync-to-git pr reviews [--json]
```

**Integração C07:**
- Não permite merge direto (apenas via PR)
- Aguarda revisão (TTL configurável)
- Analisa comentários de review

### 7. sync-merge

Executa merge após aprovação.

```bash
sync-to-git merge [--squash] [--no-ff] [--json]
```

**Gates:**
- Verifica PR aprovado
- Verifica CI passou
- Verifica reviews resolvidas

## Configuração

### .sync-git.env

```bash
# Remote Configuration
SYNC_GIT_REMOTE=origin
SYNC_GIT_PROVIDER=github  # github | bitbucket | gitlab

# Branch Protection
SYNC_GIT_PROTECTED_BRANCHES=main,master,develop,release/*
SYNC_GIT_DEFAULT_BASE=main

# PR Configuration
SYNC_GIT_PR_TEMPLATE=.github/PULL_REQUEST_TEMPLATE.md
SYNC_GIT_PR_REVIEWERS=@team/devs
SYNC_GIT_PR_LABELS=ai-generated

# Review Protocol (C07)
SYNC_GIT_REVIEW_TTL_MINUTES=30
SYNC_GIT_AUTO_DELEGATE_REVIEWER=true
SYNC_GIT_REVIEWER_AGENT=code-reviewer

# Commit Configuration
SYNC_GIT_CO_AUTHOR="Claude Opus 4.5 <noreply@anthropic.com>"
SYNC_GIT_CONVENTIONAL_COMMITS=true

# Worktree Integration (C04)
SYNC_GIT_ENFORCE_WORKTREE=true
SYNC_GIT_WORKTREE_DIR=.worktrees

# Output Configuration
SYNC_GIT_JSON_OUTPUT=false
SYNC_GIT_VERBOSE=false
SYNC_GIT_DRY_RUN=false

# Manifest
SYNC_GIT_MANIFEST_DIR=.sync/manifests
SYNC_GIT_MANIFEST_ENABLED=true
```

### git config integration

```bash
git config --local sync.git.remote origin
git config --local sync.git.protected-branches "main,master"
git config --global sync.git.co-author "Claude Opus 4.5 <noreply@anthropic.com>"
```

## Gates de Segurança

### 1. Branch Gate

```
┌────────────────────────────────────────────────────────────────────────┐
│  BRANCH GATE: Previne operações destrutivas em branches protegidas    │
├────────────────────────────────────────────────────────────────────────┤
│  push --force     → BLOQUEADO em main/master/develop                  │
│  merge direto     → BLOQUEADO (requer PR)                             │
│  delete branch    → BLOQUEADO em protegidas                           │
│  rebase           → WARNING se publicada                              │
└────────────────────────────────────────────────────────────────────────┘
```

### 2. Worktree Gate

```
┌────────────────────────────────────────────────────────────────────────┐
│  WORKTREE GATE: Integração com C04                                    │
├────────────────────────────────────────────────────────────────────────┤
│  Se SYNC_GIT_ENFORCE_WORKTREE=true:                                   │
│  - Verifica se operação está em worktree                              │
│  - Se no repo principal → ERROR com instrução para criar worktree     │
│  - Se em worktree → procede normalmente                               │
└────────────────────────────────────────────────────────────────────────┘
```

### 3. Conflict Detection Gate

```
┌────────────────────────────────────────────────────────────────────────┐
│  CONFLICT GATE: Detecta conflitos antes de operações                  │
├────────────────────────────────────────────────────────────────────────┤
│  Antes de pull/merge:                                                 │
│  1. fetch silencioso                                                  │
│  2. git merge-base + diff                                             │
│  3. Se conflito detectado → WARNING + arquivos listados               │
│  4. Se --force → procede; senão → BLOQUEADO                           │
└────────────────────────────────────────────────────────────────────────┘
```

### 4. PR Status Gate

```
┌────────────────────────────────────────────────────────────────────────┐
│  PR STATUS GATE: Integração com C07                                   │
├────────────────────────────────────────────────────────────────────────┤
│  Antes de merge:                                                      │
│  1. Verifica se PR existe                                             │
│  2. Verifica se reviews foram feitas                                  │
│  3. Verifica se CI passou                                             │
│  4. Verifica se não há conflitos                                      │
│  5. Se tudo OK → merge; senão → instrução específica                  │
└────────────────────────────────────────────────────────────────────────┘
```

## Error Handling (MCP-JSON-RPC)

Seguindo padrão C06:

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32010,
    "message": "Branch protection violation",
    "data": {
      "details": "Cannot push --force to protected branch 'main'",
      "instructions": "Use: sync-to-git push (without --force) OR create PR",
      "context": "branch-gate"
    }
  }
}
```

### Códigos de Erro Específicos

| Code | Name | Recovery |
|------|------|----------|
| -32010 | Branch protection | Remover --force ou usar PR |
| -32011 | Worktree required | Criar worktree: `git worktree add .worktrees/{name}` |
| -32012 | Conflict detected | Resolver conflitos manualmente |
| -32013 | Uncommitted changes | Commit ou stash antes |
| -32014 | PR not found | Criar PR primeiro |
| -32015 | Review pending | Aguardar revisão ou delegar |
| -32016 | CI failed | Corrigir falhas de CI |
| -32017 | Remote unavailable | Verificar conexão/credenciais |

## Manifest

Cada operação gera entrada no manifest:

```json
{
  "operation": "push",
  "timestamp": "2026-01-23T10:30:00-03:00",
  "agent": "Claude-Code",
  "session_id": "abc123",
  "branch": "feat/my-feature",
  "worktree": ".worktrees/my-feature",
  "commit_hash": "a1b2c3d",
  "remote": "origin",
  "result": "success",
  "details": {
    "ahead_before": 3,
    "ahead_after": 0
  }
}
```

## Integração com Protocolos

### C04 (Git Worktree Protocol)

- Verifica se operação está em worktree
- Respeita merge hierárquico (worktree → parent → main)
- Não troca branch no repo principal (REGRA 7)

### C07 (PR Review Protocol)

- Cria PR automaticamente após push
- Aguarda revisão com TTL
- Analisa feedback de reviewers
- Delega para code-reviewer se timeout

## Implementação

### Estrutura de Arquivos

```
~/.claude/
├── skills/
│   └── sync-to-git/
│       └── SKILL.md          # Frontmatter + instruções
├── commands/
│   └── sync-to-git.md        # Slash command
└── docs/
    └── specs/
        └── sync-to-git-spec.md  # Esta especificação
```

### SKILL.md Template

```yaml
---
name: sync-to-git
version: 1.0.0
description: Git synchronization automation for AI agents
triggers:
  - sync git
  - git sync
  - push changes
  - create pr
  - check pr status
tools:
  - Bash
  - Read
  - Write
---

# sync-to-git Skill

[Instruções detalhadas para o agente...]
```

## CLI Reference

```
sync-to-git - Git synchronization automation for AI agents

USAGE:
  sync-to-git <command> [options]

COMMANDS:
  status              Show repository sync status
  fetch               Fetch changes from remote
  pull                Pull changes from remote
  push                Push changes to remote
  commit              Create commit with standards
  pr create           Create pull request
  pr status           Check PR status
  pr reviews          List PR reviews
  merge               Merge after approval

GLOBAL OPTIONS:
  --json              Output in JSON-RPC format
  --dry-run           Preview without executing
  --verbose           Show detailed output
  --force             Bypass safety gates (use with caution)
  --config <file>     Use custom config file

EXAMPLES:
  sync-to-git status --json
  sync-to-git push --set-upstream
  sync-to-git pr create --title "feat: new feature"
  sync-to-git merge --squash
```

## Roadmap

### v1.0.0 (MVP)
- [x] Spec completa
- [ ] Implementar comandos básicos (status, fetch, pull, push)
- [ ] Gates de segurança (branch, worktree)
- [ ] Output JSON-RPC
- [ ] Integração C04

### v1.1.0
- [ ] Comandos PR (create, status, reviews)
- [ ] Integração C07
- [ ] Manifest

### v1.2.0
- [ ] Suporte Bitbucket
- [ ] Auto-merge após aprovação
- [ ] Métricas de sync

---

## Sources

- [GitHub Actions CI/CD](https://github.blog/enterprise-software/ci-cd/build-ci-cd-pipeline-github-actions-four-steps/)
- [Bitbucket Pipelines](https://bitbucket.org/product/features/pipelines)
- [git-worktree-runner](https://github.com/coderabbitai/git-worktree-runner)
- [Git Hooks for CI](https://www.atlassian.com/blog/git/git-hooks-for-continuous-integration)
- [Using Git Worktrees for Parallel AI Development](https://stevekinney.com/courses/ai-development/git-worktrees)

---

*Spec Version: 1.0.0 | Created: 2026-01-23 | Author: Claude-Code*
