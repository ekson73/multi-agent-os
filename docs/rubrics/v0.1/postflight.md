# Rubrica v0.1 — postflight

> PRÉ-REGISTRADA 2026-08-15 antes de qualquer avaliação (council D5).
> Critérios derivados 1:1 de failure modes em traces reais (evidence/<skill>.md).
> Formulados como CLASSE de falha, não incidente único.

## C1 — WIP-alheio detectado e isolado
**Regra**: O relatório DEVE distinguir arquivos sujos por sessão-owner (git status × sessões ativas); tocar WIP alheio = falha fatal.
**Âncora**: evidence/postflight.md#E1

## C2 — Nada unpushed do owner atual
**Regra**: Commits locais da sessão atual sem push = postflight FALHOU.
**Âncora**: evidence/postflight.md#E1
