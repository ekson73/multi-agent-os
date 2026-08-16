# Rubrica v0.1 — quiesce

> PRÉ-REGISTRADA 2026-08-15 antes de qualquer avaliação (council D5).
> Critérios derivados de failure modes em traces reais (evidence). Todo critério tem âncora; um anchor pode fundamentar 2 critérios da mesma classe.
> Formulados como CLASSE de falha, não incidente único.

## C1 — Loose-end sweep cobre worktrees alheios
**Regra**: Antes de declarar quiescência, o relatório DEVE listar commits locais unpushed em TODOS os worktrees (incluindo de outras sessões) — marcados como owner-alheio, nunca colhidos.
**Âncora**: evidence/quiesce.md#E1

## C2 — External-quota vs gate-real distinguível
**Regra**: Checks falhos DEVEM ser classificados como [externo-quota | gate-real] com evidência (msg de erro) antes de qualquer merge; ausência da classificação = quiesce inválido.
**Âncora**: evidence/quiesce.md#E2

## C3 — Veredito-stale check
**Regra**: Se reviewDecision está pinned a commit antigo, o relatório DEVE medir findings contra o head atual, nunca contra o veredito.
**Âncora**: evidence/quiesce.md#E2
