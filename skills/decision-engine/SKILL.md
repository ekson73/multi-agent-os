---
name: decision-engine
description: |
  Route each HITL item to DIY, COMPUTE or HITL by fixed, deterministic rules, so the
  operator only sees what is really theirs. Reads the JSON of the synopsis-panel engine
  (synopsis-fuse.py --hitl-only --format json), a list of items, or one item, and returns
  one verdict per item - route, rule, reason, recommendation, alternatives. The five SSOT
  HITL types (credencial, gasto, irreversivel, envio, negocio) go to HITL with a
  recommendation; technical decisions go to DIY; an unknown type goes to COMPUTE; an
  already-leaked secret is denied without rotation (operator policy, overridable). Thin
  skill: reuses the synopsis-panel option builder, never mutates the ledger, never
  authorizes anything. Use when the operator or an agent asks "which HITL is really mine",
  "route the HITL queue", "decision engine", "pre-decide the digest", "DIY or HITL".
prompt_version: "0.1.0"
type: skill
spec: AAIF / agentskills.io
applicable_hosts: [Claude Code, Cursor, GitHub Copilot, Aider, any AAIF-compliant agent]
allowed-tools: [Bash, Read]
cycles_completed: 0
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: work-landscape
  cross_link_slug: decision-engine
  dogfood_status: forged-not-yet-dogfooded
triggers:
  - decision engine
  - route the hitl queue
  - which hitl is mine
  - diy or hitl
  - pre-decide the digest
---

# decision-engine

The missing middle step of the HITL resolution order "DIY -> decision engine ->
compute -> human". The `/hitl-digest` command shows the queue; this skill says, per
item, who should act and what the recommended answer is.

## O que é (e o que NÃO é)

