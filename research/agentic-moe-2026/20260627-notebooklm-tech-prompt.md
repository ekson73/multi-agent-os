---
title: "NotebookLM — Prompt de Apresentação TÉCNICA (deep-dive)"
item: "(4.3)"
observed: "2026-06-27"
output_language: "prosa pt-BR · identificadores/código en-US"
recommended_sources: "digest §B + final-report + 00 + 02 + 03 (e 01a–d se quiser detalhe por-expert)"
---

# Prompt — NotebookLM (Apresentação TÉCNICA / deep-dive)

> Para profundidade real, suba também `00`, `02`, `03` (e opcionalmente `01a–d`). Use o bloco A no
> **"Customize" do Audio Overview**; use B/C no chat para study-guide e Q&A técnico.

## A) Audio Overview — "Customize" (cole isto)

```text
Audiência: engenheiros DevOps / AI (Vek) — confortáveis com arquitetura, MCP, LLMOps.
Idioma: português do Brasil; mantenha nomes técnicos em inglês (MCP, hooks, gating, registry, OTel).
Duração-alvo: ~18–25 minutos. Tom: técnico, preciso, sem hype.

Cubra, nesta ordem:
1) O frame MoE: cada Target = um EXPERT de uma camada (L0–L9); o hub = a gating network/router.
   Substrate-first: L0 guardrails + L8 memory + L9 observability sempre ligados.
2) O landscape por camada com os trade-offs reais (não só estrelas): spec (spec-kit formal × OpenSpec
   leve), workflow (superpowers × gstack × ECC e a COLISÃO da instruction-layer — gstack bane o
   browser-MCP que ECC empacota), memória (mem0/cognee plugáveis × letta runtime lock-in; graphiti
   como bridge L4↔L8), observabilidade (langfuse OTel-native, mas ee/ é source-available).
3) O grafo de roteamento (N-Tree): a spine substrate→knowledge→spec→workflow→design→slides, com L3
   (ruflo/BMAD) como amplificador opcional; as arestas tagueadas por mecanismo (MCP, filesystem,
   git-worktree, memory, hooks...) e as relações negativas (incompatibilidades).
4) O HUB em detalhe: pipeline intent-classification → CTS scoring (hard-filters-first; função
   ponderada ISO×Eisenhower×risk×scope×methodology×reversibility; rubric 4-dim) → ISO/Tool-Attention
   gating (pool de summaries ≤60 tokens/tool, promoção de schema só p/ top-k → resolve o "MCP/Tools
   tax" de 10k–60k tokens/turno e o context-fracture acima de ~70%) → model-router (LiteLLM,
   cheapest-capable, budgets) → tool-registry YAML.
5) Substratos do hub: memória tiered (mem0 default + graphiti temporal + Learning-Loop
   RETRIEVE→JUDGE→DISTILL→CONSOLIDATE do ruflo); observabilidade (langfuse OTel + LLM-as-judge →
   gates warn→correct→cure); segurança (AgentShield/PreToolUse: bloquear git --no-verify, detectar
   sk-/ghp-/AKIA, impedir exfiltração de CLAUDE.md; tainting trusted/untrusted/derived).
6) Reuso DRY (não reinventar): ruflo Queen→topology + behavioral-trust-score; BMAD persona→phase;
   ECC NanoClaw (gating determinístico O(1)); Tool-Attention (ISO). LiteLLM e MCP gateways = INFRA.
7) Plano de avaliação: 6 famílias de tarefa × risco baixo/médio/alto, com/sem gating, testes de
   injeção; métricas (routing precision/recall, unsafe-call rate, token/latency, approval-fatigue).
8) Filtro de pragmatismo: o que foi REJEITADO (blockchain audit, quantum, swarms auto-replicantes,
   "camada L10 de gateways", design distribuído sem caso de uso real).

Regras:
- Seja fiel às fontes; marque incertezas como [UNVERIFIED]. Estrelas = ordem de grandeza datada (2026-06-27).
- Pode citar fórmulas/threshold como PROPOSTAS a calibrar (não medições).
- Não recomende empilhar dois gerenciadores de CLAUDE.md nem dois sistemas de spec.
```

## B) Study guide (cole no chat)

