---
title: "Phase 0 — Canonicalization + Security/Supply-chain Gate + Dedup"
run: "RUN 0 (Caminho B / lotes)"
object_prompt: "deep-research-prompt-agentic-tools-v5.md §B"
observed: "2026-06-27"
method: "live GitHub REST API (api.github.com) primary; WebSearch secondary when API body empty"
author: "Emilson de Queiroz Moraes (ekson73)"
executed_by: "Claude (Opus 4.8) — Cowork"
lang_policy: "prose=pt-BR · identifiers/commands=en-US"
status: "BLOCKING gate — review before Phase 1"
---

# RUN 0 — Canonicalização + Gate de Segurança/Supply-chain (BLOCKING)

> **pt-BR (nota epistêmica):** Esta passada **re-derivou** identidade, estrelas, licença e
> status de cada item via API **ao vivo** (não confiei nos números do v5). Resultado: várias
> divergências materiais e **3 achados de segurança/identidade que mudam o set INCLUDED**.
> Star counts são **ordem de grandeza datada (2026-06-27)**; onde a API retornou corpo vazio,
> uso fonte secundária marcada `[sec]`. Nada aqui é precisão — é o melhor sinal verificável hoje.

## §0.1 — Achados que ALTERAM o set (headline)

1. **`MemPalace` → EXCLUDED/FLAGGED (segurança).** Alegações secundárias **(não provadas)** de
   compra de estrelas (~42K em repo de ~2 meses), de o projeto ser um "wrapper de ChromaDB" com
   nome de celebridade (owner `milla-jovovich/mempalace`), e benchmark "96.6% LongMemEval"
   não-auditável. Pelo gate ("EXCLUDE or flag any compromised supply chain"), **sai do INCLUDED**
   até auditoria independente. O v5 o tinha como default de memória — **substituir por mem0**.
2. **`andrej-karpathy-skills`: dono canônico é `multica-ai`, NÃO `forrestchang`.** O path
   `forrestchang/andrej-karpathy-skills` **404/não resolve**; `multica-ai/andrej-karpathy-skills`
   é o repo vivo (**154K**, **SEM licença**). A atribuição "mirror" do v5 está **invertida**.
   ⚠️ **Sem licença = "all rights reserved" por padrão** → falha a exigência "state license" do filtro.
3. **GSD rug-pull CONFIRMADO por múltiplas fontes secundárias.** `gsd-build/get-shit-done`
   (~63K) — token `$GSD` (Solana), saque de liquidez (~US$500K), fundador "TÂCHES" apagou
   contas ~2026-04-01; pacotes npm abandonados seguem como ameaça viva. **EXCLUDED** confirmado.
   Sucessor seguro auditado: **`open-gsd/gsd-core`** (`@opengsd/gsd-core`; fork original `get-shit-done-redux`, agora canonicalizado sob `open-gsd/gsd-core` — ver §0.1 tabela + 01c).

## §0.2 — Correções de licença (gate "state license")

| Item | v5 dizia | API/realidade 2026-06-27 | Ação |
|---|---|---|---|
| multica-ai/andrej-karpathy-skills | MIT | **none (sem LICENSE)** | flag OSS-posture (all-rights-reserved) |
| langfuse/langfuse | MIT | **NOASSERTION** (source-available/EE-style) | flag (não é OSS permissivo puro) |
| Arize-ai/phoenix | OSS | **NOASSERTION** (licença Arize custom) | flag |
| bmad-code-org/BMAD-METHOD | MIT | **MIT** confirmado via raw LICENSE 2026-06-27 (01d §refs); SPDX-API retorna NOASSERTION (artefato) | resolvido: MIT |
| BerriAI/litellm | MIT | **NOASSERTION** (cláusula custom) | flag (infra) |
| ChristopherKahler/base, /seed | — | **none** | flag (cluster) |
| ruvnet/agentic-flow | OSS | **none** | flag (neighbor) |

## §0.3 — Identidades resolvidas (migrações/renomeações)

