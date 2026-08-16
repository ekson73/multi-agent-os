# Rubrica v0.1 — praxis-audit

> PRÉ-REGISTRADA 2026-08-15 antes de qualquer avaliação (council D5).
> Critérios derivados 1:1 de failure modes em traces reais (evidence/<skill>.md).
> Formulados como CLASSE de falha, não incidente único.

## C1 — Auditar o head, não o veredito
**Regra**: Toda auditoria de PR DEVE re-medir findings contra o headRefOid atual; veredito pinned a commit antigo é registrado como stale, não como verdade.
**Âncora**: evidence/praxis-audit.md#E1

## C2 — Recount antes de concordar
**Regra**: Toda métrica citada num audit DEVE ser re-computada pelo auditor (grep/probe próprio), nunca lida do claim.
**Âncora**: evidence/praxis-audit.md#E1
