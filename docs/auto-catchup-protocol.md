# Auto Catch-up Protocol

<!-- ═══════════════════════════════════════════════════════════════════════════
     AUTO CATCH-UP PROTOCOL
     Propósito: Garantir continuidade entre sessões antes de compactação
     Versão: 1.0.0
     Criado: 2026-01-21
     Autor: Claude-Code
     ═══════════════════════════════════════════════════════════════════════════ -->

---

## Visão Geral

O **Auto Catch-up Protocol** define como gerar automaticamente um relatório de status antes que uma sessão Claude seja compactada por limite de contexto.

### Problema

Quando uma sessão atinge o limite de contexto (~200k tokens), o Claude automaticamente compacta o histórico, potencialmente perdendo:
- Decisões tomadas
- Contexto de tarefas em andamento
- Arquivos críticos referenciados
- Bloqueios conhecidos

### Solução

Gerar um **catch-up report** estruturado quando o contexto atinge ~80% (20% antes da compactação), seguindo o padrão definido em `~/.claude/CLAUDE.md`.

---

## Trigger Conditions

### Quando Gerar

| Condição | Ação |
|----------|------|
| Context usage >= 80% | Gerar automaticamente |
| Antes de pausar sessão longa | Gerar manualmente |
| Ao mudar de contexto/projeto | Gerar manualmente |
| Antes de handoff para outro agente | Gerar automaticamente |

### Como Detectar 80%

Atualmente, Claude Code não expõe diretamente o uso de contexto. Indicadores indiretos:

1. **Mensagem de aviso**: "Context is getting large..."
2. **Lentidão**: Respostas mais lentas que o normal
3. **Tempo de sessão**: Sessões longas (>2h) com muitas ferramentas
4. **Arquivos lidos**: >20 arquivos lidos na sessão

---

## Script de Geração

### Localização

```
~/.claude/scripts/auto-catchup.sh
```

### Uso

```bash
# Uso básico (gera com timestamp)
~/.claude/scripts/auto-catchup.sh

# Com nome de sessão específico
~/.claude/scripts/auto-catchup.sh "infra-worktree-migration"

# Com diretório de saída customizado
~/.claude/scripts/auto-catchup.sh "session-name" "/path/to/output"
```

### Output

Gera arquivo em: `~/.claude/sessions/catchup_<session-name>.md`

---

## Estrutura do Catch-up Report

O relatório segue o padrão de **Catch-up Padrão** do CLAUDE.md:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  CATCH-UP REPORT STRUCTURE                                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. O que já fizemos?        → Tarefas completadas                      │
│  2. O que falta fazer?       → Tarefas pendentes com prioridade         │
│  3. Status atual             → Diagrama visual de progresso             │
│  4. Próxima ação lógica      → Recomendação de continuidade             │
│  5. Short-name               → Identificador taxonômico da sessão       │
│  6. Contexto para próxima    → Arquivos, decisões, bloqueios            │
│  7. Metadados                → Timestamps, IDs                          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Integração com Workflow

### Durante a Sessão

1. **Início**: Verificar se existe catch-up report anterior
2. **Durante**: Manter TodoWrite atualizado para facilitar geração
3. **~80% context**: Executar `auto-catchup.sh`
4. **Compactação**: Catch-up é preservado no summary

### Handoff entre Agentes

Quando um agente passa trabalho para outro:

1. Agente A executa `auto-catchup.sh`
2. Agente A commit/push mudanças
3. Agente B lê catch-up report
4. Agente B continua do ponto salvo

---

## Integração com TodoWrite

O catch-up report pode ser gerado automaticamente a partir do TodoWrite:

```python
# Exemplo de integração futura
def generate_catchup_from_todos(todos):
    completed = [t for t in todos if t['status'] == 'completed']
    pending = [t for t in todos if t['status'] == 'pending']
    in_progress = [t for t in todos if t['status'] == 'in_progress']

    return {
        'completed': completed,
        'pending': sorted(pending, key=lambda x: x.get('priority', 99)),
        'in_progress': in_progress
    }
```

---

## Armazenamento

### Local

```
~/.claude/sessions/
├── catchup_20260121_143000.md
├── catchup_20260121_180000.md
├── catchup_infra-worktree-migration.md
└── index.json  # (futuro) índice de sessões
```

### Formato de Arquivo

- **Nome**: `catchup_<session-name>.md`
- **Formato**: Markdown
- **Tamanho típico**: 2-5 KB
- **Retenção**: 30 dias (configurável)

---

## Melhorias Futuras

### v1.1.0 (Planejado)

- [ ] Integração automática com TodoWrite
- [ ] Detecção de context usage via API
- [ ] Geração de JSON além de Markdown
- [ ] Hook de pre-compaction

### v1.2.0 (Planejado)

- [ ] Index de sessões com busca
- [ ] Linking automático entre sessões
- [ ] Métricas de produtividade
- [ ] Exportação para Confluence

---

## Referências

- `~/.claude/CLAUDE.md` - Catch-up Padrão (seção original)
- `~/.claude/docs/git-worktree-protocol.md` - Sessions registry
- `~/.claude/templates/worktree/sessions.json.template` - Session tracking

---

*Versão: 1.0.0 | Criado: 2026-01-21 | Autor: Claude-Code*