| Item | Veredito | Evidência (2026-06-27) |
|---|---|---|
| Understand-Anything | `Egonex-AI/Understand-Anything` canônico (migrou de `Lum1104`) | README "originally created by Lum1104 · now maintained under EgonexAI"; ~55–66K `[sec]` |
| ECC | `affaan-m/ECC` canônico (MIT) | API: 187,680★, não-fork, homepage ecc.tools; atribuição WorldFlowAI do ATH = errada |
| laminar | **renomeado** → `lmnr-ai/lmnr` (~2.8K `[sec]`) | slug `laminar` não resolve; YC S24 |
| claude-swarm | **renomeado** → `parruda/swarm` | API do owner falhou; Ruby gem ativo `[sec]` |
| MetaGPT | `FoundationAgents/MetaGPT` (ex `geekan/MetaGPT`) | API: 68,402★, rename de org |
| ruflo | `ruvnet/ruflo` (ex `claude-flow`) | API: 54,569★, criado 2025-06-02 |

## §0.4 — Tabela de Canonicalização (Deliverable 0)

> Colunas: `stars` = valor API ao vivo (sem tag) ou `[sec]` (secundário, API vazia), datado 2026-06-27 ·
> `fork?` sempre `não` salvo indicado · `last push` = atividade do repo · `sec` = status do gate.

### SUBSTRATOS (always-on)

