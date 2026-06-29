---
title: "NotebookLM — Seleção de fontes + Digest condensado (fonte nova)"
item: "(4.1) identificar artefatos p/ NotebookLM + gerar novo se útil"
observed: "2026-06-27"
lang: "prosa pt-BR · identificadores en-US"
---

# §A — Quais artefatos subir para o NotebookLM (e por quê)

O NotebookLM rende melhor com **fontes focadas e não-redundantes**. A série tem ~280 KB com muita
sobreposição entre as Fases 1 (detalhe) e a Síntese. Recomendação em 3 camadas:

| Camada | Subir | Arquivo(s) | Por quê |
|---|---|---|---|
| **PRIMÁRIA (núcleo)** | ✅ | **este digest (§B)** + `20260627-final-report.md` | Espinha limpa, sem redundância; cobre tese + conclusões + cheat-sheet. É o que dá o melhor Audio Overview. |
| **SUPORTE (Q&A/profundidade)** | ✅ | `20260627-00-canonicalization.md`, `20260627-02-ntree-moe.md`, `20260627-03-orchestrator-hub.md` | Fatos canônicos (estrelas/licenças/segurança), o grafo de roteamento e o design do hub — para perguntas específicas. |
| **OPCIONAL (detalhe fino)** | ➖ | `20260627-01a/01b/01c/01d` | Só se quiser que o NotebookLM responda por-expert em detalhe. **Adiciona ruído** ao overview — prefira deixar de fora na 1ª rodada. |
| **NÃO subir** | ❌ | `20260627-CONSOLIDATED.pdf` / `.html` | Redundantes com os `.md`; o PDF importa de forma pior (layout/100 págs). |

**Decisão (gerar novo?):** SIM — criei **este digest (§B)** como fonte nova e enxuta. Ele melhora
clareza/visão porque elimina a sobreposição de 280 KB preservando todas as conclusões datadas.
Use-o como **fonte primária** do notebook; os demais entram como suporte.

> Dica: nomeie o notebook **"Agentic MoE 2026 — Vek"**. Suba primeiro §B + final-report, gere o
> Audio Overview, e só então adicione as fontes de suporte se precisar de profundidade.

---

# §B — DIGEST CONDENSADO (fonte nova, auto-contida) — Agentic MoE 2026

**Observado 2026-06-27. Estrelas = ordem de grandeza datada (não precisão); `[sec]` = via fonte secundária.**

## Tese
O ecossistema agentic (Claude Code & cross-harness) **não é um mercado homogêneo** — é uma **stack
de camadas funcionais agrupadas por PAPEL**, roteada como um **Mixture-of-Experts (MoE)**. Nenhum
tool "vence"; o valor está em **compor** e em um **hub = gating network** que seleciona o expert
certo por tarefa. Princípio central: **substrate-first**.

## Camadas (papéis)
- **Substratos always-on:** L0 Guardrails · L8 Memória · L9 Observabilidade (envolvem toda rota).
- **Conhecimento:** L4 Codebase-Intelligence · L5 PKM.
- **Pipeline de build (ordenada):** L1 Spec → L2 Workflow → L6 Design → L7 Slides.
- **Amplificador:** L3 Orquestração (MoE engines) — opcional, só com HITL em irreversíveis.

## Experts INCLUDED (âncora por camada · estrelas 2026-06-27)
- **L0:** `multica-ai/andrej-karpathy-skills` (~154K, **sem licença** ⚠️) · `ChristopherKahler/base` (87, cluster).
- **L8:** `mem0ai/mem0` (~58K [sec], Apache, **default**) · `letta-ai/letta` (22.9K, runtime lock-in) · `topoteretes/cognee` (17.5K) · `getzep/graphiti` (26.4K, **bridge L4↔L8**).
- **L9:** `langfuse/langfuse` (28.2K, **NOASSERTION/source-available**, default) · vizinhos openllmetry/lmnr/opik/phoenix.
- **L4:** `safishamsi/graphify` (52.7K, MIT) · `Egonex-AI/Understand-Anything` (~55–66K [sec], migrou de Lum1104).
- **L5:** `kepano/obsidian-skills` (33.4K, MIT).
- **L1:** `github/spec-kit` (106K) · `Fission-AI/OpenSpec` (51K) · `open-gsd/gsd-core` (~4.2K, sucessor seguro).
- **L2:** `obra/superpowers` (~147K[sec]; outra fonte 236K) · `garrytan/gstack` (101K) · `affaan-m/ECC` (188K, cross-layer +NanoClaw +AgentShield) · `HKUDS/CLI-Anything` (~42–44K, Apache) · `ChristopherKahler/{paul,carl,seed}` (cluster).
- **L6:** `nexu-io/open-design` (48.7K, Apache) · `OpenCoworkAI/open-codesign` (7K) · `pbakaus/impeccable` (30K).
- **L7:** `slidevjs/slidev` (47K) · `zarazhangrui/frontend-slides` (19K).
- **L3:** `ruvnet/ruflo` (54.6K, ex claude-flow) · `bmad-code-org/BMAD-METHOD` (47.8K, MIT).

