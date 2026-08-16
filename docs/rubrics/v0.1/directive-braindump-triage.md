# Rubrica v0.1 — directive-braindump-triage

> PRÉ-REGISTRADA 2026-08-15 antes de qualquer avaliação (council D5).
> Critérios derivados de failure modes em traces reais (evidence). Todo critério tem âncora; um anchor pode fundamentar 2 critérios da mesma classe.
> Formulados como CLASSE de falha, não incidente único.

## C1 — Banner PROCESSED + ledger row atômicos
**Regra**: Toda triagem DEVE terminar com banner no source E row no ledger; um sem o outro = falha.
**Âncora**: evidence/directive-braindump-triage.md#E1

## C2 — DONE não é re-executado
**Regra**: Diretiva já satisfeita pelo corpus é classificada DONE/COVERED, nunca re-executada.
**Âncora**: evidence/directive-braindump-triage.md#E1
