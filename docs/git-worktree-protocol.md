# Git Worktrees para AI Agents — Protocolo Global

<!-- ═══════════════════════════════════════════════════════════════════════════
     PROTOCOLO GLOBAL: Git Worktrees para Multi-Agent Development

     Localização: ~/.claude/docs/git-worktree-protocol.md
     Escopo: Todos os repositórios do usuário
     Versão: 1.2.0 (adicionada REGRA 7: Nunca trocar branch)
     Criado: 2026-01-21
     Atualizado: 2026-01-23
     Autor: Claude-Code

     SOURCE OF TRUTH: Este documento é a versão global.
     Projetos específicos podem estender, mas não substituir estas regras.
     ═══════════════════════════════════════════════════════════════════════════ -->

---

## ⚠️ REGRA CRÍTICA — LER PRIMEIRO

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  ⛔ NUNCA FAZER git checkout/switch NO REPOSITÓRIO PRINCIPAL                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ❌ ERRADO:  git checkout feature/my-branch                                │
│  ❌ ERRADO:  git switch feature/my-branch                                  │
│                                                                             │
│  ✅ CORRETO: git worktree add .worktrees/my-feature -b feature/my-branch   │
│  ✅ CORRETO: cd .worktrees/my-feature                                      │
│                                                                             │
│  POR QUÊ?                                                                   │
│  • git checkout ALTERA todos os arquivos no working directory              │
│  • Múltiplos agentes COMPARTILHAM o mesmo repositório principal            │
│  • Trocar branch QUEBRA o trabalho de TODOS os outros agentes              │
│  • Worktrees são diretórios ISOLADOS — cada agente tem o seu               │
│                                                                             │
│  FLUXO CORRETO:                                                             │
│  1. Criar worktree:  git worktree add .worktrees/{name} -b {branch}        │
│  2. Entrar com cd:   cd .worktrees/{name}                                  │
│  3. Trabalhar:       [edit, commit, push - tudo DENTRO do worktree]        │
│  4. Sair com cd:     cd /path/to/repo                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Visão Geral

Git worktrees permitem checkout de múltiplas branches simultaneamente em diretórios separados, compartilhando o mesmo `.git`. Isso é essencial para:

1. **Isolamento**: Cada agente trabalha em seu próprio diretório
2. **Sem conflitos de arquivos**: Agentes não sobrescrevem trabalho um do outro
3. **Merge controlado**: Conflitos são resolvidos no momento do merge, não durante o trabalho
4. **Paths estáveis**: Cada worktree tem path fixo (não muda com branch switch)

---

## Estrutura Padrão para Repositórios

```
{repo}/
├── .worktrees/                        # Diretório de worktrees
│   ├── README.md                      # Documentação específica do repo
│   ├── tasks.md                       # Registro de tarefas por agente
│   ├── sessions.json                  # Registro de sessões ativas
│   ├── protected_files.json           # Manifest de arquivos protegidos
│   ├── session_lock.template.json     # Template para lock files
│   ├── {session-id}.lock              # Lock files ativos (dinâmicos)
│   └── {agent-name}-{feature}/        # Worktree por agente/feature
│       └── (cópia completa do repo)
└── ...
```

---

## Quando Usar Worktree (Regra Padrão)

