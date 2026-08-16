# Rubrica v0.1 — agentic-delegation

> PRÉ-REGISTRADA 2026-08-15 antes de qualquer avaliação (council D5).
> Critérios derivados 1:1 de failure modes em traces reais (evidence/<skill>.md).
> Formulados como CLASSE de falha, não incidente único.

## C1 — Detecção de não-entrega
**Regra**: Toda delegação DEVE verificar o artefato esperado (arquivo/PR/output) após o spawn — stdout vazio com rc=0 ≠ sucesso; falta do artefato = spawn falho, ponto.
**Âncora**: evidence/agentic-delegation.md#E1

## C2 — Fallback-chain codificada
**Regra**: Delegação DEVE declarar a cadeia de canais alternativos ANTES do primeiro spawn (quota mata mid-loop).
**Âncora**: evidence/agentic-delegation.md#E2
