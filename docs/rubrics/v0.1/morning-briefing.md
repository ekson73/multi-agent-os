# Rubrica v0.1 — morning-briefing

> PRÉ-REGISTRADA 2026-08-15 antes de qualquer avaliação (council D5).
> Critérios derivados de failure modes em traces reais (evidence). Todo critério tem âncora; um anchor pode fundamentar 2 critérios da mesma classe.
> Formulados como CLASSE de falha, não incidente único.

## C1 — Idempotency guard ativo
**Regra**: Re-invocação ≤5min após briefing anterior DEVE emitir aviso ou degradar para --quick (anti-recursion).
**Âncora**: evidence/morning-briefing.md#E1

## C2 — Zero-counts transparentes
**Regra**: Seções vazias são omitidas do corpo MAS o Pulse mostra os zeros — nunca omitir a contagem.
**Âncora**: evidence/morning-briefing.md#E1