## Achados de SEGURANÇA (gate de supply-chain — parte da tese)
- **EXCLUÍDO `gsd-build/get-shit-done`** — rug-pull do token `$GSD` (Solana, ~US$500K), fundador
  apagou contas ~2026-04; npm abandonado = vetor vivo. **Migrar para `open-gsd/gsd-core`.**
- **EXCLUÍDO/flag `MemPalace`** — alegações *secundárias* de compra de estrelas + leakage de
  benchmark ("96,6% LongMemEval" ≈ default do ChromaDB). Default de memória passou a **mem0**.
- Contexto: ~13% de pacotes agent-skill com vulns críticas (fev/2026); `CLAUDE.md` malicioso pode exfiltrar chaves.

## Roteamento (spine N-Tree)
`substrate-check (L0+L8+L9)` → `conhecimento (L4/L5)` → `L1 spec` → `L2 workflow` → `L6 design`
→ `L7 slides`; **L3 envolve L1–L7 quando justificado**.

## Top incompatibilidades (não empilhar)
1. **Instruction-layer:** `superpowers × gstack × ECC` (+ BASE em L0) disputam `CLAUDE.md`/`.claude/`
   — `gstack` bane o browser-MCP que `ECC` empacota; hooks duplicados. → escolher **um** maestro.
2. **Specs exclusivas:** `spec-kit × OpenSpec` (modelos de artefato incompatíveis).
3. **Backends de memória:** `letta` (runtime lock-in) × `mem0`/`cognee` (plugáveis).
4. `open-design × open-codesign` (mesma vaga); orquestração pesada em contexto de baixo risco = overkill.

## O HUB (gating network)
`intent-classification` → `CTS multi-criteria scoring` (ISO × Eisenhower × risco × escopo ×
metodologia × reversibilidade; **hard-filters primeiro**; rubric 4-dim Expert-fit/Authorization/
Task-frame/Risk-frame) → `ISO/Tool-Attention gating` (pool de summaries ≤60 tokens/tool, promove
schema completo só p/ top-k — resolve o **"MCP/Tools tax"** de 10k–60k tokens/turno) →
`model-router` (LiteLLM, modelo capaz mais barato + budgets) → `tool-registry` (YAML).
Sobre substratos: **mem0** (memória tiered + Learning-Loop), **langfuse** (OTel; evals → gates
warn→correct→cure), **L0 guardrails** (AgentShield: bloqueia `--no-verify`, detecta sk-/ghp-/AKIA,
impede exfiltração de CLAUDE.md). **HITL** em risco HIGH/irreversível. **Reuso DRY:** ruflo
(Queen→topology, trust-score), BMAD (persona→phase), ECC NanoClaw (gating O(1)), Tool-Attention (ISO).

## Caveats honestos
- **Estrelas extraordinárias e divergentes** (ex.: `superpowers` 147K × 236K no **mesmo dia**) →
  ordem-de-grandeza datada `[UNVERIFIED]`, não precisão.
- Correções: `karpathy/base` = sem licença; `BMAD` = MIT (NOASSERTION era artefato de parsing);
  `langfuse`/`phoenix` = NOASSERTION; `CLI-Anything` = Apache-2.0.
- Alegações do MemPalace são secundárias; pesos/thresholds da Fase 3 são **propostas a calibrar**.

---

