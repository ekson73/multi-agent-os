# Prompts - Multi-Agent-OS Research

<!-- ═══════════════════════════════════════════════════════════════════════════
     PROJETO: multi-agent-os
     Extraído de: Temporary Prompts - vek-sales-mvp-presentation.md
     Data de Extração: 2026-01-14
     Clusters Incluídos: C15, C16
     Foco: Research sobre worktrees órfãos e inter-comunicação entre agentes
     ═══════════════════════════════════════════════════════════════════════════ -->

## Índice de Clusters

> **Nota**: Instruções globais (C01, C02) estão em `~/Projects/catalogo-prompts-inventario.md`
> e devem ser herdadas implicitamente por todos os prompts deste arquivo.

| ID      | Camada | Tipo     | Descrição                                 |
| ------- | ------ | -------- | ----------------------------------------- |
| **C15** | 6      | Research | Worktrees órfãos + parent-session-id      |
| **C16** | 6      | Research | 7 soluções inter-comunicação agentes      |

---

## [C15] Research: Worktrees Órfãos

```research-question
CONTEXTO: `git worktree add .worktrees/${SHORT_ID}-feature-name -b feat/feature-name-${SHORT_ID}`
PROBLEMA: Sessões órfãs detectadas - possivelmente executadas por outros agentes em outras sessões
HIPÓTESE: Adicionar parent-session-id (FK) ao worktree, similar a multi-tenant
```

!!DO: delegue recursivamente → inventariar, analisar, validar, concluir, justificar.

### Status da Pesquisa

**✅ COMPLETO** - Documentado em `05_internal/research/research_multi_agent_2026-01-11.md`

**Solução Recomendada**: Opcão A + B combinadas

1. Adicionar `parent_session_id` ao schema de sessions.json (v1.5)
2. Criar LINEAGE.md em cada worktree como backup

**Schema Proposto**:

```json
{
  "session_id": "string",
  "parent_session_id": "string|null",
  "spawn_reason": "string|null",
  "started_at": "ISO8601",
  "state": "active|paused|orphaned"
}
```

### Implementação Sugerida

#### Opção A: Metadados em sessions.json

```json
{
  "sessions": [
    {
      "session_id": "abc123",
      "parent_session_id": null,
      "worktree_path": ".worktrees/abc123-feature-auth",
      "branch": "feat/feature-auth-abc123",
      "started_at": "2026-01-10T10:00:00-03:00",
      "state": "active"
    },
    {
      "session_id": "def456",
      "parent_session_id": "abc123",
      "spawn_reason": "delegated_qa_validation",
      "worktree_path": ".worktrees/def456-qa-auth",
      "branch": "feat/qa-auth-def456",
      "started_at": "2026-01-10T11:00:00-03:00",
      "state": "completed"
    }
  ]
}
```

#### Opção B: LINEAGE.md por Worktree

```markdown
# Worktree Lineage

## Identity
- **Session ID**: def456
- **Parent Session ID**: abc123
- **Spawn Reason**: delegated_qa_validation

## Timeline
- **Created**: 2026-01-10T11:00:00-03:00
- **Completed**: 2026-01-10T12:30:00-03:00

## Context
- **Task**: Validar implementação de autenticação
- **Delegated By**: Orchestrator Agent (abc123)
- **Expected Output**: QA Report

## Dependencies
- Depends on: abc123 (parent)
- Depended by: none
```

### Detecção de Órfãos

```bash
# Script para detectar worktrees órfãos
#!/bin/bash
for wt in .worktrees/*/; do
  session_id=$(basename "$wt" | cut -d'-' -f1)
  if ! jq -e ".sessions[] | select(.session_id == \"$session_id\")" sessions.json > /dev/null 2>&1; then
    echo "ORPHAN: $wt"
  fi
done
```

---

## [C16] Research: Inter-comunicação Agentes

!!DO: delegue recursivamente → crie 7 soluções para inter-comunicação entre agentes/sessions/threads:

```use-cases
- Delegação e consulta entre agentes
- Awareness: saber o que outro faz, impacto na própria tarefa
- Coordenação: esforços conjuntos, evitar conflitos
- Sincronização: estados, entregáveis, objetivos
- Qualidade: consistência, eficiência, minimizar retrabalho
```

!!DO: após gerar 7 soluções → pesquisar boas práticas na internet → comparar → apresentar as 3 melhores com justificativas, trade-offs, riscos, mitigações.

### Status da Pesquisa

**✅ COMPLETO** - Documentado em `05_internal/research/research_multi_agent_2026-01-11.md`

**Top 3 Soluções Recomendadas**:

| Rank | Solução                  | Score | Justificativa                         |
| ---- | ------------------------ | ----- | ------------------------------------- |
| 1    | File-Based Message Queue | 48/60 | Zero dependências, auditável, simples |
| 2    | Git-Based Communication  | 48/60 | Nativo git, histórico completo        |
| 3    | Hybrid Melhorado         | 46/60 | Já implementado, menor curva          |

**Implementação Sugerida**: `.worktrees/messages/` com JSON FIPA-inspired

---

### 7 Soluções Propostas

#### Solução 1: File-Based Message Queue (RECOMENDADA)

```
.worktrees/
├── messages/
│   ├── inbox/
│   │   ├── agent-abc123/
│   │   │   ├── msg-001.json
│   │   │   └── msg-002.json
│   │   └── agent-def456/
│   │       └── msg-001.json
│   ├── outbox/
│   └── processed/
```

**Formato da Mensagem (FIPA-inspired)**:

