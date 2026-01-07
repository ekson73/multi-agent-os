# Status Map Inference Engine v1.0

Sistema de inferencia automatica de templates para Status Maps.

## Visao Geral

O motor de inferencia seleciona automaticamente o template apropriado baseado em:
1. Evento atual (inicio, fim, erro, delegacao)
2. Estado do contexto (git, tasks, sessions)
3. Tempo desde ultimo status
4. Solicitacao explicita do usuario

---

## 1. Tabela de Triggers Automaticos

| ID | Condicao (Trigger) | Template | Prioridade | Justificativa |
|----|--------------------|----------|------------|---------------|
| T01 | Inicio de sessao (primeiro prompt) | `SESSION_START` | 1 (Maxima) | Estabelece contexto inicial |
| T02 | Erro detectado (exit code != 0) | `ERROR_DEBUG` | 2 | Diagnostico imediato critico |
| T03 | Delegacao retornando | `DELEGATION_POST` | 3 | Sincronizacao de contexto |
| T04 | Pre-commit (git add detectado) | `PRE_COMMIT` | 4 | Validacao antes de persistir |
| T05 | Tarefa concluida (>5 acoes) | `CHECKPOINT` | 5 | Fechamento de ciclo |
| T06 | Intervalo >15min sem status | `HEARTBEAT` | 6 | Manter usuario informado |
| T07 | Usuario solicita status | `COMPACT` | 7 | Resposta rapida padrao |
| T08 | Fim de sessao | `SESSION_END` | 1 | Fechamento com resumo |

### Prioridades
- **1-2**: Critico - sempre executar
- **3-4**: Alto - executar exceto se override manual
- **5-6**: Medio - executar se nao houver evento mais relevante
- **7+**: Baixo - fallback quando nada mais se aplica

---

## 2. Comandos de Override Manual

### Sintaxe Base
```
/status [modificador]
```

### Comandos Disponiveis

| Comando | Template | Descricao |
|---------|----------|-----------|
| `/status` | `COMPACT` | Status resumido padrao |
| `/status full` | `FULL_REPORT` | Relatorio completo |
| `/status debug` | `ERROR_DEBUG` | Diagnostico de erros |
| `/status start` | `SESSION_START` | Estado inicial |
| `/status end` | `SESSION_END` | Handoff/resumo final |
| `/status pre` | `PRE_COMMIT` | Validacao pre-commit |
| `/status silent` | `NONE` | Suprimir proximo status |

### Aliases Rapidos
| Alias | Equivalente |
|-------|-------------|
| `/s` | `/status` |
| `/sf` | `/status full` |
| `/sd` | `/status debug` |

---

## 3. Variaveis de Contexto

### Temporais
| Variavel | Tipo | Descricao |
|----------|------|-----------|
| `time_since_last_status` | Duration | Tempo desde ultimo status |
| `session_start_time` | DateTime | Inicio da sessao |
| `last_action_time` | DateTime | Ultima acao executada |

### Atividade
| Variavel | Tipo | Descricao |
|----------|------|-----------|
| `actions_since_last_status` | Integer | Contador de acoes |
| `files_modified_count` | Integer | Arquivos alterados |
| `errors_count` | Integer | Erros na sessao |

### Git
| Variavel | Tipo | Descricao |
|----------|------|-----------|
| `git_is_dirty` | Boolean | Ha mudancas nao commitadas |
| `git_staged_count` | Integer | Arquivos em staging |
| `git_current_branch` | String | Branch atual |

### Delegacao
| Variavel | Tipo | Descricao |
|----------|------|-----------|
| `active_subagents` | Integer | Sub-agents em execucao |
| `completed_delegations` | Integer | Delegacoes finalizadas |
| `delegation_depth` | Integer | Profundidade de aninhamento |

---

