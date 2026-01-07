# Git Worktrees para AI Agents — Diretrizes
## VKS_Apresentacao_CEO_2027Q3

Este diretorio armazena git worktrees para uso por multiplos AI agents trabalhando em paralelo.

**Versao**: 1.5 | **Atualizado**: 2026-01-07

---

## Arquivos de Coordenacao

| Arquivo | Proposito | Tracked |
|---------|-----------|---------|
| `README.md` | Documentacao e diretrizes | Sim |
| `tasks.md` | Registro de tarefas por agente | Sim |
| `sessions.json` | Registro de sessoes ativas | Sim |
| `protected_files.json` | Manifest de arquivos protegidos | Sim |
| `session_lock.template.json` | Template para arquivos de lock | Sim |
| `*.lock` | Lock files ativos (dinamicos) | **Nao** |

---

## Por Que Usar Worktrees?

Git worktrees permitem checkout de multiplas branches simultaneamente em diretorios separados, compartilhando o mesmo `.git`. Isso e essencial para:

1. **Isolamento**: Cada agente trabalha em seu proprio diretorio
2. **Sem conflitos de arquivos**: Agentes nao sobrescrevem trabalho um do outro
3. **Merge controlado**: Conflitos sao resolvidos no momento do merge, nao durante o trabalho
4. **Paths estaveis**: Cada worktree tem path fixo (nao muda com branch switch)

---

## Guardrails de Integridade (v1.0)

```
┌────────────────────────────────────────────────────────────────────────┐
│  GUARDRAILS OBRIGATORIOS — PREVENCAO DE CONFLITOS                      │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  REGRA 1: UNICIDADE DE SESSAO                                          │
│  ─────────────────────────────────────────────────────────────────────│
│  Um session_id DEVE aparecer em APENAS UM dos arrays:                  │
│  - active_sessions OU completed_sessions, NUNCA ambos                  │
│                                                                        │
│  VALIDACAO: Antes de adicionar sessao, verificar ambos os arrays       │
│                                                                        │
│  REGRA 2: WORKTREE REAL                                                │
│  ─────────────────────────────────────────────────────────────────────│
│  worktree_path em sessions.json DEVE corresponder a um worktree real   │
│                                                                        │
│  VALIDACAO: `git worktree list | grep {path}` deve retornar resultado  │
│                                                                        │
│  REGRA 3: WORKTREE EXCLUSIVO                                           │
│  ─────────────────────────────────────────────────────────────────────│
│  Um worktree_path pode ser usado por NO MAXIMO UMA sessao ativa        │
│                                                                        │
│  VALIDACAO: Verificar se worktree_path ja existe em active_sessions    │
│                                                                        │
│  REGRA 4: CONSISTENCIA TEMPORAL                                        │
│  ─────────────────────────────────────────────────────────────────────│
│  completed_at DEVE ser posterior a started_at                          │
│  last_heartbeat NAO pode ser posterior a completed_at                  │
│                                                                        │
│  REGRA 5: TRANSICAO ATOMICA                                            │
│  ─────────────────────────────────────────────────────────────────────│
│  Ao completar sessao:                                                  │
│  1. PRIMEIRO: Remover de active_sessions                               │
│  2. DEPOIS: Adicionar a completed_sessions                             │
│  Nunca inverter a ordem ou fazer parcialmente                          │
│                                                                        │
│  REGRA 6: BRANCH-WORKTREE SYNC                                         │
│  ─────────────────────────────────────────────────────────────────────│
│  Se worktree foi removido, a branch associada deve ser avaliada:       │
│  - Merged? → Pode deletar branch                                       │
│  - Nao merged? → Manter ou fazer backup antes de deletar               │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### Checklist de Validacao (Antes de Iniciar Sessao)

```bash
# 1. Verificar se session_id ja existe
grep -l "meu-session-id" .worktrees/sessions.json && echo "ERRO: Session ja existe"

# 2. Verificar se worktree existe (se for usar um)
git worktree list | grep "meu-worktree-path" || echo "AVISO: Worktree nao existe"

# 3. Verificar se worktree esta em uso por outra sessao
jq '.active_sessions[] | select(.worktree_path == "meu-path")' .worktrees/sessions.json

# 4. Verificar branches orfas (existem mas nao estao em worktree)
git branch -a | while read branch; do
  git worktree list | grep -q "$branch" || echo "Orfa: $branch"