```
┌────────────────────────────────────────────────────────────────────────┐
│  WORKTREE OBRIGATÓRIO — REGRA PADRÃO                                   │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ✓ TODAS as modificações de arquivos requerem worktree                │
│  ✓ Não existe "quick fix" — criação de worktree leva ~3 segundos      │
│  ✓ Estimativas temporais são imprecisas — não confiar em "<5 min"     │
│  ✓ Consistência > exceções condicionais                                │
│                                                                        │
│  Racional: Overhead mínimo (3s) com máxima segurança.                 │
│  "Quick fixes" frequentemente expandem além do esperado.               │
│                                                                        │
├────────────────────────────────────────────────────────────────────────┤
│  EXCEÇÕES VÁLIDAS — APENAS ESTAS 3                                     │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  1. READ-ONLY: Análise sem modificação de arquivos                    │
│     → Risco zero de conflito                                           │
│                                                                        │
│  2. APPEND-ONLY em coordination files (tasks.md, sessions.json)       │
│     → Projetados para acesso concorrente                               │
│     → Apenas adicionar linhas, nunca editar existentes                │
│                                                                        │
│  3. Solicitação EXPLÍCITA do usuário                                   │
│     → Documentar em tasks.md                                           │
│     → Autonomia do usuário prevalece                                   │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Guardrails de Integridade

```
┌────────────────────────────────────────────────────────────────────────┐
│  GUARDRAILS OBRIGATÓRIOS — PREVENÇÃO DE CONFLITOS                      │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  REGRA 1: UNICIDADE DE SESSÃO                                          │
│  ─────────────────────────────────────────────────────────────────────│
│  Um session_id DEVE aparecer em APENAS UM dos arrays:                  │
│  - active_sessions OU completed_sessions, NUNCA ambos                  │
│                                                                        │
│  REGRA 2: WORKTREE REAL                                                │
│  ─────────────────────────────────────────────────────────────────────│
│  worktree_path em sessions.json DEVE corresponder a um worktree real   │
│                                                                        │
│  REGRA 3: WORKTREE EXCLUSIVO                                           │
│  ─────────────────────────────────────────────────────────────────────│
│  Um worktree_path pode ser usado por NO MÁXIMO UMA sessão ativa        │
│                                                                        │
│  REGRA 4: CONSISTÊNCIA TEMPORAL                                        │
│  ─────────────────────────────────────────────────────────────────────│
│  completed_at DEVE ser posterior a started_at                          │
│  last_heartbeat NÃO pode ser posterior a completed_at                  │
│                                                                        │
│  REGRA 5: TRANSIÇÃO ATÔMICA                                            │
│  ─────────────────────────────────────────────────────────────────────│
│  Ao completar sessão:                                                  │
│  1. PRIMEIRO: Remover de active_sessions                               │
│  2. DEPOIS: Adicionar a completed_sessions                             │
│                                                                        │
│  REGRA 6: BRANCH-WORKTREE SYNC                                         │
│  ─────────────────────────────────────────────────────────────────────│
│  Se worktree foi removido, a branch associada deve ser avaliada:       │
│  - Merged? → Pode deletar branch                                       │
│  - Não merged? → Manter ou fazer backup antes de deletar               │
│                                                                        │
│  REGRA 7: NUNCA TROCAR BRANCH NO REPO PRINCIPAL (CRÍTICO!)            │
│  ─────────────────────────────────────────────────────────────────────│
│  ⚠️  PROIBIDO: git checkout <branch> no repositório principal          │
│  ⚠️  PROIBIDO: git switch <branch> no repositório principal            │
│                                                                        │
│  ✓  CORRETO: cd .worktrees/{agent}-{feature} (entrar no worktree)     │
│  ✓  CORRETO: cd .. ou cd /path/to/repo (sair do worktree)             │
│                                                                        │
│  RACIONAL:                                                             │
│  • Múltiplos agentes compartilham o mesmo repositório principal        │
│  • git checkout altera TODOS os arquivos no working directory          │
│  • Isso impacta TODAS as sessões de TODOS os agentes ativos           │
│  • Worktrees são checkouts ISOLADOS - cada um tem seu diretório       │
│                                                                        │
│  FLUXO CORRETO:                                                        │
│  1. git worktree add .worktrees/{name} -b {branch}                    │
│  2. cd .worktrees/{name}  ← ENTRAR com cd, não checkout               │
│  3. [trabalhar, commit, push]                                          │
│  4. cd /path/to/repo      ← SAIR com cd, não checkout                 │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Comandos Essenciais

### Criar Worktree

```bash
# Criar worktree para nova branch
git worktree add .worktrees/{agent}-{feature} -b {branch-name}

# Criar worktree para branch existente
git worktree add .worktrees/{agent}-{feature} {branch-name}
```

### Listar Worktrees

```bash
git worktree list
```

### Remover Worktree

```bash
# Remover diretório e limpar referências
rm -rf .worktrees/{agent}-{feature}
git worktree prune
```

### Atualizar Worktree

```bash
cd .worktrees/{agent}-{feature}
git pull origin main
```

---

## Hierarchical Merge Protocol

