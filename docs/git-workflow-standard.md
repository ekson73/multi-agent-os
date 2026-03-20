# Git Workflow Standard (Work)

> **Versão**: 2.0.0 (2026-03-20)
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
| **Worktrees** | OBRIGATÓRIO para todas as modificações (ver `git-worktree-protocol.md`) |
| **Co-Author** | OBRIGATÓRIO para AI — ver `co-author-standard.md` |
| **Bootstrap** | OBRIGATÓRIO para agents — ver `agent-bootstrap-protocol.md` |

### Co-Author Format (MANDATORY for AI Agents)

```text
Co-Authored-By: {AgentName} ({Provider}/{Model}) <noreply+{agent}@{provider-domain}>
```

Formato obrigatório que identifica as **3 entidades**:
- **AgentName**: nome do agente (Claude-Code, Antigravity, Amazon-Q, Copilot)
- **Provider**: empresa do AI provider (Anthropic, Google, Amazon, GitHub)
- **Model**: LLM específico (Claude-4-Sonnet, Gemini-2.5-Pro, GPT-4o)

Exemplos:
```
Co-Authored-By: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>
Co-Authored-By: Antigravity (Google/Gemini-2.5-Pro) <noreply+antigravity@google.com>
Co-Authored-By: Amazon-Q (Amazon/Nova-Pro) <noreply+amazon-q@amazon.com>
Co-Authored-By: Copilot (GitHub/GPT-4o) <copilot@users.noreply.github.com>
```

Full spec: [`docs/co-author-standard.md`](co-author-standard.md)

---

## Tipos de Branch

| Tipo | Uso |
|------|-----|
| `feature/` | Nova funcionalidade |
| `bugfix/` | Correção de bug não-urgente → develop |
| `hotfix/` | Correção de produção urgente → master + develop |
| `chore/` | Manutenção, configuração |
| `docs/` | Documentação |
| `refactor/` | Refatoração sem mudança de comportamento |

> **DEPRECATED**: `fix/` — usar `bugfix/` para non-urgent, `hotfix/` para urgent

### Migration from v1.0.0

- Existing `fix/*` branches may be merged as-is
- New branches MUST use `bugfix/` (non-urgent → develop) or `hotfix/` (urgent → master + develop)
- CI pipelines keep backward-compat with `fix/*` (git-provider agnostic)

---

## Conventional Commits

```
{tipo}({escopo}): {descrição curta}

{corpo opcional}

Co-Authored-By: {AgentName} ({Provider}/{Model}) <noreply+{agent}@{provider-domain}>
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
feat(auth): add OAuth2 login flow

Implemented Google OAuth2 authentication with PKCE.
Added token refresh mechanism and session management.

Co-Authored-By: Antigravity (Google/Gemini-2.5-Pro) <noreply+antigravity@google.com>
```

---

## Agent Bootstrap (MANDATORY)

Before writing ANY file, AI agents MUST execute the
[Agent Bootstrap Protocol](agent-bootstrap-protocol.md).

---

*v2.0.0 | 2026-03-20 | Updated Co-Author format to 3-entity standard. Added Agent Bootstrap reference. Aligned branch types with D16 Git Flow.*
*v1.0.0 | 2026-01-22 | Initial version*
