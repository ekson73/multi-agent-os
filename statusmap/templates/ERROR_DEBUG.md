# Template: ERROR_DEBUG

**Proposito**: Diagnostico quando ocorre erro ou bloqueio
**Tempo de absorcao**: 15-20 segundos
**Trigger**: Automatico (erro detectado) ou `/agentic-status debug`

---

## Formato

```
┌─ 🔴 ERROR DEBUG ────────────────────────────────────────────────────────┐
│                                                                          │
│  ERROR: {error_type}                                                     │
│  TIME:  {timestamp}                                                      │
│  AGENT: {agent_id}                                                       │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  STACK TRACE                                                             │
│  ─────────────────────────────────────────────────────────────────────── │
│  {stack_trace}                                                           │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  ROOT CAUSE ANALYSIS                                                     │
│  ─────────────────────────────────────────────────────────────────────── │
│  Cause: {root_cause}                                                     │
│  Impact: {impact_description}                                            │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  RECOMMENDED ACTIONS                                                     │
│  ─────────────────────────────────────────────────────────────────────── │
│  {actions_list}                                                          │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## Exemplo Preenchido

```
┌─ 🔴 ERROR DEBUG ────────────────────────────────────────────────────────┐
│                                                                          │
│  ERROR: File lock conflict                                               │
│  TIME:  2026-01-06T14:30:15-03:00                                        │
│  AGENT: Claude-Dev-c614-001                                              │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  STACK TRACE                                                             │
│  ─────────────────────────────────────────────────────────────────────── │
│  1. Orch-Prime dispatched task "edit CLAUDE.md"                          │
│  2. Dev-001 received task at 14:28:00                                    │
│  3. Dev-001 attempted file edit at 14:29:30                              │
│  4. ERROR: File locked by another session                                │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  ROOT CAUSE ANALYSIS                                                     │
│  ─────────────────────────────────────────────────────────────────────── │
│  Cause: Lock file exists - .worktrees/session-a1b2.lock                  │
│  Impact: Cannot proceed with CLAUDE.md modification                      │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  RECOMMENDED ACTIONS                                                     │
│  ─────────────────────────────────────────────────────────────────────── │
│  [1] Check lock owner: cat .worktrees/session-a1b2.lock                  │
│  [2] If stale (>30min): rm .worktrees/session-a1b2.lock                  │
│  [3] Retry task after lock resolution                                    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## Campos

| Campo | Obrigatorio | Descricao |
|-------|-------------|-----------|
| `error_type` | Sim | Tipo do erro (curto) |
| `timestamp` | Sim | ISO 8601 completo |
| `agent_id` | Sim | ID do agent que encontrou erro |
| `stack_trace` | Sim | Sequencia de eventos ate o erro |
| `root_cause` | Sim | Causa raiz identificada |
| `impact_description` | Sim | Impacto do erro |
| `actions_list` | Sim | Lista de acoes recomendadas |

---

**Versao**: 1.0
