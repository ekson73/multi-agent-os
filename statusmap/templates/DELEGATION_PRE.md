# Template: DELEGATION_PRE

**Proposito**: Contexto antes de delegar para sub-agente
**Tempo de absorcao**: 5-8 segundos
**Trigger**: Automatico (antes de Task tool call)

---

## Formato

```
┌─ DELEGATION ────────────────────────────────────────────────────────────┐
│                                                                          │
│  FROM: {parent_agent}                                                    │
│  TO:   {target_agent}                                                    │
│  TASK: {task_summary}                                                    │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  CHAIN VALIDATION                                                        │
│  ─────────────────────────────────────────────────────────────────────── │
│  Depth: {depth}/{max_depth} │ Loop Check: {loop_status}                  │
│  Chain: {delegation_chain}                                               │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  CONTEXT PACKAGE                                                         │
│  ─────────────────────────────────────────────────────────────────────── │
│  Files: {context_files}                                                  │
│  Constraints: {constraints}                                              │
│  Success criteria: {success_criteria}                                    │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  → Dispatching sub-agent...                                              │
└──────────────────────────────────────────────────────────────────────────┘
```

## Exemplo Preenchido

```
┌─ DELEGATION ────────────────────────────────────────────────────────────┐
│                                                                          │
│  FROM: Claude-Orch-Prime-20260106-c614                                   │
│  TO:   Claude-Analyst-c614-003                                           │
│  TASK: Analyze buffer requirements for VKS-554 dependencies              │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  CHAIN VALIDATION                                                        │
│  ─────────────────────────────────────────────────────────────────────── │
│  Depth: 1/3 │ Loop Check: ✓ PASS                                         │
│  Chain: Orch-Prime → Analyst-003                                         │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  CONTEXT PACKAGE                                                         │
│  ─────────────────────────────────────────────────────────────────────── │
│  Files: roadmap_macro_2027Q3.csv, dependency_edges_2027Q3.csv            │
│  Constraints: Focus on critical path only, max 500 tokens output         │
│  Success criteria: Gap analysis with HIGH/MEDIUM/LOW classification      │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  → Dispatching sub-agent...                                              │
└──────────────────────────────────────────────────────────────────────────┘
```

## Campos

| Campo | Obrigatorio | Descricao |
|-------|-------------|-----------|
| `parent_agent` | Sim | ID do agente que delega |
| `target_agent` | Sim | ID do agente que recebe |
| `task_summary` | Sim | Resumo da tarefa (1 linha) |
| `depth` | Sim | Nivel atual de delegacao |
| `max_depth` | Sim | Maximo permitido (default: 3) |
| `loop_status` | Sim | ✓ PASS ou ✗ BLOCKED |
| `delegation_chain` | Sim | Cadeia de delegacoes ate aqui |
| `context_files` | Nao | Arquivos relevantes para a tarefa |
| `constraints` | Nao | Restricoes para o sub-agente |
| `success_criteria` | Sim | Criterios de sucesso da tarefa |

## Integracao com Sentinel Protocol

Este template é exibido ANTES de cada chamada ao Task tool. Os campos `depth`, `loop_status` e `delegation_chain` são validados automaticamente pelo Sentinel Protocol.

Se `loop_status` = ✗ BLOCKED, a delegação é impedida e o template ERROR_DEBUG é exibido.

---

**Versao**: 1.0
