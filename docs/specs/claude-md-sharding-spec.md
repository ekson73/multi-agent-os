# CLAUDE.md Sharding Specification

> **Versão**: 1.0.0 (2026-01-25)
> **Status**: Draft
> **Autor**: Claude-Code
> **Sessão**: ef47 (continuação)

---

## 1. Análise do Problema

### 1.1 Estado Atual

| Métrica | Valor |
|---------|-------|
| Tamanho total | 55 KB (1576 linhas) |
| Seções [CXX] | 58.4% (32 KB) |
| Outras seções | 40.7% (23 KB) |
| Seções já shardadas | 5 (com duplicação) |
| Seções críticas | 10 |
| Seções não-críticas | 8 |

### 1.2 Problemas Identificados

1. **Context consumption**: CLAUDE.md consome ~55KB de contexto em TODA sessão
2. **Duplicação**: Seções já têm shards em `docs/` mas mantêm conteúdo completo
3. **Over-specification**: Informação detalhada que não é usada na maioria das sessões
4. **Degradação**: Performance degrada quando contexto > 75% utilização

### 1.3 Boas Práticas (Fontes)

| Prática | Fonte |
|---------|-------|
| Manter CLAUDE.md conciso e legível | [Anthropic Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices) |
| "Ruthlessly prune" - deletar instruções redundantes | [ClaudeLog](https://claudelog.com/faqs/what-is-claude-code-auto-compact/) |
| Qualidade de contexto > quantidade | [Context Engineering Secrets](https://01.me/en/2025/12/context-engineering-from-claude/) |
| Progressive disclosure via Skills | [Claude Code Docs](https://code.claude.com/docs/en/best-practices) |
| Sessions que param em 75% produzem código de maior qualidade | [AIMultiple Research](https://research.aimultiple.com/agentic-coding/) |

---

## 2. Estratégia de Sharding

### 2.1 Princípios

```
┌────────────────────────────────────────────────────────────────────────┐
│  CLAUDE.md = SUMÁRIO EXECUTIVO + REFERÊNCIAS                          │
│  docs/     = ESPECIFICAÇÕES DETALHADAS (on-demand)                    │
│  rules/    = REGRAS CRÍTICAS AUTO-LOAD (< 500 linhas cada)           │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Critérios de Classificação

| Tipo | Critério | Destino | Auto-Load |
|------|----------|---------|-----------|
| **Crítico** | Usado em TODA sessão, regra mandatória | CLAUDE.md | SIM |
| **Frequente** | Usado em > 50% das sessões, curto | rules/ | SIM |
| **Ocasional** | Usado em < 50% das sessões, detalhado | docs/ | NÃO |
| **Raro** | Referência histórica, templates | docs/ | NÃO |

### 2.3 Classificação das Seções

#### 🔴 MANTER EM CLAUDE.md (Crítico - Auto-load)

| Seção | Tamanho | Justificativa |
|-------|---------|---------------|
| Ação Obrigatória ao Iniciar | 798 B | Primeiro item lido |
| Arquitetura de Contexto | 2.4 KB | Explica rules/ vs docs/ |
| [C01] Core Directive | 492 B | Diretiva fundamental |
| [C02] Main Instructions | 3.8 KB | Regras mandatórias |
| [C07] Versioning Standard | 1.4 KB | Controle de versão |
| [C08] Insights Management | 1.7 KB | Persistência de aprendizados |
| [C10] End-of-Interaction | 540 B | Checklist de encerramento |
| Staging: Novas Instruções | 1.3 KB | Área de processamento |
| Master Changelog | 2.5 KB | Histórico de mudanças |
| **TOTAL** | **~15 KB** | **Core essencial** |

#### 🟡 REDUZIR PARA SUMÁRIO (Já têm shard externo)

| Seção | Atual | Após | Shard |
|-------|-------|------|-------|
| [C04] Git Worktree Protocol | 7.4 KB | ~400 B | `docs/git-worktree-protocol.md` |
| [C06] AI-Native Environment | 5.9 KB | ~400 B | `docs/ai-native-environment.md` |
| [C07] PR Review Protocol | 2.0 KB | ~400 B | `rules/pr-review-protocol.md` |
| Arquitetura Multi-Repo S9 | 2.1 KB | ~400 B | `docs/dot-claude-multi-repo-spec.md` |
| **ECONOMIA** | **17.4 KB** | **1.6 KB** | **-15.8 KB** |

#### 🟢 MOVER PARA docs/ (Criar novo shard)

| Seção | Tamanho | Novo Shard |
|-------|---------|------------|
| [C03] Ralph Loop Pattern | 1.7 KB | `docs/ralph-loop-pattern.md` |
| [C05] Session Report Standard | 4.3 KB | `docs/session-report-standard.md` |
| [C09] Naming Conventions | 1.9 KB | `docs/naming-conventions.md` |
| [C11] Session Audit & Archive | 1.2 KB | `docs/session-audit-standard.md` |
| Glossário de Termos Globais | 1.2 KB | `docs/glossary-global-terms.md` |
| Git Workflow Standard | 1.0 KB | `docs/git-workflow-standard.md` |
| Estrutura de Projetos | 600 B | `docs/project-structure.md` |
| Matriz RACI Padrão | 500 B | `docs/raci-matrix.md` |
| **ECONOMIA** | **12.4 KB** | **~2.4 KB (sumários)** | **-10 KB** |

---

## 3. Tamanho Projetado

### 3.1 Antes vs Depois

| Componente | Antes | Depois | Economia |
|------------|-------|--------|----------|
| Seções críticas | 15 KB | 15 KB | 0 |
| Seções já shardadas | 17.4 KB | 1.6 KB | -15.8 KB |
| Seções a shardar | 12.4 KB | 2.4 KB | -10 KB |
| **TOTAL** | **~55 KB** | **~19 KB** | **-36 KB (65%)** |

### 3.2 Validação

```
┌────────────────────────────────────────────────────────────────────────┐
│  TARGET: CLAUDE.md < 20 KB                                             │
│  RESULTADO: ~19 KB ✅                                                  │
│  ECONOMIA: 36 KB (65% redução)                                         │
│  RULES/ AUTO-LOAD: ~18 KB adicional                                    │
│  TOTAL AUTO-LOAD: ~37 KB (otimizado vs 55 KB original)                │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Formato de Sumário

### 4.1 Template para Seções Shardadas

```markdown
## [CXX] Nome da Seção

> **Versão**: X.Y.Z (YYYY-MM-DD)
> **Spec completa**: `~/.claude/docs/nome-shard.md`

| Item | Valor |
|------|-------|
| Propósito | [1 linha] |
| Regra crítica | [1 linha] |

### Quick Reference
[Tabela com 2-3 itens mais importantes]

---
```

### 4.2 Exemplo: C04 Git Worktree (Reduzido)

```markdown
## [C04] Git Worktree Protocol

> **Versão**: 2.0.0 (2026-01-21)
> **Spec completa**: `~/.claude/docs/git-worktree-protocol.md`

| Item | Valor |
|------|-------|
| Propósito | Isolamento de trabalho para multi-agent |
| Regra | Worktree OBRIGATÓRIO para modificações |

### Quick Reference

| Comando | Descrição |
|---------|-----------|
| `git worktree add .worktrees/{name} -b {branch}` | Criar |
| `git worktree list` | Listar |
| `git worktree remove {path}` | Remover |

**Exceções**: READ-ONLY, APPEND-ONLY em coordination files, solicitação EXPLÍCITA do usuário.

---
```

---

## 5. Plano de Implementação

### Fase 1: Criar Shards Faltantes (P1)

| Ordem | Arquivo | Fonte |
|-------|---------|-------|
| 1 | `docs/session-report-standard.md` | Seção [C05] |
| 2 | `docs/ralph-loop-pattern.md` | Seção [C03] |
| 3 | `docs/naming-conventions.md` | Seção [C09] |
| 4 | `docs/session-audit-standard.md` | Seção [C11] |

### Fase 2: Criar Shards Auxiliares (P2)

| Ordem | Arquivo | Fonte |
|-------|---------|-------|
| 5 | `docs/glossary-global-terms.md` | Seção Glossário |
| 6 | `docs/git-workflow-standard.md` | Seção Git Workflow |
| 7 | `docs/project-structure.md` | Seção Estrutura |
| 8 | `docs/raci-matrix.md` | Seção Matriz RACI |

### Fase 3: Reduzir CLAUDE.md (P1)

1. Substituir seções completas por sumários
2. Remover duplicações
3. Validar tamanho final < 20 KB

### Fase 4: Validação (P1)

1. Testar nova sessão com CLAUDE.md shardado
2. Verificar se regras críticas são aplicadas
3. Verificar se shards são carregados on-demand

---

## 6. Riscos e Mitigações

| Risco | Mitigação |
|-------|-----------|
| Regra crítica movida para docs/ (não auto-load) | Checklist de classificação + validação |
| Shards desatualizados | Incluir versão no sumário + cross-reference |
| Quebra de fluxo de sessões existentes | Implementação gradual em fases |
| Perda de contexto histórico | Master Changelog permanece em CLAUDE.md |

---

## 7. Métricas de Sucesso

| Métrica | Target | Atual |
|---------|--------|-------|
| Tamanho CLAUDE.md | < 20 KB | 55 KB |
| Tempo de carregamento inicial | Redução mensurável | Baseline |
| Regras críticas aplicadas | 100% | 100% |
| Shards criados | 8 novos | 0 |
| Sumários substituindo seções | 12 | 0 |

---

## 8. Changelog

| Versão | Data | Descrição |
|--------|------|-----------|
| 1.0.0 | 2026-01-25 | Versão inicial do spec |

---

*Assinatura: Claude-Code | 2026-01-25T15:30:00-03:00*