```text
Gere um study-guide técnico (pt-BR, identificadores en-US): (1) glossário (MoE, gating, ISO/Tool-
Attention, CTS, MCP tax, HITL, supply-chain gate); (2) a função de scoring CTS explicada termo a
termo; (3) o schema YAML do tool-registry com 1 exemplo preenchido; (4) a tabela de incompatibilidades
com mitigação; (5) 10 perguntas de revisão com respostas. Cite as fontes.
```

## C) Q&A de arquitetura (cole no chat)

```text
Responda como revisor de arquitetura, só a partir das fontes: Como o hub evita o "MCP/Tools tax"?
Onde entra o HITL? Por que mem0 e não MemPalace? Como ruflo/BMAD/NanoClaw são reusados sem reinventar?
Qual o caminho de fallback se o tool top-1 falhar? Cite o arquivo-fonte em cada resposta.
```

## Checklist
- [ ] Fontes técnicas subidas (digest §B + final-report + 00 + 02 + 03; opcional 01a–d).
- [ ] Audio Overview customizado com o bloco A; ~18–25 min; pt-BR + termos en-US.
- [ ] (opcional) Study-guide (B) e Q&A (C) gerados no chat.

---

## Atualização 2026-06-28 (deep-dive técnico — incluir)
- **MAOS Hub** (ADR-006): gating network nativo; enforcement **HYBRID** cascade-resolved (runtime-hook + advisory + CI-floor bloqueante) p/ C1/C6; `protocols/moe-hub-architecture.md` + `openspec/specs/maos-hub/spec.md`.
- **MAOS Agora / console + registry** (ADR-007, Draft): `openspec/changes/maos-hub-console/` + `openspec/specs/maos-hub-registry/spec.md` (taxonomia `activation`, license/SPDX, provenance, ttl, rollback).
- **Achados da análise crítica** (`20260628-critical-analysis.md`) p/ o Q&A técnico: (1) os "dentes" do console **não existem** — `lib/gateway/router.py` (`@with_feedback`) só anota, não gateia `profile`/`conflicts_with` → falta um **gating-seam**; (2) o CI-floor é ~60% real (Trivy `exit-code:0`), o `contribution-gatekeeper` não existe, e o **fixture known-bad** é nomeado mas não instanciado ("a porta antes da fechadura"); (3) **CTS scorer unificado = possível over-engineering**. Cubra os 3 fixes + a recomendação de **minimal-viable-slice**.

## Atualização 2026-06-29 (deep-dive técnico — o seam EXISTE + governança)
- **Fix (1) RESOLVIDO — gating-seam construído** (Loop 2): `lib/gateway/policy.py` (`PolicyResolver` dumb in-memory + `load_conflicts()`) + `conflicts.yaml` (**16 arestas estruturais** do `02-ntree-moe`) + `router.py` (+33/−1: 1 bloco pré-dispatch após validar `operation`; deny → erro no envelope `_agent_feedback` **existente**; discovery L0-L2 intocado). **`policy=None`=passthrough.**
- **Prova (não-asserção):** `test_gateway_policy.py` **16/16** · router+feedback **24/24** · suíte **192 pass / 3 fails pré-existentes** (count-drift, seam-independentes, idênticos no HEAD pristino) · `validate-plugin.sh` PASSED · call-spy prova **handler-não-invocado** nos 2 deny-paths (disabled + conflict) → **0-regressão**.
- **Score 6-fatores** (Loop 4, SSOT `agents/COWORK-AUTONOMY-POLICY.md`): `knowledge·.30 + certainty·.30 + (1−risk)·.15 + (1−impact)·.15 + (1−importance)·.05 + (1−priority)·.05` → **agent-doable 0.79** · **full-goal 0.71** (binding=`certainty`, HARD-capado). Regime `convergence-engine` = **DEFER@n*** (resíduo = ato-humano, não cognição).
- **Governança git** (p/ Q&A): #176 mergeou ADR-006/007 **[Proposed]**; o resto landa via **worktree [C04] + gates [C07]** (gitleaks·openspec·validate-plugin), **merge=HITL**, EKO-66 stage-only. Q&A técnico a cobrir: *por que `policy=None` garante 0-regressão?* · *como o seam reusa o `_agent_feedback` (DRY)?* · *por que os fixes (2) CI-floor e (3) CTS seguem DEFERRED?* (R4-ops é admin; CTS é YAGNI até ≥3 tools competindo).
