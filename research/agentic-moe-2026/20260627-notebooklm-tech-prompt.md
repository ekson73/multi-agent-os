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
