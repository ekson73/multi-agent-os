# Status Map System v1.0

Sistema padronizado de visualizacoes ASCII para observabilidade humana em sessoes multi-agent.

## Proposito

Status Maps sao **visualizacoes estruturadas** projetadas para:
- Comunicar estado do sistema para humanos de forma rapida
- Padronizar output entre diferentes sessoes e agents
- Facilitar handoff entre sessoes
- Documentar contexto para debugging

## Estrutura do Diretorio

```
.claude/statusmap/
├── README.md                              ← Este arquivo
├── inference.md                           ← Regras de inferencia automatica
└── templates/
    └── statusmap_templates.md             ← TODOS os 8 templates (completo)
```

### Templates Disponiveis

| Template | Proposito | Tempo Alvo |
|----------|-----------|------------|
| `SESSION_START` | Estado inicial ao comecar sessao | 10s |
| `COMPACT` | Verificacao rapida entre tarefas | 5s |
| `DELEGATION_PRE` | Antes de delegar para sub-agent | 8s |
| `DELEGATION_POST` | Apos retorno de sub-agent | 10s |
| `PRE_COMMIT` | Validacao antes de commit | 8s |
| `ERROR_DEBUG` | Diagnostico quando ocorre erro | 15s |
| `SESSION_END` | Relatorio de handoff | 20s |
| `FULL_REPORT` | Relatorio completo para analise profunda | 60s |

## Uso Rapido

### Automatico (Inferencia)

O AI agent seleciona automaticamente o template baseado em:
- Evento atual (inicio, fim, erro, delegacao)
- Tempo desde ultimo status
- Estado do repositorio
- Solicitacao do usuario

### Manual (Override)

Comandos disponiveis:
- `/status` → COMPACT
- `/status full` → FULL_REPORT
- `/status debug` → ERROR_DEBUG
- `/status start` → SESSION_START
- `/status end` → SESSION_END

## Design Principles

1. **Cognitive Load Minimizado**: Tempo alvo de absorcao definido por template
2. **Hierarquia Visual**: Informacoes criticas no topo
3. **Scanability**: Facil encontrar informacao especifica
4. **Consistencia**: Mesmos padroes visuais em todos templates
5. **Actionability**: Indicacao clara do que precisa de acao

## Convencoes Visuais

### Box Drawing Characters
```
Simples:  ┌─┬─┐ │ ├─┼─┤ └─┴─┘
Duplo:    ╔═╦═╗ ║ ╠═╬═╣ ╚═╩═╝
```

### Indicadores de Estado
```
🟢 OK / Success / Clean
🟡 Warning / Attention needed
🔴 Error / Critical / Blocked
⚪ Unknown / N/A
```

### Fallback (sem emoji)
```
[OK]   → Estado normal
[WARN] → Atencao necessaria
[FAIL] → Erro/bloqueio
[????] → Desconhecido
```

## Campos Padronizados

| Campo | Tipo | Descricao |
|-------|------|-----------|
| `timestamp` | ISO 8601 | Momento do status |
| `session_id` | String | ID da sessao atual |
| `git_branch` | String | Branch atual |
| `git_status` | Enum | clean/dirty/conflict |
| `active_agents` | Int | Agents rodando |
| `pending_tasks` | Int | Tarefas pendentes |
| `health_score` | Int | Score Sentinel 0-100 |
| `next_action` | String | Proxima acao sugerida |

## Documentacao Completa

O arquivo `templates/statusmap_templates.md` contem para CADA template:

1. **Exemplo Preenchido** - Com dados realistas do projeto VKS
2. **Esqueleto com Placeholders** - `{campo}` para substituicao
3. **Tabela de Campos** - Required vs Optional, descricao

### Exemplo Rapido (COMPACT)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ QUICK STATUS │ 2026-01-06 12:45:00 │ Claude-Orch-Prime-20260106-c614       │
├─────────────────────────────────────────────────────────────────────────────┤
│ GIT:      main [OK] │ 3M 2U │ ahead 0                                      │
│ AGENTS:   1 active  │ 0 pending │ depth: 1/3                               │
│ SENTINEL: 98/100    │ 0 alerts  │ hooks: enabled                           │
│ NEXT:     Create templates (HIGH)                                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Integracao com Sentinel Protocol

Status Maps complementam o Sentinel Protocol:

| Aspecto | Sentinel | Status Maps |
|---------|----------|-------------|
| Formato | JSON (maquina) | ASCII (humano) |
| Proposito | Audit, analise | Visibilidade rapida |
| Storage | Persistente (.jsonl) | Efemero (display) |
| Trigger | Automatico (hooks) | Manual ou on-demand |
| Detalhe | Completo | Resumido |

---

**Versao**: 1.0
**Atualizado**: 2026-01-06
**Criado por**: Claude-Orch-Prime-20260106-c614