```
┌────────────────────────────────────────────────────────────────────────┐
│  MERGE PARA BRANCH PAI — NÃO DIRETO PARA MAIN                          │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  REGRA: Worktree faz merge para a branch que o ORIGINOU, não main.    │
│                                                                        │
│  RACIONAL:                                                             │
│  • Permite hierarquia de decisões (tree-like convergence)              │
│  • Main = root oficial, só recebe merges validados em camadas          │
│  • Cada nível de branch atua como gate de qualidade                   │
│  • Suporta trabalho paralelo com isolamento controlado                 │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### Modelo Visual

```
main (root/oficial)
  │
  ├── feature/sprint-42 (branch pai nível 1)
  │     │
  │     ├── feature/user-auth (worktree A)
  │     │     └── merge → feature/sprint-42 ✓
  │     │
  │     └── feature/payment-api (worktree B)
  │           │
  │           └── feature/payment-validation (worktree C)
  │                 └── merge → feature/payment-api ✓
  │                       └── merge → feature/sprint-42 ✓
  │                             └── merge → main ✓ (após validação)
```

### Fluxo Correto de Merge

```bash
# 1. TRABALHAR NO WORKTREE (branch filha)
cd .worktrees/prime-feature
git add <files>
git commit -m "feat: implement feature"

# 2. VOLTAR PARA BRANCH PAI (não main, a menos que seja a origem)
cd /path/to/repo

# 3. FAZER MERGE DA FILHA PARA O PAI
git merge feature/child-branch --no-edit

# 4. SE PAI = MAIN → Push direto
# SE PAI ≠ MAIN → Continuar subindo a hierarquia
git push origin <parent-branch>

# 5. CLEANUP
git worktree remove .worktrees/prime-feature --force
git branch -d feature/child-branch
```

---

## Lock File Protocol

### Criando um Lock File

```json
{
  "session_id": "Claude-Code-20260121-abcd",
  "agent_name": "Claude-Code",
  "started_at": "2026-01-21T12:00:00-03:00",
  "heartbeat": "2026-01-21T12:00:00-03:00",
  "working_on": ["CLAUDE.md", "README.md"],
  "branch": "main",
  "worktree_path": null,
  "pid": null,
  "stale_after_minutes": 30
}
```

### Verificando Locks Ativos

```bash
# Listar todos os locks
ls -la .worktrees/*.lock

# Verificar conteúdo de um lock
cat .worktrees/{session-id}.lock | jq '.working_on'
```

### Detecção de Locks Stale

Um lock é considerado **stale** quando:
- `(now - heartbeat) > stale_after_minutes` (default: 30 min)

Locks stale podem ser removidos por qualquer agente.

---

## Sessions Registry (sessions.json)

### Estrutura

```json
{
  "version": "1.0",
  "repository": "{repo-name}",
  "active_sessions": [],
  "paused_sessions": [],
  "orphaned_sessions": [],
  "completed_sessions": []
}
```

### Session Object

```json
{
  "session_id": "Claude-Code-20260121-xxxx",
  "agent_name": "Claude-Code",
  "started_at": "2026-01-21T12:00:00-03:00",
  "last_heartbeat": "2026-01-21T12:30:00-03:00",
  "worktree_path": ".worktrees/claude-feature",
  "branch": "feature/my-feature",
  "parent_branch": "main",
  "working_on": ["file1.md", "file2.md"],
  "status": "active"
}
```

---

## Tasks Registry (tasks.md)

### Formato

```markdown
# Task Registry

| Timestamp | Agent | Feature | Parent Branch | Status |
|-----------|-------|---------|---------------|--------|
| 2026-01-21T12:00:00-03:00 | Claude-Code | docs-update | main | IN_PROGRESS |
| 2026-01-21T13:00:00-03:00 | Claude-Code | docs-update | main | COMPLETED |
```

### Regras

- Append-only (nunca editar linhas existentes)
- Um registro por início e fim de tarefa
- Status: `IN_PROGRESS`, `PAUSED`, `COMPLETED`, `ABANDONED`

---

## Workflow Recomendado

### Início de Sessão

```bash
# 1. Verificar estado do repo
git status
git log --oneline -5

# 2. Verificar worktrees ativos
git worktree list

# 3. Criar ou entrar em worktree
git worktree add .worktrees/{agent}-{feature} -b feature/{branch}
cd .worktrees/{agent}-{feature}

# 4. Registrar início no tasks.md
echo "| $(date -Iseconds) | {agent} | {feature} | main | IN_PROGRESS |" >> ../.worktrees/tasks.md
```

### Durante Trabalho

```bash
# Antes de editar arquivo
git status --short | grep {arquivo}

# Commits frequentes
git add {arquivo-específico}
git commit -m "tipo(escopo): descrição - Agent: {nome}"
```

### Fim de Sessão

```bash
# 1. Commit final
git add -A
git commit -m "feat(escopo): descrição final - Agent: {nome}"

# 2. Push para remote
git push -u origin feature/{branch}

# 3. Registrar conclusão
echo "| $(date -Iseconds) | {agent} | {feature} | main | COMPLETED |" >> ../.worktrees/tasks.md

# 4. OBRIGATÓRIO: Criar PR (ver C07)
gh pr create --title "descrição" --body "Agent: {nome}"

# 5. Aguardar revisão e analisar (ver C07: PR Review Protocol)
# NÃO fazer merge direto - seguir workflow C07
```

> **IMPORTANTE**: O merge NUNCA é direto. Sempre via PR com revisão.
> Ver: `~/.claude/rules/pr-review-protocol.md` (C07)

---

## Nomenclatura

### Worktrees

Padrão: `{agent-name}-{feature-short}`

Exemplos:
- `claude-code-harmonization`
- `claude-orch-alpha-audit`

### Branches

Padrão: `{tipo}/{agent-name}-{descrição}`

Tipos: `feature/`, `fix/`, `docs/`, `refactor/`, `chore/`

---

## Inicialização de Novo Repositório

Para habilitar git-worktree em um novo repositório:

```bash
# 1. Criar estrutura
mkdir -p .worktrees
touch .worktrees/tasks.md
touch .worktrees/protected_files.json

# 2. Criar sessions.json
cat > .worktrees/sessions.json << 'EOF'
{
  "version": "1.0",
  "repository": "REPO_NAME",
  "active_sessions": [],
  "paused_sessions": [],
  "orphaned_sessions": [],
  "completed_sessions": []
}
EOF

# 3. Criar README.md
cp ~/.claude/templates/worktree/README.md.template .worktrees/README.md

# 4. Adicionar ao .gitignore
echo ".worktrees/*.lock" >> .gitignore
echo ".worktrees/*/  " >> .gitignore

