# Evidence anchors — agentic-delegation (paráfrase + hash; zero quote cru — repo público)
> hash-recipe: sha256(rg -o "<60 primeiros chars da paráfrase, escapado>" <session-log>) · session-log: pi jsonl `2026-08-14T23-54-42-542Z_01a002b3-07ee-7d1c-a881-91048d8872b4.jsonl` (local, não commitado — logs são privados)

- E1: 2 spawns executor morreram com stdout vazio e rc=0 — delegação sem detecção de não-entrega; o lead só notou pelo arquivo ausente
  anchor: 615bde054493f0b7 · session-log mtime:2026-08-16T14:52Z
- E2: Canal claude/codex esgotou quota mid-loop; cadeia de fallback não estava codificada (improvisada)
  anchor: 31efcb1a605f044b · session-log mtime:2026-08-16T14:52Z
