---
title: "PROMPT (saved, NOT launched) — Criar Épico Jira + Páginas Confluence no Vek"
item: "(3) deep-research execution kit follow-up"
status: "READY-TO-RUN — DO NOT EXECUTE até o operador aprovar"
observed: "2026-06-27"
lang: "prompt instructions = en-US · conteúdo a criar = pt-BR"
atlassian_mcp: "disponível nesta sessão, mas NÃO deve ser chamado até liberação explícita"
---

# ⛔ PROMPT SALVO — Jira/Confluence (NÃO LANÇAR AINDA)

> Este arquivo é um **prompt pronto para rodar depois**. Ele NÃO deve ser executado agora.
> Quando o operador disser "pode lançar", cole o bloco `RUN PROMPT` abaixo para um agente com
> o Atlassian MCP conectado. O agente **deve fazer DRY-RUN primeiro** (imprimir o plano e
> esperar aprovação) antes de criar qualquer issue/página.

## Pré-requisitos a confirmar antes de rodar
- **Confluence space key** do Vek (sugestão a partir do repo: documentação MAOS). → CONFIRMAR: `____`
- **Jira project key** (o `CLAUDE.md` referencia `VKS-1694` → sugestão `VKS`). → CONFIRMAR: `VKS`
- Fonte canônica dos achados: `~/Projects/multi-agent-os/research/agentic-moe-2026/` (8 arquivos `.md` + PDF/HTML consolidados).

---

## RUN PROMPT (cole para o agente Atlassian quando liberado)

```text
ROLE: você é um agente de operações com o Atlassian MCP conectado (Jira + Confluence do Vek).
LANGUAGE: títulos/corpos em pt-BR; rótulos/keys em en-US.
SAFETY: DRY-RUN obrigatório. Primeiro IMPRIMA o plano completo (todas as páginas e issues que
criaria, com títulos, pais, labels, links) e PARE para aprovação humana. Só crie depois do "ok".
Nunca apague nada. Use o space key e o project key confirmados pelo operador.

SOURCE OF TRUTH (anexar/linkar, não recolar tudo):
- ~/Projects/multi-agent-os/research/agentic-moe-2026/20260627-final-report.md  (síntese)
- 00-canonicalization.md · 01a/01b/01c/01d · 02-ntree-moe.md · 03-orchestrator-hub.md
- 20260627-CONSOLIDATED.pdf / .html  (versões de publicação)

# ── CONFLUENCE: árvore de páginas ──
Criar 1 página-pai + 6 filhas no space {CONFLUENCE_SPACE}:
PAI: "Agentic MoE 2026 — Landscape Comparativo & Hub Orquestrador"
  corpo: resumo executivo (3 parágrafos do final-report §1) + índice das filhas + link p/ o repo.
  labels: agentic-moe, claude-code, moe, research, vek
FILHAS:
  1. "Fase 0 — Canonicalização & Gate de Segurança"  (de 00) — tabela de vereditos
     INCLUDED/EXCLUDED + os 2 achados de segurança (GSD rug-pull, MemPalace) + correções de licença.
  2. "Fase 1 — Landscape por Camada (L0–L9)"  (de 01a–d) — cards + matrizes de comparação.
  3. "Fase 2 — N-Tree / MoE Routing Graph"  (de 02) — spine de roteamento, edge list,
     incompatibilidades; colar o diagrama Mermaid em um bloco de código `mermaid`.
  4. "Fase 3 — Orchestrator/Hub (gating network)"  (de 03) — arquitetura (a)–(m), CTS, ISO,
     registry YAML, substratos, segurança, ref impl.
  5. "Síntese Final & Cheat-Sheet de Roteamento"  (de final-report) — reconciliação de
     estrelas datada + cheat-sheet Eisenhower Q1–Q4.
  6. "Decisões de Segurança & Exclusões"  — GSD ($GSD rug-pull → migrar p/ open-gsd/gsd-core),
     MemPalace (alegações secundárias, excluído), gate de supply-chain obrigatório.
Cada página: linkar o arquivo-fonte correspondente e a página-pai.

# ── JIRA: épico + stories ──
Criar 1 épico no project {JIRA_PROJECT}:
ÉPICO: "Agentic-Tool MoE Orchestrator/Hub (gating network)"
  descrição: visão do hub (intent → CTS scoring → ISO/Tool-Attention gating → model-router →
  tool-registry, sobre substratos guardrails+memory+observability; HITL em irreversível/HIGH).
  reusar DRY: ruflo / BMAD / ECC-NanoClaw / Tool-Attention. labels: agentic-moe, hub, moe.
STORIES (linkar ao épico; cada uma com critério de aceite):
  S1. Tool Registry (YAML SSOT) + summaries ISO (≤60 tokens/tool).
  S2. CTS multi-criteria scorer (hard-filters-first + função ponderada; rubric 4-dim).
  S3. ISO/Tool-Attention gating + lazy-schema-loader (resolve o "MCP/Tools tax").
  S4. Substrato de MEMÓRIA: mem0 (default) + graphiti (temporal) + Learning-Loop (consolidação).
  S5. Substrato de OBSERVABILIDADE: langfuse (OTel) + evals → gates warn/correct/cure.
  S6. MODEL ROUTER (LiteLLM) — modelo capaz mais barato por tool-call + budgets por categoria.
  S7. Modelo de SEGURANÇA: AgentShield/PreToolUse (bloquear `--no-verify`; detectar sk-/ghp-/AKIA;
      impedir exfiltração de CLAUDE.md) + gate de supply-chain (excluir classe GSD/MemPalace).
  S8. Harness de AVALIAÇÃO: 6 famílias de tarefa × risco baixo/médio/alto; com/sem gating;
      testes de injeção; métricas (routing precision/recall, unsafe-call, token/latency, approval-fatigue).
  S9. Calibrar pesos/thresholds da Fase 3 (CTS weights, θ, contagem de tokens ISO).
  S10. Higiene de dados: reconciliar contagens de estrela `[sec]` com API autenticada (token).
Opcional: criar uma story de governança "Migrar qualquer uso de gsd-build/get-shit-done →
  open-gsd/gsd-core (supply-chain)".

OUTPUT do DRY-RUN: uma árvore textual (Confluence) + lista de issues (Jira) com títulos/pais/labels,
e os IDs que seriam criados. AGUARDAR "ok" antes de criar.
```

---
*Gerado por Claude (Cowork) · 2026-06-27. Edite os keys/labels conforme o Vek antes de rodar.*