| Faz | NÃO faz |
|---|---|
| roteia cada item HITL: `DIY` · `COMPUTE` · `HITL` | **não** muta o ledger (`hitl-punch-list.py` + `punch-list.md`) |
| anexa recomendação + alternativas aos itens `HITL` | **não** autoriza nada: `HITL` continua sendo do humano |
| reusa as opções por tipo do `synopsis-panel` (`_card_options`) | **não** reimplementa render, opções ou agregação |
| regras fixas, mesma entrada = mesma saída | **não** usa modelo: o candidato Laya foi medido e rejeitado no backlog (#555 cita a medição) |

## Regras (a primeira que casa vence)

| Regra | Quando | Rota |
|---|---|---|
| `R0-leaked-secret` | `credencial` sobre segredo/PII já vazado, exposto ou comprometido (rotação planejada NÃO conta) | `DIY`, `denied: true` (sem rotação) |
| `R1-human-type` | tipo é um dos 5 do SSOT | `HITL` com recomendação |
| `R2-guard` | item técnico que cita produção/irreversível, gasto, envio ou ato explícito de conta/segurança/uso de dados pessoais reais | `HITL` |
| `R3-technical` | tipo técnico (`tecnico`, `tatico`, `operacional`, ...) | `DIY` |
| `R4-unknown` | tipo ausente ou desconhecido | `COMPUTE` (classificar e recalcular) |

`recommendation_basis` diz de onde veio a recomendação: `evidence` (opção estruturada
com `recommended: true` e `evidence` não vazia) ou `type-default:<fonte>` (a primeira
disposição do tipo, sem evidência). Ler `type-default` como recomendação com evidência
é erro.

A política `R0` vem do operador: vazamento já existente é ignorado, sem pedir rotação.
Para voltar ao comportamento de escalar, passe `--policy` com
`{"leaked_secret": "escalate"}`. Política inválida (chave ou valor desconhecido, JSON
quebrado) sai com exit `2`; nunca é adivinhada.

O guard `R2` reconhece ação + objeto: mudar permissões/configurações da conta,
ativar/desativar MFA, aceitar verificação de segurança do provedor ou usar dados
pessoais reais. `conta` ou `dados` isolados não bastam: parsing de conta sintética,
fixtures de dados sintéticos e formas explícitas reconhecidas de implementação local
de testes/mocks continuam técnicos, mesmo descrevendo a funcionalidade de MFA/permissões.
O ato deve ser apenas a descrição da funcionalidade: alvo real, produção, outro pedido
sensível ou alvo não reconhecido como sintético continuam HITL. Uma palavra `mock`
ou `teste` solta não retira o gate. É proteção lexical limitada, não classificação
universal de HUMAN_DOMAIN.
O pedido é avaliado por campo (`decidir`, `titulo`, `title`, incluindo o fallback
legado): título descritivo benigno não vira sufixo da ação local. Escopo real,
produção, alvo indefinido ou outro pedido sensível em qualquer campo mantêm o gate.
As quatro classes reconhecem também gerúndios PT/EN, sem pretensão de flexão universal.
A negação operacional só neutraliza o ato quando ligada diretamente ao verbo;
urgência e propostas retóricas `why not` / `por que não` não declinam a ação.
Perguntas técnicas sem pedido sensível continuam técnicas.
Antes de agir, preserve a confirmação exigida pelo efeito e pela autoridade da ação,
independentemente de `route`; nenhum veredito concede consentimento.

`options_source` diz de onde vieram as opções: `structured`, `ledger-text` ou
`type-generic` (do `synopsis-panel`), `fallback:synopsis-panel-error` (instalado mas falhou ao carregar), ou `fallback:synopsis-panel-absent` quando o
`synopsis-panel` não está instalado. O fallback é sempre declarado, nunca silencioso.

## Uso

```bash
DE="$MAOS_DIR/skills/decision-engine/bin/decision_engine.py"
FUSE="$MAOS_DIR/skills/synopsis-panel/bin/synopsis-fuse.py"
echo '{}' | python3 "$FUSE" --hitl-only --compass-json - --hitl-md "$LEDGER" --format json \
  | python3 "$DE" - --format tree        # ou --format json (envelope decision-engine/verdict/v1)
```

Saída JSON:

```json
{"schema": "decision-engine/verdict/v1",
 "counts": {"DIY": 1, "COMPUTE": 0, "HITL": 2},
 "verdicts": [{"id": "H-0001", "tipo": "gasto", "route": "HITL", "rule": "R1-human-type",
               "reason": "...", "recommendation": "Autorizar o gasto",
               "recommendation_basis": "type-default:type-generic",
               "alternatives": ["Não autorizar", "Manter pendente"], "denied": false}]}
```

Exit `2` = entrada inválida. Exit `0` em qualquer outra situação, inclusive 0 itens.

## Decisões de forja (agentic-tool-pipeline, resumidas)

- **Nome**: `decision-engine`, o nome que o operador e os tickets já usam (#555
  e o backlog de construção). Registro de máquina; um nome novo quebraria a busca.
- **Tipo**: skill com `bin/`, no padrão `synopsis-panel`. Um command sozinho não teria
  testes; um MCP seria serviço novo sem necessidade.
- **Rejeitado**: (1) modelo local Laya como roteador, medido no backlog com 50,0% de
  concordância contra 77,8% do "sempre a opção A"; (2) estender o `synopsis-fuse.py`,
  que é read-only e só desenha, e ganharia uma segunda responsabilidade.
- **Fora do MVP**: drivers de modelo (`ModelAdapter`), gravar o veredito no
  ledger, backtest contra decisões reais do operador.

## Testes

```bash
pytest skills/decision-engine/tests -v
```

Cobre as 5 regras, a política `R0`, a dedup do envelope, determinismo, o pipe real
`synopsis-fuse -> decision-engine` e um mutation-check: remover os tipos humanos faz o
teste falhar.

## §Refs

- Ticket: #555.
- Motor composto: `../synopsis-panel/bin/synopsis-fuse.py` (`_card_options`).
- Entrada: `../../commands/hitl-digest.md` (passo 2 opcional).
- Captura de decisão técnica (`R3`): `../decision-capture/SKILL.md`.

## License

MIT (matches multi-agent-os repo `LICENSE`).