# 5. Commit inicial
git add .worktrees/
git commit -m "chore: initialize git-worktree infrastructure"
```

---

## Hook de Validação Pre-Commit

O hook `validate-worktree-commit.sh` valida commits conforme o protocolo.

### Instalação

```bash
# Copiar para repositório
cp ~/.claude/hooks/validate-worktree-commit.sh .git/hooks/pre-commit

# Ou usar como hook global do Claude
# Já configurado em ~/.claude/settings.json
```

### Validações

| Validação | Ação | Nível |
|-----------|------|-------|
| Commit em main de worktree | BLOQUEIA | Error |
| Arquivo protegido sem lock | AVISA | Warning |
| Nome worktree não segue padrão | AVISA | Warning |

### Variáveis de Ambiente

| Variável | Propósito |
|----------|-----------|
| `CLAUDE_SESSION_ID` | ID da sessão para verificação de locks |
| `CLAUDE_PROJECT_DIR` | Diretório raiz do projeto |

---

## Resolução de Conflitos Multi-Agent

### Cenário 1: Conflito de Merge

Quando dois agentes modificam o mesmo arquivo em worktrees diferentes.

```
main
  └── feature/agent-a-work (modifica api.ts)
  └── feature/agent-b-work (modifica api.ts)
```

**Resolução**:

1. **Primeiro merge vence**: O primeiro agente a fazer merge não tem conflito
2. **Segundo detecta conflito**: Git marca conflitos no merge
3. **Rebase ou merge manual**:
   ```bash
   # No worktree do segundo agente
   git fetch origin
   git rebase origin/main  # ou merge
   # Resolver conflitos manualmente
   git add <resolved-files>
   git rebase --continue
   ```

### Cenário 2: Conflito de Lock

Dois agentes tentam adquirir lock no mesmo arquivo.

**Resolução**:

1. Verificar se lock existente é stale (`heartbeat > 30 min`)
2. Se stale: Remover lock e adquirir
3. Se ativo: Esperar ou negociar com outro agente
4. Usar arquivos diferentes quando possível

### Cenário 3: Worktree Órfão

Agente abandonou worktree sem cleanup.

**Detecção**:
```bash
# Listar worktrees
git worktree list

# Verificar sessions.json
cat .worktrees/sessions.json | jq '.orphaned_sessions'
```

**Resolução**:
```bash
# 1. Verificar se há trabalho não commitado
git -C .worktrees/{orphan-name} status

