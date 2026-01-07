# Template: FULL_REPORT

**Proposito**: Relatorio completo para analise profunda
**Tempo de absorcao**: 60-120 segundos
**Trigger**: Manual (`/status full`)

---

## Formato

```
╔══════════════════════════════════════════════════════════════════════════╗
║  FULL STATUS REPORT                                                      ║
║  Session: {session_id}                                                   ║
║  Generated: {timestamp}                                                  ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║  EXECUTIVE SUMMARY                                                       ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║                                                                          ║
║  Health Score: {health_score}/100 ({health_status})                      ║
║  Session Duration: {duration}                                            ║
║  Tasks Completed: {tasks_done}/{tasks_total} ({tasks_pct}%)              ║
║  Anomalies: {anomalies_count} ({anomalies_resolved} resolved)            ║
║                                                                          ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║  GIT REPOSITORY                                                          ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║                                                                          ║
║  Branch:        {branch}                                                 ║
║  Status:        {git_status}                                             ║
║  Last Commit:   {commit_hash} - {commit_msg}                             ║
║  Modified:      {modified_count} files                                   ║
║  Staged:        {staged_count} files                                     ║
║  Untracked:     {untracked_count} files                                  ║
║                                                                          ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║  DELEGATION METRICS                                                      ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║                                                                          ║
║  {delegation_table}                                                      ║
║                                                                          ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║  SENTINEL PROTOCOL                                                       ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║                                                                          ║
║  Version: {sentinel_version}                                             ║
║  Rules Enabled: {rules_enabled}/{rules_total}                            ║
║  Alerts (this session): {alerts_high} HIGH | {alerts_med} MEDIUM         ║
║                                                                          ║
║  {sentinel_rules_status}                                                 ║
║                                                                          ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║  MULTI-AGENT COORDINATION                                                ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║                                                                          ║
║  Sessions Registry: {sessions_count} total ({sessions_active} active)    ║
║  Lock Files: {locks_active} active | {locks_stale} stale                 ║
║  Protected Files: {protected_in_use} in use                              ║
║                                                                          ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║  ACTIVITY LOG (last 10)                                                  ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║                                                                          ║
║  {activity_log}                                                          ║
║                                                                          ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║  ANOMALY LOG                                                             ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║                                                                          ║
║  {anomaly_log}                                                           ║
║                                                                          ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║  RECOMMENDATIONS                                                         ║
║  ═══════════════════════════════════════════════════════════════════════ ║
║                                                                          ║
║  {recommendations}                                                       ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

## Exemplo de Delegation Table

```
  ┌──────────────┬────────┬─────────┬────────┬──────────┐
  │ Agent        │ Tasks  │ Success │ Errors │ Avg Time │
  ├──────────────┼────────┼─────────┼────────┼──────────┤
  │ Orch-Prime   │   15   │   100%  │    0   │    N/A   │
  │ PO-001       │    3   │   100%  │    0   │   45s    │
  │ Dev-002      │    5   │    80%  │    1   │   2m30s  │
  │ Editor-003   │    4   │   100%  │    0   │   30s    │
  └──────────────┴────────┴─────────┴────────┴──────────┘
```

## Campos Principais

| Campo | Obrigatorio | Descricao |
|-------|-------------|-----------|
| `session_id` | Sim | ID completo da sessao |
| `timestamp` | Sim | ISO 8601 completo |
| `health_score` | Sim | Score 0-100 |
| `health_status` | Sim | EXCELLENT/GOOD/FAIR/POOR/CRITICAL |
| `duration` | Sim | Duracao da sessao |
| `tasks_done` | Sim | Tarefas concluidas |
| `tasks_total` | Sim | Total de tarefas |
| `anomalies_count` | Sim | Anomalias detectadas |
| `delegation_table` | Sim | Tabela de metricas por agent |
| `activity_log` | Sim | Ultimas 10 acoes |
| `anomaly_log` | Nao | Log de anomalias (se houver) |
| `recommendations` | Nao | Recomendacoes do sistema |

---

**Versao**: 1.0
