# Template: COMPACT

**Proposito**: Verificacao rapida entre tarefas
**Tempo de absorcao**: 3-5 segundos
**Trigger**: `/agentic-status` ou automatico (quick check)

---

## Formato

```
┌─────────────────────────────────────────────────────────────────┐
│  STATUS MAP | {timestamp} | Session: {session_hex}             │
├────────────┬────────────────────────────────────────────────────┤
│ {git_ico} GIT     │ {branch} | {git_status} | last: {commit}   │
│ {agt_ico} AGENTS  │ {done} completed | {active} active | {blk} │
│ {sen_ico} SENTINEL│ v{ver} | {rules} rules | health: {score}   │
│ {lck_ico} LOCKS   │ {locks_active} active | {locks_stale} stale│
├────────────┴────────────────────────────────────────────────────┤
│ NEXT: {next_action}                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Exemplo Preenchido

```
┌─────────────────────────────────────────────────────────────────┐
│  STATUS MAP | 2026-01-06T12:30 | Session: c614                  │
├────────────┬────────────────────────────────────────────────────┤
│ 🟢 GIT     │ main | clean | last: a31b933                       │
│ 🟢 AGENTS  │ 23 completed | 0 active | 0 blocked                │
│ 🟢 SENTINEL│ v1.0 | 10 rules | health: 100                      │
│ 🟢 LOCKS   │ 0 active | 0 stale                                 │
├────────────┴────────────────────────────────────────────────────┤
│ NEXT: aguardando instrucao do humano                            │
└─────────────────────────────────────────────────────────────────┘
```

## Esqueleto com Placeholders

```
┌─────────────────────────────────────────────────────────────────┐
│  STATUS MAP | {timestamp} | Session: {session_hex}             │
├────────────┬────────────────────────────────────────────────────┤
│ {git_status_icon} GIT     │ {branch} | {git_state} | last: {commit_hash} │
│ {agents_status_icon} AGENTS  │ {agents_completed} completed | {agents_active} active | {agents_blocked} blocked │
│ {sentinel_status_icon} SENTINEL│ v{sentinel_version} | {rules_count} rules | health: {health_score} │
│ {locks_status_icon} LOCKS   │ {locks_active} active | {locks_stale} stale │
├────────────┴────────────────────────────────────────────────────┤
│ NEXT: {next_action}                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Campos

| Campo | Obrigatorio | Descricao |
|-------|-------------|-----------|
| `timestamp` | Sim | ISO 8601 curto (YYYY-MM-DDTHH:MM) |
| `session_hex` | Sim | Ultimos 4 chars do session ID |
| `branch` | Sim | Branch atual do git |
| `git_state` | Sim | clean/dirty/conflict |
| `commit_hash` | Sim | Hash curto (7 chars) do ultimo commit |
| `agents_completed` | Sim | Total de sub-agents concluidos |
| `agents_active` | Sim | Sub-agents em execucao |
| `agents_blocked` | Sim | Sub-agents bloqueados |
| `sentinel_version` | Sim | Versao do Sentinel Protocol |
| `rules_count` | Sim | Numero de regras de deteccao |
| `health_score` | Sim | Score de saude 0-100 |
| `locks_active` | Sim | Lock files ativos |
| `locks_stale` | Sim | Lock files stale (>30min) |
| `next_action` | Sim | Proxima acao sugerida |

## Indicadores de Estado

| Icone | Significado |
|-------|-------------|
| 🟢 | OK / Normal / Clean |
| 🟡 | Warning / Attention |
| 🔴 | Error / Critical |
| ⚪ | Unknown / N/A |

## Fallback (sem emoji)

```
┌─────────────────────────────────────────────────────────────────┐
│  STATUS MAP | 2026-01-06T12:30 | Session: c614                  │
├────────────┬────────────────────────────────────────────────────┤
│ [OK] GIT     │ main | clean | last: a31b933                     │
│ [OK] AGENTS  │ 23 completed | 0 active | 0 blocked              │
│ [OK] SENTINEL│ v1.0 | 10 rules | health: 100                    │
│ [OK] LOCKS   │ 0 active | 0 stale                               │
├────────────┴────────────────────────────────────────────────────┤
│ NEXT: aguardando instrucao do humano                            │
└─────────────────────────────────────────────────────────────────┘
```

---

**Versao**: 1.0
