# Template: SESSION_END

**Proposito**: Handoff ao finalizar sessao
**Tempo de absorcao**: 20-30 segundos
**Trigger**: Automatico (fim de sessao) ou `/status end`

---

## Formato

```
┌─ SESSION END ───────────────────────────────────────────────────────────┐
│                                                                          │
│  FROM: {session_id}                                                      │
│  TO:   Next session / Human reviewer                                     │
│  TIME: {timestamp}                                                       │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  SESSION SUMMARY                                                         │
│  ─────────────────────────────────────────────────────────────────────── │
│  Duration: {duration} │ Health: {health_score}/100                       │
│  Tasks: {tasks_done}/{tasks_total} │ Delegations: {delegations_count}   │
│  Files modified: {files_count} │ Commits: {commits_count}               │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  DELIVERABLES                                                            │
│  ─────────────────────────────────────────────────────────────────────── │
│  {deliverables_list}                                                     │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  PENDING ITEMS                                                           │
│  ─────────────────────────────────────────────────────────────────────── │
│  {pending_list}                                                          │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  CONTEXT FOR NEXT SESSION                                                │
│  ─────────────────────────────────────────────────────────────────────── │
│  Key files: {key_files}                                                  │
│  Decisions: {decisions_summary}                                          │
│  Blockers: {blockers}                                                    │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  RECOMMENDATIONS                                                         │
│  ─────────────────────────────────────────────────────────────────────── │
│  {recommendations}                                                       │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## Exemplo Preenchido

```
┌─ SESSION END ───────────────────────────────────────────────────────────┐
│                                                                          │
│  FROM: Claude-Orch-Prime-20260106-c614                                   │
│  TO:   Next session / Human reviewer                                     │
│  TIME: 2026-01-06T15:45:00-03:00                                         │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  SESSION SUMMARY                                                         │
│  ─────────────────────────────────────────────────────────────────────── │
│  Duration: 3h 15m │ Health: 94/100                                       │
│  Tasks: 12/15 │ Delegations: 23                                          │
│  Files modified: 18 │ Commits: 5                                         │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  DELIVERABLES                                                            │
│  ─────────────────────────────────────────────────────────────────────── │
│  [✓] Status Map System v1.0 implemented                                  │
│  [✓] 8 templates created in .claude/statusmap/                           │
│  [✓] Inference engine documented                                         │
│  [✓] CLAUDE.md updated with Status Map section                           │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  PENDING ITEMS                                                           │
│  ─────────────────────────────────────────────────────────────────────── │
│  [!] Task #13: Awaiting human approval for commit                        │
│  [ ] Task #14: Not started (depends on #13)                              │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  CONTEXT FOR NEXT SESSION                                                │
│  ─────────────────────────────────────────────────────────────────────── │
│  Key files: CLAUDE.md, .claude/statusmap/README.md                       │
│  Decisions: Status Maps use ASCII box drawing for terminal compat        │
│  Blockers: None                                                          │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  RECOMMENDATIONS                                                         │
│  ─────────────────────────────────────────────────────────────────────── │
│  1. Review and commit pending changes                                    │
│  2. Test Status Map templates in production                              │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## Campos

| Campo | Obrigatorio | Descricao |
|-------|-------------|-----------|
| `session_id` | Sim | ID completo da sessao |
| `timestamp` | Sim | ISO 8601 completo |
| `duration` | Sim | Duracao da sessao |
| `health_score` | Sim | Score Sentinel 0-100 |
| `tasks_done` | Sim | Tarefas concluidas |
| `tasks_total` | Sim | Total de tarefas |
| `delegations_count` | Sim | Sub-agents despachados |
| `files_count` | Sim | Arquivos modificados |
| `commits_count` | Sim | Commits realizados |
| `deliverables_list` | Sim | Lista de entregas |
| `pending_list` | Nao | Itens pendentes |
| `key_files` | Sim | Arquivos chave para contexto |
| `decisions_summary` | Nao | Decisoes tomadas |
| `blockers` | Sim | Bloqueadores ou "None" |
| `recommendations` | Nao | Recomendacoes para proxima sessao |

---

**Versao**: 1.0
