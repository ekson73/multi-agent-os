# Session Audit & Archive Standard

> **Versão**: 1.1.0 (2026-01-22)
> **Status**: Aprovado
> **Propagado de**: `~/.claude/CLAUDE.md` [C11]

---

## Propósito

Garantir que sessões declaradas como 100% completas sejam verificadas antes de serem arquivadas, e que sessões finalizadas tenham um processo claro de arquivamento.

---

## Regra de Auditoria

```
┌────────────────────────────────────────────────────────────────────────┐
│  REGRA: Sessões 100% DEVEM ser auditadas antes de arquivamento        │
│  MÉTODO: Verificar cada claim com evidência objetiva                  │
│  RESULTADO: verified_complete (100%) ou verified_partial (N%)         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Checklist de Auditoria

Para cada sessão com status 100%:

| # | Verificação | Método | Critério |
|---|-------------|--------|----------|
| 1 | Arquivos existem | `ls -la {path}` | Arquivo presente com tamanho > 0 |
| 2 | Commits existem | `git log --oneline --grep="{msg}"` | Hash confirmado |
| 3 | PRs merged | `gh pr list --state merged` | PR listado |
| 4 | Working directory | `git status` | Limpo (no uncommitted changes) |
| 5 | Branch sincronizada | `git diff origin/{branch}..HEAD` | Sem divergência |

---

## Formato de Auditoria

Adicionar ao session report:

```markdown
## Auditoria (C11)

> **Auditor**: {Agent-Name}
> **Data**: {YYYY-MM-DD}
> **Protocolo**: Session Audit Standard v1.1.0

### Claims Verificados

| # | Claim | Evidência | Status |
|---|-------|-----------|--------|
| 1 | {descrição} | {evidência objetiva} | ✅/❌ |

### Resultado

| Métrica | Valor |
|---------|-------|
| Claims verificados | N/N |
| Penalidades | 0% |
| **Status Final** | verified_complete / verified_partial (N%) |
```

---

## Estados de Sessão

| Estado | Código | Descrição |
|--------|--------|-----------|
| `pending` | 0-25% | Não iniciada ou início |
| `in_progress` | 25-75% | Em andamento |
| `review_pending` | 75-99% | Aguardando revisão/auditoria |
| `verified_partial` | N% | Auditada, parcialmente completa |
| `verified_complete` | 100% | Auditada e verificada |
| `archived` | — | Arquivada (somente após verified_complete) |

---

## Processo de Arquivamento

```
┌─────────────────────────────────────────────────────────────────────────┐
│  FLUXO DE ARQUIVAMENTO                                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌──────────────┐     ┌──────────────┐     ┌──────────────┐           │
│   │   SESSÃO     │────►│   AUDITORIA  │────►│  ARQUIVAR    │           │
│   │   100%       │     │   C11        │     │  (se 100%)   │           │
│   └──────────────┘     └──────────────┘     └──────────────┘           │
│                              │                                          │
│                              ▼                                          │
│                        ┌──────────────┐                                 │
│                        │ < 100%?      │                                 │
│                        │ CORRIGIR     │                                 │
│                        │ session      │                                 │
│                        └──────────────┘                                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Arquivamento de Sessões

Sessões `verified_complete` podem ser movidas para:

```
{repo}/.claude/sessions/archive/{YYYY-MM}/
```

Manter no diretório principal apenas:
- Últimas 5 sessões ativas
- Sessões com pendências (< 100%)

---

## Arquivamento em Cadeia

Sessões podem ser arquivadas **INDEPENDENTEMENTE** do status de sessões descendentes:

```
X (100% ✅) → Y (100% ✅) → Z (em progresso)
    │             │
 arquivar ✅   arquivar ✅    (não precisa esperar Z)
```

| Cenário | Permitido? | Razão |
|---------|------------|-------|
| Arquivar X mesmo se Y em progresso | ✅ Sim | X não depende de Y |
| Arquivar X e Y mesmo se Z em progresso | ✅ Sim | Dependência é unidirecional |

**Justificativa**:
1. **Dependência unidirecional**: Filhos leem pais (X ← Y ← Z), não o contrário
2. **Imutabilidade**: Sessões 100% são read-only; arquivar não altera conteúdo
3. **Acessibilidade**: Arquivamento é reorganização, não exclusão
4. **Rastreabilidade**: Campo `Parent Session` preserva cadeia histórica

---

## Propagação

Este padrão se aplica a TODOS os repositórios que usam C05 Session Report Standard.

---

*Propagado automaticamente | v1.1.0*
