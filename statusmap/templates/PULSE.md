# Template: PULSE

**Proposito**: Status minimo em 1 linha, a cada resposta do agent
**Tempo de absorcao**: 1-2 segundos
**Trigger**: Automatico (cada resposta)

---

## Formato

```
[PULSE] {barra} {pct}% | ✓{done} ↻{active} ⚠{blocked} | {tempo} | → {acao}
```

## Anatomia

```
[PULSE] ████████░░ 80% | ✓3 ↻1 ⚠0 | 25m | → Continue editing
   │       │       │      │            │        └── Proxima acao sugerida
   │       │       │      │            └── Tempo desde inicio sessao
   │       │       │      └── ✓=done ↻=active ⚠=blocked (tasks)
   │       │       └── Porcentagem progresso
   │       └── Barra visual ASCII (10 chars)
   └── Identificador do template
```

## Exemplo Preenchido

```
[PULSE] ██████░░░░ 60% | ✓5 ↻2 ⚠0 | 1h 15m | → Commit changes
```

## Esqueleto com Placeholders

```
[PULSE] {progress_bar} {progress_pct}% | ✓{tasks_done} ↻{tasks_active} ⚠{tasks_blocked} | {session_duration} | → {next_action}
```

## Campos

| Campo | Obrigatorio | Descricao |
|-------|-------------|-----------|
| `progress_bar` | Sim | Barra ASCII de 10 chars (█ e ░) |
| `progress_pct` | Sim | Porcentagem 0-100 |
| `tasks_done` | Sim | Contador de tarefas concluidas |
| `tasks_active` | Sim | Contador de tarefas em andamento |
| `tasks_blocked` | Sim | Contador de tarefas bloqueadas |
| `session_duration` | Sim | Duracao da sessao (ex: 25m, 1h 15m) |
| `next_action` | Sim | Proxima acao sugerida |

## Barra de Progresso

```
  0%: ░░░░░░░░░░
 10%: █░░░░░░░░░
 20%: ██░░░░░░░░
 30%: ███░░░░░░░
 40%: ████░░░░░░
 50%: █████░░░░░
 60%: ██████░░░░
 70%: ███████░░░
 80%: ████████░░
 90%: █████████░
100%: ██████████
```

## Fallback (sem emoji)

```
[PULSE] ████████░░ 80% | OK:3 RUN:1 BLK:0 | 25m | -> Continue editing
```

---

**Versao**: 1.0
