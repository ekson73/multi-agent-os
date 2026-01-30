# PR Reviewer Communication Protocol

<!-- Auto-loaded rule | Version: 1.0.0 | 2026-01-30 -->
<!-- Full spec: docs/pr-reviewer-communication.md -->

## Princípio Fundamental

```
┌────────────────────────────────────────────────────────────────────────┐
│  PARA COMUNICAR COM REVISORES DE PR: USE COMENTÁRIOS DO PR            │
├────────────────────────────────────────────────────────────────────────┤
│  Canal: PR Comments (não email, não chat, não issues)                  │
│  Formato: @mention + tabela de correções + request re-review          │
│  Revisores: Copilot, qodo-code-review, CodeRabbit, humanos            │
└────────────────────────────────────────────────────────────────────────┘
```

## Workflow Rápido

1. **Receber review** → Analisar feedback
2. **Aplicar correções** → Commit com referência
3. **Comunicar** → `@revisor` + tabela + re-review request
4. **Aguardar** → Verificar novos comentários
5. **Iterar** → Repetir até aprovação

## Mentions por Revisor

| Revisor | Mention |
|---------|---------|
| Copilot | `@copilot-pull-request-reviewer` |
| qodo | `@qodo-code-review` |
| CodeRabbit | `@coderabbitai` |
| Humano | `@username` |

## Template de Resposta

```markdown
@{reviewer}

All {N} findings have been addressed.

| Finding | Fix | Commit(s) |
|---------|-----|-----------|
| ... | ... | `{hash}` |

Tests: {N}/{N} passing ✅

Could you please re-review?
```

## Timeouts

| Situação | Timeout | Ação |
|----------|---------|------|
| Re-review bot | 15 min | Verificar comentários |
| Review humano | 4 horas | Lembrete amigável no PR |
| Sem resposta (bot) | 30 min | Merge se críticos OK |
| Sem resposta (humano) | 1 dia útil | Escalar para líder |

---
*Extends C07 (PR Review Protocol) | Full spec: `docs/pr-reviewer-communication.md`*
