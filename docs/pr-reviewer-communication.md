# PR Reviewer Communication Protocol

> **Version**: 1.0.0
> **Created**: 2026-01-30
> **Protocol**: Extension of C07 (PR Review Protocol)

## Overview

Este documento define o protocolo de comunicação com revisores de PR (bots e humanos) usando comentários como canal primário.

## Princípio Fundamental

> **"Existem diversas formas de comunicação - audio, texto, email, sinais. Para comunicar com revisores de PR (Copilot, qodo-code-review, CodeRabbit, humanos), use os comentários do PR como canal oficial."**

## Canais de Comunicação

| Revisor | Canal | Formato |
|---------|-------|---------|
| **Copilot** | PR comments | `@copilot-pull-request-reviewer` mention |
| **qodo-code-review** | PR comments | `@qodo-code-review` mention |
| **CodeRabbit** | PR comments | `@coderabbitai` mention |
| **Humanos** | PR comments | `@username` mention |

## Workflow de Comunicação

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PR REVIEWER COMMUNICATION WORKFLOW                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   1. RECEBER REVIEW                                                      │
│      └── Revisor posta comentários/suggestions                           │
│                                                                          │
│   2. ANALISAR FEEDBACK                                                   │
│      └── Classificar: crítico / médio / baixo / trade-off               │
│                                                                          │
│   3. APLICAR CORREÇÕES                                                   │
│      └── Commit com referência ao issue                                  │
│                                                                          │
│   4. COMUNICAR VIA PR COMMENT                                            │
│      └── @mention revisor + tabela de correções + request re-review     │
│                                                                          │
│   5. AGUARDAR RESPOSTA                                                   │
│      └── Verificar periodicamente por novos comentários                  │
│                                                                          │
│   6. ITERAR ATÉ APROVAÇÃO                                                │
│      └── Repetir 2-5 até todos issues resolvidos                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Template de Resposta

```markdown
@{reviewer-bot}

All {N} issues from your review have been addressed in commit(s) `{hash}`.

**Summary of fixes applied:**

| Your Finding | Fix Applied | Commit |
|--------------|-------------|--------|
| {issue 1} | {fix description} | {hash} |
| {issue 2} | {fix description} | {hash} |

**Test results:** All {N} tests passing ✅

Could you please re-review the changes?

---
*Communication via PR comments per C07 protocol*
```

## Boas Práticas

### DO (Fazer)

- ✅ Sempre mencionar o revisor com `@`
- ✅ Usar tabelas para resumir correções
- ✅ Referenciar commits específicos
- ✅ Incluir resultado dos testes
- ✅ Solicitar re-review explicitamente
- ✅ Documentar trade-offs aceitos

### DON'T (Não Fazer)

- ❌ Ignorar comentários de revisores
- ❌ Fazer merge sem responder feedback
- ❌ Assumir que correções serão detectadas automaticamente
- ❌ Esperar indefinidamente por resposta

## Timeouts

| Situação | Timeout | Ação |
|----------|---------|------|
| Aguardando re-review de bot | 10 min | Verificar novos comentários |
| Aguardando review humano | 30 min | Escalar ou delegar |
| Sem resposta após correções | 15 min | Considerar merge se críticos resolvidos |

## Integração com C07

Este protocolo estende C07 (PR Review Protocol) adicionando:

1. **Canal explícito**: PR comments como meio oficial
2. **Formato padrão**: Templates de comunicação
3. **Mentions obrigatórios**: `@revisor` para notificação
4. **Feedback loop**: Request re-review após correções

## Referências

- C07 - PR Review Protocol (`~/.claude/rules/pr-review-protocol.md`)
- GitHub PR Comments API
- Copilot PR Reviewer Documentation

---

*MAOS - Multi-Agent OS | Communication Protocol v1.0.0*
