# Git Workflow Standard (Work)

> **Versão**: 1.0.0 (2026-01-22)
> **Status**: Aprovado
> **Propagado de**: `~/.claude/CLAUDE.md`
> **Nota**: Preferências pessoais (idioma, tom, formato) → `~/.claude/personal/CLAUDE.md`

---

## Padrões Corporativos

| Item | Padrão |
|------|--------|
| **Branches** | `{tipo}/{feature}-{identificador}` |
| **Commits** | Conventional Commits (feat, fix, docs, chore, refactor) |
| **PRs** | Sempre com descrição e checklist |
| **Worktrees** | Um por agente/tarefa (quando multi-agent) |
| **Co-Author** | `Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>` |

---

## Tipos de Branch

| Tipo | Uso |
|------|-----|
| `feat/` | Nova funcionalidade |
| `fix/` | Correção de bug |
| `chore/` | Manutenção, configuração |
| `docs/` | Documentação |
| `refactor/` | Refatoração sem mudança de comportamento |

---

## Conventional Commits

```
{tipo}({escopo}): {descrição curta}

{corpo opcional}

{footer opcional}
```

### Tipos

| Tipo | Descrição |
|------|-----------|
| `feat` | Nova funcionalidade |
| `fix` | Correção de bug |
| `docs` | Documentação |
| `style` | Formatação (sem mudança de lógica) |
| `refactor` | Refatoração |
| `test` | Testes |
| `chore` | Manutenção |

### Exemplo

```
feat(C02): add Entropia Zero rule v1.4.0

Added mandatory rule 4 to pre-execution checklist:
- Every action must leave storage MORE ORGANIZED or equal
- Never leave more disorganized than found

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

---

*Propagado automaticamente | v1.0.0*