## 4. Decision Tree

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        EVENTO DETECTADO                                  │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────┐
                    │    Override Manual?       │
                    └──────────────────────────┘
                         │              │
                        SIM            NAO
                         │              │
                         ▼              ▼
              ┌──────────────┐  ┌─────────────────────┐
              │ Usar Template │  │   Evento Critico?   │
              │  Solicitado   │  └─────────────────────┘
              └──────────────┘         │
                                       ├── ERRO → ERROR_DEBUG
                                       ├── INICIO → SESSION_START
                                       ├── FIM → SESSION_END
                                       │
                                       ▼ (Nao critico)
                              ┌─────────────────────┐
                              │    Delegacao?       │
                              └─────────────────────┘
                                       │
                                       ├── RETORNANDO → DELEGATION_POST
                                       ├── INICIANDO → DELEGATION_PRE
                                       │
                                       ▼ (Nao)
                              ┌─────────────────────┐
                              │   Estado Git?       │
                              └─────────────────────┘
                                       │
                                       ├── PRE-COMMIT → PRE_COMMIT
                                       │
                                       ▼ (Normal)
                              ┌─────────────────────┐
                              │  Tarefa Concluida?  │
                              └─────────────────────┘
                                       │
                                       ├── SIM → CHECKPOINT
                                       │
                                       ▼ (Nao)
                              ┌─────────────────────┐
                              │   Tempo >15min?     │
                              └─────────────────────┘
                                       │
                                       ├── SIM → HEARTBEAT
                                       └── NAO → COMPACT (default)
```

---

## 5. Pseudocodigo de Inferencia

```python
def select_template(context, event, override=None):
    """
    Seleciona template baseado no contexto atual.
    """

    # Override manual tem prioridade absoluta
    if override is not None:
        return override

    # Prioridade 1: Eventos criticos de sessao
    if event == SESSION_START:
        return Template.SESSION_START
    if event == SESSION_END:
        return Template.SESSION_END

    # Prioridade 2: Erros
    if event == ERROR_OCCURRED or context.errors_count > 0:
        return Template.ERROR_DEBUG

    # Prioridade 3: Delegacoes
    if event == DELEGATION_COMPLETE:
        return Template.DELEGATION_POST
    if event == DELEGATION_START and context.delegation_depth > 1:
        return Template.DELEGATION_PRE

    # Prioridade 4: Operacoes Git
    if context.git_staged_count > 0 and event == PRE_COMMIT:
        return Template.PRE_COMMIT

    # Prioridade 5: Conclusoes
    if context.actions_since_last_status >= 5:
        return Template.CHECKPOINT

    # Prioridade 6: Heartbeat temporal
    if context.time_since_last_status > timedelta(minutes=15):
        return Template.HEARTBEAT

    # Default: COMPACT
    return Template.COMPACT
```

---

## 6. Fallback Strategy

| Situacao | Estrategia | Resultado |
|----------|------------|-----------|
| Nenhuma regra aplicavel | Usar COMPACT | Status basico |
| Multiplas regras | Primeira por prioridade | Determinístico |
| Contexto insuficiente | COMPACT + warning | Informa limitacao |
| Template nao registrado | Mensagem de erro | Feedback claro |

### Hierarquia de Fallback

```
1. Override Manual              → Usar template solicitado
   │
   ▼ (nao disponivel)
2. Regra Especifica Aplicavel   → Usar template da regra
   │
   ▼ (nenhuma aplicavel)
3. Regra Default (COMPACT)      → Status resumido basico
   │
   ▼ (falha no render)
4. Fallback de Emergencia       → "[STATUS] Operacoes normais"
```

---

## 7. Integracao com Sentinel Protocol

```
   Sentinel Hooks                     Status Maps
       │                                  │
       ▼                                  ▼
   PRE_DELEGATE ─────────────────► DELEGATION_PRE (if depth > 1)
   POST_DELEGATE ────────────────► DELEGATION_POST / COMPACT
   ON_ERROR ─────────────────────► ERROR_DEBUG
   ON_ANOMALY ───────────────────► ALERT embedded in template
   ON_SESSION_END ───────────────► SESSION_END
```

---

**Versao**: 1.0
**Criado por**: Claude-Orch-Prime-20260106-c614
**Data**: 2026-01-06