done
```

### Erros Comuns e Solucoes

| Erro | Causa | Solucao |
|------|-------|---------|
| Sessao em active E completed | Transicao incompleta | Remover de active_sessions |
| worktree_path inexistente | Worktree deletado sem atualizar sessions.json | Atualizar ou remover sessao |
| Multiplas sessoes no mesmo worktree | Falta de verificacao pre-sessao | Mover uma sessao para outro worktree |
| Branch orfa | Worktree removido sem deletar branch | Avaliar e deletar se merged |
| Heartbeat > completed_at | Sessao continuou apos ser marcada completa | Atualizar completed_at |

---

## Quando Usar Worktree (v1.1)

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

## Estrutura de Worktrees

```
.worktrees/
+-- README.md                      <- Este arquivo (v1.4)
+-- tasks.md                       <- Registro de tarefas por agente
+-- sessions.json                  <- Registro de sessoes ativas
+-- protected_files.json           <- Manifest de arquivos protegidos
+-- session_lock.template.json     <- Template para lock files
+-- {session-id}.lock              <- Lock file ativo (dinamico, nao tracked)
+-- {agent-name}-{feature}/        <- Worktree por agente/feature
    +-- (copia completa do repo)
```

---

## Nomenclatura de Worktrees

Padrao: `{agent-name}-{feature-short}`

Exemplos:
- `claude-orch-alpha-audit`
- `claude-code-harmonization`
- `claude-review-docs`

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
# Remover diretorio e limpar referencias
rm -rf .worktrees/{agent}-{feature}
git worktree prune
```

### Atualizar Worktree

```bash
cd .worktrees/{agent}-{feature}
git pull origin main
```

---

## Regras Anti-Conflito para AI Agents

> **IMPORTANTE**: Versao completa e atualizada (v2.0) em `CLAUDE.md` secao "Anti-Conflict Rules (Enhanced v2.0)"
>
> A versao abaixo e um resumo. Consulte CLAUDE.md para o protocolo completo com 6 fases.

### 1. Identificacao Obrigatoria

Todo AI agent DEVE:
- Ter um nome unico (ex: `Claude-Orch-Alpha`, `Claude-Review-Beta`)
- Assinar todos os documentos que modifica
- Registrar suas acoes no `tasks.md`

### 2. Verificacao Pre-Edicao

Antes de editar qualquer arquivo:

```bash
# Verificar se arquivo esta sendo modificado por outro
git status --short | grep {arquivo}

# Se arquivo esta com 'M' ou 'MM', NAO editar
```

### 3. Arquivos Protegidos (Coordenacao Obrigatoria)

> **IMPORTANTE**: Lista completa em `.worktrees/protected_files.json`

| Categoria | Arquivos | Protocolo |
|-----------|----------|-----------|
| **Critical** | `CLAUDE.md`, `README.md` | Lock obrigatorio + notificacao em tasks.md |
| **Source of Truth** | `02_processed_data/*.csv` | Edits requerem validation report |
| **Shared State** | `.worktrees/tasks.md`, `sessions.json` | Append-only preferido |

Antes de editar qualquer arquivo protegido:
1. Verificar `.worktrees/*.lock` para sessoes ativas
2. Verificar `sessions.json` para agents trabalhando no arquivo
3. Criar seu proprio lock file se necessario

### 4. Politica de Commits

```bash
# Sempre verificar status antes de commit
git status

# Usar commits atomicos (um proposito por commit)
git add {arquivos-especificos}
git commit -m "tipo(escopo): descricao - Agent: {nome}"

# NAO usar git add . em repos compartilhados
```

### 5. Branches por Agente

Cada agente deve trabalhar em sua propria branch:

```bash
# Padrao de nome
feature/{agent-name}-{descricao}

# Exemplos
feature/claude-orch-alpha-multiperspective
feature/claude-code-harmonization
```

---

## Workflow Recomendado

### Inicio de Sessao

```bash
# 1. Verificar estado do repo
git status
git log --oneline -5

# 2. Verificar worktrees ativos
git worktree list

# 3. Criar ou entrar em worktree
git worktree add .worktrees/{meu-agent}-{feature} -b feature/{branch}
cd .worktrees/{meu-agent}-{feature}

# 4. Registrar inicio no tasks.md
echo "| $(date -Iseconds) | {agent} | {feature} | IN_PROGRESS |" >> ../tasks.md
```

### Durante Trabalho

```bash
# Antes de editar arquivo
git status --short | grep {arquivo}

# Se limpo, editar
# Se modificado por outro, NAO editar ou coordenar

# Commits frequentes
git add {arquivo-especifico}
git commit -m "tipo(escopo): descricao - Agent: {nome}"
```

### Fim de Sessao

```bash
# 1. Commit final
git add -A
git commit -m "feat(escopo): descricao final - Agent: {nome}"

# 2. Push para remote
git push -u origin feature/{branch}

# 3. Registrar conclusao
echo "| $(date -Iseconds) | {agent} | {feature} | COMPLETED |" >> ../tasks.md

# 4. Opcional: Criar PR para merge
gh pr create --title "descricao" --body "Agent: {nome}"
```

---

## Resolucao de Conflitos

### Conflito Detectado