# 2. Se há trabalho importante, criar branch de resgate
git -C .worktrees/{orphan-name} checkout -b rescue/orphan-work
git -C .worktrees/{orphan-name} add -A
git -C .worktrees/{orphan-name} commit -m "rescue: work from orphaned worktree"

# 3. Remover worktree
rm -rf .worktrees/{orphan-name}
git worktree prune
```

### Cenário 4: Merge Hierárquico com Conflitos

```
main
  └── sprint/wave-3 (pai)
        └── feature/task-a (filho 1 - modifica CLAUDE.md)
        └── feature/task-b (filho 2 - modifica CLAUDE.md)
```

**Resolução Correta**:

1. **NÃO** fazer merge direto de filhos para main
2. Fazer merge de task-a → sprint/wave-3
3. Fazer merge de task-b → sprint/wave-3 (resolver conflitos aqui)
4. Fazer merge de sprint/wave-3 → main (já consolidado)

```bash
# 1. Merge task-a para pai
git checkout sprint/wave-3
git merge feature/task-a

# 2. Merge task-b para pai (conflitos aqui)
git merge feature/task-b
# Resolver conflitos
git add <resolved>
git commit

# 3. Finalmente, merge para main
git checkout main
git merge sprint/wave-3
```

### Prevenção de Conflitos

| Estratégia | Descrição |
|------------|-----------|
| **Arquivos protegidos** | Usar `protected_files.json` para arquivos críticos |
| **Lock antes de editar** | Adquirir lock antes de modificar arquivo sensível |
| **Commits frequentes** | Reduzir tamanho de mudanças por commit |
| **Pull frequente** | Manter branch atualizada com upstream |
| **Divisão clara** | Agentes trabalham em áreas distintas do código |

---

## Integração com PR Review Protocol (C07)

> **IMPORTANTE**: Este protocolo (C04) integra-se com o PR Review Protocol (C07).
> A partir de v1.1.0, merge direto é PROIBIDO.

### Workflow Completo C04 + C07

```
┌─────────────────────────────────────────────────────────────────────────┐
│  WORKFLOW INTEGRADO: Worktree → Branch → PR → Review → Merge            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  C04 (Worktree)                  C07 (PR Review)                        │
│  ──────────────                  ──────────────────                     │
│                                                                         │
│  1. Criar worktree    ─────────►                                        │
│  2. Desenvolver       ─────────►                                        │
│  3. Commit            ─────────►                                        │
│  4. Push branch       ─────────► 5. Criar PR                            │
│                                  6. Aguardar revisão (TTL: 30min)       │
│                                  7. Analisar revisão                    │
│                                  8. Decidir (merge/fix/partial/escalar) │
│  9. Cleanup worktree  ◄───────── (após merge)                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Regras de Integração

| Regra | C04 | C07 | Combinado |
|-------|-----|-----|-----------|
| Modificar arquivos | Requer worktree | - | Worktree obrigatório |
| Merge para pai | Via merge | Via PR | **PR obrigatório** |
| Merge direto | Permitido (v1.0) | Proibido | **Proibido (v1.1+)** |
| Revisão | Não especificado | Obrigatória | **Obrigatória** |

### Documentação Relacionada

| Documento | Localização | Propósito |
|-----------|-------------|-----------|
| C04 Rule (compacto) | `~/.claude/rules/core-directive.md` | Auto-load |
| C04 Spec (este doc) | `~/.claude/docs/git-worktree-protocol.md` | Detalhes |
| C07 Rule (compacto) | `~/.claude/rules/pr-review-protocol.md` | Auto-load |
| C07 Spec | `~/.claude/docs/pr-review-protocol-spec.md` | Detalhes |

---

## Referências

- [Git Worktrees for AI Agents - Nick Mitchinson](https://www.nrmitchi.com/2025/10/using-git-worktrees-for-multi-feature-development-with-ai-agents/)
- [Parallel Workflows with AI Agents - Medium](https://medium.com/@dennis.somerville/parallel-workflows-git-worktrees-and-the-art-of-managing-multiple-ai-agents-6fa3dc5eec1d)
- [Git Worktrees - Nx Blog](https://nx.dev/blog/git-worktrees-ai-agents)

---

*Versão: 1.2.0 | Atualizado: 2026-01-23 | Autor: Claude-Code*
*Integração com C07 (PR Review Protocol) adicionada*
*REGRA 7 (Nunca trocar branch) com enforcement via hook*
*Adaptado de vks-docs-mvp-approval/.worktrees/README.md v1.6*