```json
{
  "message_id": "msg-001",
  "performative": "request|inform|query|propose|accept|reject",
  "sender": "agent-abc123",
  "receiver": "agent-def456",
  "timestamp": "2026-01-10T10:00:00-03:00",
  "content": {
    "action": "validate_document",
    "params": {
      "file": "roadmap.md",
      "criteria": ["tone", "completeness"]
    }
  },
  "reply_to": null,
  "conversation_id": "conv-xyz"
}
```

**Prós**: Zero dependências, auditável, simples
**Contras**: Polling necessário, latência

---

#### Solução 2: Git-Based Communication (RECOMENDADA)

Usar branches dedicados para comunicação:

```
git branches:
├── main
├── feat/feature-abc123
├── comms/agent-abc123  # Canal de saída do agente abc123
└── comms/agent-def456  # Canal de saída do agente def456
```

**Formato do Commit de Mensagem**:

```
[COMM] request: validate_document

From: agent-abc123
To: agent-def456
Action: validate_document
Params: {"file": "roadmap.md"}
Conversation: conv-xyz
```

**Prós**: Histórico completo, nativo git, merge natural
**Contras**: Overhead de commits, possíveis conflitos

---

#### Solução 3: Shared State File

```json
// .worktrees/shared-state.json
{
  "agents": {
    "abc123": {
      "status": "working",
      "current_task": "generate_slides",
      "progress": 75,
      "blocked_by": null,
      "last_update": "2026-01-10T10:30:00-03:00"
    },
    "def456": {
      "status": "waiting",
      "current_task": "qa_validation",
      "progress": 0,
      "blocked_by": "abc123",
      "last_update": "2026-01-10T10:25:00-03:00"
    }
  },
  "locks": {
    "roadmap.md": "abc123",
    "slides/": null
  }
}
```

**Prós**: Estado global visível, simples
**Contras**: Single point of contention, race conditions

---

#### Solução 4: Event Log (Append-Only)

```
.worktrees/events.log

2026-01-10T10:00:00 | abc123 | STARTED | generate_slides
2026-01-10T10:15:00 | abc123 | ACQUIRED_LOCK | roadmap.md
2026-01-10T10:20:00 | def456 | STARTED | qa_validation
2026-01-10T10:21:00 | def456 | BLOCKED | waiting for abc123
2026-01-10T10:30:00 | abc123 | COMPLETED | generate_slides
2026-01-10T10:30:01 | abc123 | RELEASED_LOCK | roadmap.md
2026-01-10T10:30:02 | def456 | UNBLOCKED | abc123 completed
```

**Prós**: Auditoria completa, append-only (sem conflitos de escrita)
**Contras**: Parsing necessário, arquivo cresce indefinidamente

---

#### Solução 5: Semaphore Files

```
.worktrees/locks/
├── roadmap.md.lock      # Conteúdo: "abc123|2026-01-10T10:15:00"
├── slides.lock          # Diretório inteiro
└── .heartbeat/
    ├── abc123           # Touch a cada 30s
    └── def456
```

**Prós**: Simples, previne conflitos
**Contras**: Não comunica intenção, apenas bloqueio

---

#### Solução 6: Task Board (Kanban-style)

```json
// .worktrees/taskboard.json
{
  "todo": [
    {"id": "t3", "title": "Export PDF", "assigned": null}
  ],
  "in_progress": [
    {"id": "t1", "title": "Generate slides", "assigned": "abc123", "started": "2026-01-10T10:00:00"}
  ],
  "blocked": [
    {"id": "t2", "title": "QA validation", "assigned": "def456", "blocked_by": "t1"}
  ],
  "done": []
}
```

**Prós**: Visual, claro, familiar
**Contras**: Não suporta comunicação direta

---

#### Solução 7: Hybrid (File + Git + Events)

Combinar as melhores características:

1. **Messages**: File-based queue para comunicação direta
2. **State**: Shared state file para awareness
3. **Events**: Append-only log para auditoria
4. **Locks**: Semaphore files para recursos compartilhados

**Prós**: Completo, flexível
**Contras**: Complexidade, manutenção

---

### Matriz de Avaliação

| Critério        | Peso | Sol.1 | Sol.2 | Sol.3 | Sol.4 | Sol.5 | Sol.6 | Sol.7 |
| --------------- | ---- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| Simplicidade    | 3    | 9     | 7     | 8     | 7     | 9     | 7     | 5     |
| Auditabilidade  | 2    | 8     | 10    | 6     | 10    | 4     | 6     | 9     |
| Sem Dependência | 3    | 10    | 10    | 10    | 10    | 10    | 10    | 10    |
| Comunicação     | 2    | 9     | 8     | 5     | 6     | 3     | 5     | 8     |
| Escalabilidade  | 1    | 7     | 6     | 5     | 4     | 8     | 6     | 6     |
| **TOTAL**       | -    | **48**| **48**| **41**| **43**| **41**| **39**| **46**|

---

### Recomendação Final

**Implementar Solução 1 (File-Based Message Queue)** como base, com elementos da Solução 2 (Git-Based) para histórico.

```
.worktrees/
├── messages/
│   ├── inbox/{agent-id}/
│   ├── outbox/{agent-id}/
│   └── processed/
├── state.json           # Estado compartilhado
├── events.log           # Log de eventos
└── locks/               # Semáforos
```

---

_Extraído de: Temporary Prompts - vek-sales-mvp-presentation.md_
_Data de Extração: 2026-01-14_
_Extração por: Claude-Cowork_