# §C — Atualização 2026-06-28 — MAOS Hub + **MAOS Agora** (Draft) + análise crítica

A pesquisa evoluiu de "landscape" para **arquitetura nativa do MAOS** + uma **visão de plataforma**. Suba TAMBÉM (fontes mais atuais):

| Camada | Subir | Arquivo |
|---|---|---|
| **Decisões (núcleo)** | ✅ | `docs/adrs/ADR-006-ath-moe-hub-adoption.md` (MAOS Hub) · `docs/adrs/ADR-007-curated-community-integration-platform.md` (North Star, **Draft**) |
| **Visão (legível)** | ✅ | `docs/vision/maos-integration-platform.md` |
| **Análise crítica** | ✅ | `research/agentic-moe-2026/20260628-critical-analysis.md` (33 socráticas + banca + veredito + nome) |
| **Contratos** | ➖ | `openspec/changes/maos-hub-console/{proposal,tasks}.md` · `openspec/specs/maos-hub-registry/spec.md` · `…/20260627-ATH-OODA-RECON.md` |

**Síntese (pro NotebookLM aterrar):**
- **Nome (anima):** **`MAOS Agora`** (`maos-agora`) — a *agora* grega (encontro + mercado vetado + discurso) = as 3 faces (integrador + registry + console). ⚠️ pendente ratificação.
- **MAOS Hub (ADR-006):** o MoE gating network nativo (evolução do `maos-mcp-hub`); MAOS já é ~70% dele.
- **MAOS Agora (ADR-007, Draft):** front-door curado-confiável do commons — índice+gate+adapter+guia (não re-host); 7 guardrails; taxonomia `activation`.
- **Veredito (dogfood dos próprios experts):** **GO-WITH-FIXES (autonomy 0.62)** · **ASSET-com-risco-de-COST**. Forte onde **constrói**, fraco onde **se declara**. **Recomenda:** ratificar ADR-006; **rebaixar ADR-007 a Vision exploratória**; reduzir ao **minimal-viable-slice** (registry read-only + conflict-graph) + **Wizard-of-Oz de 1 dia** p/ validar demanda antes de construir; e os "dentes" do hub (gating no router) **ainda não existem** (maior build-risk).

---

# §D — Atualização 2026-06-29 — o build aconteceu + o gate de demanda (Loops 2-4)

A visão saiu do papel em parte: o **núcleo foi construído e test-provado**; a plataforma virou **destino-a-ganhar**, não premissa. Fontes novas a subir (mais atuais que §C):

| Camada | Subir | Arquivo |
|---|---|---|
| **Closure do goal-loop** | ✅ | `20260628-goal-loop-closure.md` (Loops 1-4: build · demanda · v3-canônico) |
| **Debate de soluções** | ✅ | `20260628-solutions-debate.md` (3 lentes → cunha "conflict-safe install") |
| **Probe de demanda** | ➖ | `20260629-demand-probe-post.md` (a munição R2 + kill-criterion pré-registrado) |
| **Código (referência, NÃO subir)** | ❌ | `mcp-tools/maos-mcp-hub/lib/gateway/{policy.py,conflicts.yaml,router.py}` — é código; citar como evidência, não como fonte |

**Síntese (pro NotebookLM aterrar):**
- **O seam foi construído** (Loop 2): `policy.py` + `conflicts.yaml` (16 incompatibilidades) + `router.py` (+33/−1) + 16 testes. **`policy=None`=passthrough → 0-regressão** nos 96 actions. Os "dentes" que a crítica disse faltar **agora existem** (test-provados).
- **A demanda bifurcou** (Loop 3): a *dor existe* (prior 0.45→0.68 por evidência) mas *adotam-ESTA-solução* é **HARD** (só o mundo resolve). Wedge = "instalar a tool certa sem quebrar o resto".
- **Loop 4 (v3-canônico):** score 6-fatores → **agent-doable 0.79 · full-goal 0.71** (binding=`certainty`, HARD-capado). Veredito: **DEFER@n*** — o que falta é ato-humano (ratificar ADR-006, rodar o probe), não cognição.
- **Status real:** PR #176 mergeou ADR-006/007 como **Proposed**; o seam + docs seguem **não-commitados** (EKO-66, landing via worktree C04/C07).