| Item | owner/repo | stars (2026-06-27) | lic | fork? | last push | sec-status | layer | role | verdict |
|---|---|---:|---|---|---|---|---|---|---|
| karpathy-claude-md | **multica-ai**/andrej-karpathy-skills | 154,186 | **none** | não | 2026-04-20 | ⚠️ sem licença | L0 | substrate | **INCLUDED** (flag licença) |
| forrestchang variant | forrestchang/andrej-karpathy-skills | — | — | — | — | 404 | L0 | — | **EXCLUDED** (não existe/mis-attrib) |
| base | ChristopherKahler/base | 87 | none | não | 2026-04-29 | borderline-stale | L0 | substrate | INCLUDED (cluster <1K) |
| mem0 | mem0ai/mem0 | ~57–59K `[sec]` | Apache-2.0 | não | ativo 2026 | clean | L8 | substrate | **INCLUDED** (novo default memória) |
| letta | letta-ai/letta (ex-MemGPT) | 22,891 | Apache-2.0 | não | 2026-05-14 | clean | L8 | substrate | INCLUDED |
| cognee | topoteretes/cognee | 17,453 | Apache-2.0 | não | 2026-05-22 | clean | L8 | substrate | INCLUDED |
| graphiti | getzep/graphiti | 26,380 | Apache-2.0 | não | 2026-05-21 | clean | L4↔L8 | bridge | INCLUDED (BRIDGE) |
| mempalace | MemPalace / milla-jovovich | ~42K `[sec]` | MIT | não | — | 🚩 star-manip + claims não-auditáveis `[UNVERIFIED]` | L8 | — | **EXCLUDED/FLAGGED (segurança)** |
| agentmemory | rohitg00/agentmemory | 14,818 | Apache-2.0 | não | 2026-05-20 | clean | L8 | neighbor | NEIGHBOR |
| zep | (SaaS; core=graphiti) | — | — | — | — | — | L8 | baseline | BASELINE |
| langfuse | langfuse/langfuse | 28,219 | **NOASSERTION** | não | 2026-05-30 | clean (lic source-available) | L9 | substrate | **INCLUDED** (default obs; flag licença) |
| openllmetry | traceloop/openllmetry | 7,153 | Apache-2.0 | não | 2026-05-29 | clean | L9 | neighbor | NEIGHBOR |
| laminar | lmnr-ai/**lmnr** ( renomeado) | ~2.8K `[sec]` | Apache-2.0 | não | — | rename | L9 | neighbor | NEIGHBOR |
| opik | comet-ml/opik | 18,829 | Apache-2.0 | não | 2026-04-14 | stale (~74d) | L9 | neighbor | NEIGHBOR |
| phoenix | Arize-ai/phoenix | 9,918 | **NOASSERTION** | não | 2026-05-29 | clean (lic custom) | L9 | neighbor | NEIGHBOR |

### CONHECIMENTO

| Item | owner/repo | stars (2026-06-27) | lic | fork? | last push | sec | layer | role | verdict |
|---|---|---:|---|---|---|---|---|---|---|
| graphify | safishamsi/graphify | 52,657 | MIT | não | 2026-05-23 | clean | L4 | knowledge | INCLUDED |
| understand-anything | Egonex-AI/Understand-Anything | ~55–66K `[sec]` | MIT `[sec]` | não | ativo | clean (migrou Lum1104→Egonex) | L4 | knowledge | INCLUDED |
| obsidian-skills | kepano/obsidian-skills | 33,438 | MIT | não | 2026-05-24 | clean | L5 | knowledge | INCLUDED |
| obsidian app | (proprietary core) | — | — | — | — | — | L5 | baseline | BASELINE |

### BUILD PIPELINE (ordenado)

| Item | owner/repo | stars (2026-06-27) | lic | fork? | last push | sec | layer | role | verdict |
|---|---|---:|---|---|---|---|---|---|---|
| spec-kit | github/spec-kit | 106,332 | MIT | não | 2026-05-27 | clean | L1 | pipeline | INCLUDED |
| openspec | Fission-AI/OpenSpec | 51,175 | MIT | não | 2026-05-27 | clean | L1 | pipeline | INCLUDED |
| gsd (safe) | open-gsd/gsd-core | ~4.2K `[sec]` | MIT | não | rel. 2026-06-12 | clean (sucessor seguro) | L1 | pipeline | INCLUDED |
| gsd (original) | gsd-build/get-shit-done | ~63K | MIT | não | abandonado ~2026-04 | 🚩 **$GSD rug-pull** | L1 | — | **EXCLUDED (segurança)** |
| specdd | — | — | — | — | — | — | L1 | lens | LENS (metodologia) |
| superpowers | obra/superpowers | ~147K `[sec]` | MIT `[sec]` | não | ativo | clean | L2 | pipeline | INCLUDED |
| gstack | garrytan/gstack | 101,289 | MIT | não | 2026-05-22 | clean | L2 | pipeline | INCLUDED |
| ecc | affaan-m/ECC | 187,680 | MIT | não | 2026-05-20 | clean | L2(+L3+sec) | pipeline (cross) | INCLUDED |
| cli-anything | HKUDS/CLI-Anything | ~42–44K `[sec]` | Apache-2.0 `[confirm]` | não | — | needs-confirm | L2 | pipeline | INCLUDED (lic a confirmar) |
| paul | ChristopherKahler/paul | 976 | MIT | não | 2026-06-03 | clean | L2 | pipeline | INCLUDED (cluster) |
| carl | ChristopherKahler/carl | 353 | MIT | não | 2026-04-29 | borderline | L2 | pipeline | INCLUDED (cluster) |
| seed | ChristopherKahler/seed | 288 | none | não | 2026-06-03 | flag licença | L2 | pipeline | INCLUDED (cluster) |
| open-design | nexu-io/open-design | 48,662 | Apache-2.0 | não | 2026-05-21 | clean | L6 | pipeline | INCLUDED |
| open-codesign | OpenCoworkAI/open-codesign | 6,993 | MIT | não | 2026-06-20 | clean | L6 | pipeline | INCLUDED |
| impeccable | pbakaus/impeccable | 30,054 | Apache-2.0 | não | 2026-05-22 | clean | L6 | pipeline | INCLUDED |
| claude-design / frontend-design | Anthropic | — | proprietary | — | — | — | L6 | baseline | BASELINE |
| slidev | slidevjs/slidev | 47,037 | MIT | não | 2026-06-03 | clean | L7 | pipeline | INCLUDED |
| frontend-slides | zarazhangrui/frontend-slides | 19,093 | MIT | não | 2026-05-26 | clean | L7 | pipeline | INCLUDED |

### AMPLIFICADOR + INFRA

| Item | owner/repo | stars (2026-06-27) | lic | fork? | last push | sec | layer | role | verdict |
|---|---|---:|---|---|---|---|---|---|---|
| ruflo | ruvnet/ruflo | 54,569 | MIT | não | 2026-05-24 | clean | L3 | amplifier | INCLUDED (MoE exemplar) |
| bmad-method | bmad-code-org/BMAD-METHOD | 47,753 | **MIT** (raw-confirmado; SPDX-API=NOASSERTION) | não | 2026-05-20 | clean | L3 | amplifier | INCLUDED (MoE exemplar) |
| agentic-flow | ruvnet/agentic-flow | 762 | none | não | 2026-06-24 | flag licença | L3 | neighbor | NEIGHBOR (<1K) |
| claude-swarm | parruda/swarm (renomeado) | `[UNVERIFIED]` | MIT `[sec]` | não | ativo `[sec]` | rename | L3 | neighbor | NEIGHBOR |
| claude-squad | smtg-ai/claude-squad | 7,673 | AGPL-3.0 | não | 2026-05-18 | clean (AGPL) | L3 | neighbor | NEIGHBOR |
| metagpt | FoundationAgents/MetaGPT | 68,402 | MIT | não | 2026-01-21 | stale (~5m) | L3 | baseline | BASELINE (não Claude-específico) |
| LangGraph/AutoGen/CrewAI | — | — | OSS | — | — | — | L3 | baseline | BASELINE (refs) |
| litellm | BerriAI/litellm | 42,034 | **NOASSERTION** | não | 2026-04-03 | stale (~3m) | INFRA | infra-primitive | INFRA (Phase 3 only) |

## §0.5 — Listas finais por veredito

- **INCLUDED (experts do landscape):** multica-ai/andrej-karpathy-skills⚠️, ChristopherKahler/base
  (cluster), mem0, letta, cognee, graphiti (BRIDGE), langfuse⚠️, graphify, Understand-Anything,
  obsidian-skills, spec-kit, OpenSpec, gsd-core, superpowers, gstack, ECC, CLI-Anything,
  paul/carl/seed (cluster), open-design, open-codesign, impeccable, slidev, frontend-slides,
  ruflo, bmad-method. **(26)**
- **BRIDGE:** getzep/graphiti (L4↔L8).
- **NEIGHBOR:** agentmemory, openllmetry, lmnr, opik, phoenix, agentic-flow, parruda/swarm, claude-squad.
- **BASELINE:** zep, obsidian app, claude-design/frontend-design, MetaGPT, LangGraph/AutoGen/CrewAI, claude-code.
- **LENS:** SpecDD (metodologia SDD).
- **EXCLUDED:** gsd-build/get-shit-done (🚩 $GSD rug-pull), **MemPalace (🚩 star-manip/claims)**,
  forrestchang/andrej-karpathy-skills (404/mis-attrib), klaviyo/graphiti_mcp (fork),
  goabstract/Awesome-Design-Tools (stale/non-agentic).
- **INFRA (não-Target):** BerriAI/litellm.

## §0.6 — Divergências de estrelas vs v5 (reconciliar na RUN 4)

| Item | v5 (citado) | API/`[sec]` 2026-06-27 | Δ |
|---|---|---|---|
| spec-kit | ~90–97K | **106,332** | ↑ |
| OpenSpec | ~56K | 51,175 | ↓ |
| ECC | ~163K (abr) | **187,680** | ↑ |
| gstack | ~117K | 101,289 | ↓ |
| superpowers | ~240K | **~147K** `[sec]` | ↓↓ |
| graphify | ~73K | 52,657 | ↓ |
| understand-anything | ~68K | ~55–66K `[sec]` | ↓ |
| open-design | ~70K | 48,662 | ↓ |
| obsidian-skills | ~36K | 33,438 | ↓ |
| ruflo | ~38–62K | 54,569 | ✓ |
| bmad-method | ~43K | 47,753 | ↑ |
| karpathy-skills | ~183K | 154,186 | ↓ |

> ⚠️ **Aviso de magnitude:** vários counts (ECC 188K, karpathy 154K, superpowers ~147K, spec-kit
> 106K, gstack 101K) são **extraordinários** para repos de 2025–2026 — rivalizam os maiores do
> GitHub. Reporto o **valor da API ao vivo** (fonte primária) datado, **sem editorializar**, mas
> sinalizo a anomalia de magnitude para verificação humana. Isso reforça por que o gate trata
> "velocidade de estrela" como sinal, não prova (vide MemPalace).

## §0.7 — Itens `[UNVERIFIED]` / pendências para fases seguintes

- `mem0`, `superpowers`, `Understand-Anything`, `CLI-Anything`, `gsd-core`, `lmnr`,
  `parruda/swarm`: estrelas via **secundário** (API retornou corpo vazio) — re-tentar com retry/token.
- `CLI-Anything`: licença a confirmar (v5 diz Apache-2.0).
- `langfuse`/`phoenix`/`litellm`: licença **NOASSERTION** — confirmar termos reais (EE/custom). `bmad-method`: **MIT** confirmado via raw LICENSE (resolvido; SPDX-API NOASSERTION é artefato).
- `MemPalace`: alegações de segurança são **secundárias/não-provadas** — exigir auditoria antes de qualquer reinclusão.

---
*RUN 0 concluída — gate aplicado. Próximo: revisar set INCLUDED, então RUN 1a–1d (paralelos).*
