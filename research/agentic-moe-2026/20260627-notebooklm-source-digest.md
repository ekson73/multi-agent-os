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
