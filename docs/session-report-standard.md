# Session Report Standard

> **Versão**: 1.1.0 (2026-01-21)
> **Status**: Aprovado
> **Propagado de**: `~/.claude/CLAUDE.md` [C05]

---

## Propósito

Padronização de relatórios de sessão para evitar conflitos entre agentes paralelos.

---

## Localização e Nomenclatura

```
ÚNICO DIRETÓRIO: .claude/sessions/
NOME DO ARQUIVO: {YYYY-MM-DD}_{SSID}_{TYPE}.md
```

| Campo | Formato | Como obter |
|-------|---------|------------|
| `YYYY-MM-DD` | ISO 8601 | Data atual |
| `SSID` | 4 chars lowercase | `uuidgen \| cut -c1-4 \| tr '[:upper:]' '[:lower:]'` |
| `TYPE` | kebab-case | `catchup`, `completion`, `handoff`, `incident`, `decision` |

**Exemplo**: `2026-01-21_a1b2_catchup.md`

---

## 10 Seções Obrigatórias

| # | Seção | Descrição |
|---|-------|-----------|
| 1 | O que já fizemos? | Tabela: `\| # \| Tarefa \| Status \| Evidência \|` |
| 2 | O que falta fazer? | Por prioridade P1/P2/P3 com bloqueios |
| 3 | O que precisamos fazer? | Ações bloqueantes (box `┌────┐` para urgências) |
| 4 | O que é bom fazermos? | Nice-to-have (separar de obrigatórios) |
| 5 | Qual nosso status? | Métricas, health check, bloqueios |
| 6 | Objetivo principal do projeto/repo | Propósito e entregáveis |
| 7 | Objetivo principal da sessão | + Resultado: SUCESSO/PARCIAL/FALHA |
| 8 | Objetivos secundários da sessão | Status de cada meta |
| 9 | Próxima ação lógica | Recomendação clara + comandos prontos |
| 10 | Short-name taxonômico | Formato: `{tipo}/{escopo}+{categoria}/{detalhe}` |

---

## Metadados Obrigatórios

### Início do arquivo

```markdown
# Session Report: {SHORT_NAME}

> **Session ID**: {ID_COMPLETO_SE_DISPONÍVEL}
> **SSID**: {4_CHARS}
> **Date**: {YYYY-MM-DD}
> **Time**: {HH:MM:SS-TZ}
> **Type**: {catchup|completion|handoff|incident|decision}
> **Agent**: {NOME_DO_AGENTE}
> **Project**: {NOME_DO_PROJETO}
```

### Fim do arquivo

```markdown
---
*Assinatura: {AGENT_NAME} | {YYYY-MM-DDTHH:MM:SS-TZ}*
```

---

## Short-name Taxonomia

```
{tipo}/{escopo}+{categoria}/{detalhe}
```

| Componente | Valores | Exemplo |
|------------|---------|---------|
| `tipo` | fix, feat, chore, docs, refactor | `fix/` |
| `escopo` | Problema/feature principal | `lfs-pointers` |
| `categoria` | pattern, migration, setup, validation, sync | `+pattern/` |
| `detalhe` | Especificação adicional | `worktree-gitignore` |

**Exemplo**: `fix/lfs-pointers+pattern/worktree-gitignore`

---

## Regras de Conflito (Multi-Agent)

- Se já existir arquivo com mesmo SSID e TYPE na mesma data → **ATUALIZAR** existente
- Se for agente diferente (SSID diferente) → **CRIAR** novo arquivo
- **NUNCA** sobrescrever arquivo de outro agente

---

## Git Policy

```
.claude/sessions/ → COMMITAR (não ignorar)
```

| Razão | Benefício |
|-------|-----------|
| Continuidade | Agentes futuros leem histórico |
| Handoff | Transferência documentada |
| Auditoria | Rastreabilidade de decisões |

---

## Propagação para Repositórios

Ao iniciar sessão em qualquer repositório, o agente local DEVE verificar:

1. **Diretório**: `.claude/sessions/` existe?
2. **CLAUDE.md**: Referencia o Session Report Standard?
3. **Shard local**: `.claude/docs/session-report-standard.md` existe?

---

## Versão Compacta (1 linha)

```
Salve `.claude/sessions/{YYYY-MM-DD}_{SSID}_catchup.md`: 1-10 seções. SSID=4chars. Assinar ISO.
```

---

## Changelog

| Versão | Data | Mudanças |
|--------|------|----------|
| 1.0.0 | 2026-01-21 | Versão inicial |
| 1.1.0 | 2026-01-21 | Git Policy, propagação automática |

---

*Propagado automaticamente | v1.1.0*