```bash
# Ver arquivos em conflito
git status

# Opcao 1: Resolver manualmente
git checkout --ours {arquivo}   # Manter minha versao
git checkout --theirs {arquivo} # Manter versao do outro

# Opcao 2: Merge manual
# Editar arquivo removendo marcadores <<<<< ===== >>>>>
git add {arquivo}
git commit -m "merge: resolve conflict in {arquivo} - Agent: {nome}"
```

### Prevencao de Conflitos

1. **Dividir trabalho por arquivos/diretorios**
2. **Usar worktrees separados**
3. **Comunicar via tasks.md**
4. **Commits frequentes e atomicos**
5. **Usar lock files para arquivos protegidos**

---

## Lock File Protocol

### Criando um Lock File

```bash
# 1. Copiar template
cp .worktrees/session_lock.template.json .worktrees/{session-id}.lock

# 2. Editar com seus dados
{
  "session_id": "Claude-Orch-Prime-20260106-abcd",
  "agent_name": "Claude-Orch-Prime",
  "started_at": "2026-01-06T23:00:00-03:00",
  "heartbeat": "2026-01-06T23:00:00-03:00",
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

# Verificar conteudo de um lock
cat .worktrees/{session-id}.lock | jq '.working_on'

# Verificar se lock esta stale (heartbeat > 30 min)
cat .worktrees/{session-id}.lock | jq '.heartbeat'
```

### Atualizando Heartbeat

Durante trabalho longo, atualizar heartbeat a cada 10-15 minutos:

```bash
# Atualizar campo heartbeat
jq '.heartbeat = "2026-01-06T23:15:00-03:00"' .worktrees/{session-id}.lock > tmp && mv tmp .worktrees/{session-id}.lock
```

### Removendo Lock ao Finalizar

```bash
# Ao terminar trabalho normalmente
rm .worktrees/{session-id}.lock
```

### Deteccao de Locks Stale

Um lock e considerado **stale** quando:
- `(now - heartbeat) > stale_after_minutes` (default: 30 min)

Locks stale podem ser removidos por qualquer agente:

```bash
# Verificar se lock esta stale
HEARTBEAT=$(cat .worktrees/{session-id}.lock | jq -r '.heartbeat')
STALE_MINUTES=$(cat .worktrees/{session-id}.lock | jq -r '.stale_after_minutes')

# Se stale, remover
rm .worktrees/{session-id}.lock
```

### Fluxo Completo com Lock

```
1. INICIO
   |
   v
2. Verificar .worktrees/*.lock
   |
   +---> Lock existe e NAO stale? ---> AGUARDAR ou trabalhar em outro arquivo
   |
   v
3. Criar seu lock file
   |
   v
4. Registrar em sessions.json e tasks.md
   |
   v
5. TRABALHAR (atualizar heartbeat a cada 15 min)
   |
   v
6. Commit com assinatura
   |
   v
7. Atualizar sessions.json e tasks.md
   |
   v
8. Remover lock file
   |
   v
9. FIM
```

---

## Registro de Tarefas (tasks.md)

Todos os agentes devem registrar suas tarefas:

| Timestamp | Agent | Feature | Status |
|-----------|-------|---------|--------|
| 2026-01-06T18:00:00-03:00 | Claude-Orch-Alpha | Multi-perspective analysis | COMPLETED |

---

## Referencias

- [Git Worktrees for AI Agents - Nick Mitchinson](https://www.nrmitchi.com/2025/10/using-git-worktrees-for-multi-feature-development-with-ai-agents/)
- [Parallel Workflows with AI Agents - Medium](https://medium.com/@dennis.somerville/parallel-workflows-git-worktrees-and-the-art-of-managing-multiple-ai-agents-6fa3dc5eec1d)
- [Git Worktrees - Nx Blog](https://nx.dev/blog/git-worktrees-ai-agents)
- [Parallel AI Coding - Agent Interviews](https://docs.agentinterviews.com/blog/parallel-ai-coding-with-gitworktrees/)

---

**Metadados do Documento**

| Campo | Valor |
|-------|-------|
| Criado por | `Claude-Orch-Alpha` |
| Atualizado por | `Claude-Orch-Prime-20260107-val1` |
| Data | 2026-01-07 |
| Versao | 1.5 |

**Changelog**:
- v1.5 (2026-01-07): Guardrails de Integridade v1.0 - 6 regras + checklist + erros comuns
- v1.4 (2026-01-06): Politica simplificada - worktree obrigatorio para modificacoes (3 excecoes)
- v1.3 (2026-01-06): Nomenclatura de diretorios e branches padronizada
- v1.2 (2026-01-06): Lock File Protocol, Protected Files manifest, Sessions registry
- v1.1 (2026-01-06): Referencia a Enhanced Anti-Conflict Protocol v2.0 em CLAUDE.md
- v1.0 (2026-01-06): Versao inicial

*Assinatura: Claude-Orch-Prime-20260107-val1 | 2026-01-07T00:35:00-03:00*
