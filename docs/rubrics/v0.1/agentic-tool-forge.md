# Rubrica v0.1 — agentic-tool-forge

> PRÉ-REGISTRADA 2026-08-15 antes de qualquer avaliação (council D5).
> Critérios derivados de failure modes em traces reais (evidence). Todo critério tem âncora; um anchor pode fundamentar 2 critérios da mesma classe.
> Formulados como CLASSE de falha, não incidente único.

## C1 — Recon anti-re-learning obrigatório
**Regra**: Antes de mint, DEVE existir busca por ferramenta existente com veredito explícito (compose-not-fork); mint sem recon = REJEITADO.
**Âncora**: evidence/agentic-tool-forge.md#E1

## C2 — Veredito double-forge-risk registrado
**Regra**: Se ferramenta irmã cobre ≥50%, o forge DEVE parar e rotear — nunca forjar paralelo.
**Âncora**: evidence/agentic-tool-forge.md#E1
