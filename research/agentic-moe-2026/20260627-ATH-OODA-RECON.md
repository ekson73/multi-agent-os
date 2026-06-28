---
title: "OODA-RECON — Impacto do agentic-moe-2026 / ATH sobre o projeto multi-agent-os (MAOS)"
observed: "2026-06-27"
repo: "ekson73/multi-agent-os (maos) v1.16.0 · branch main"
method: "inventário do filesystem + leitura de protocolos/hooks/mcp-hub + cruzamento com 00..03 + final-report do agentic-moe-2026"
lang: "prosa pt-BR · identificadores en-US"
author: "Emilson de Queiroz Moraes (ekson73) · executado por Claude (Cowork)"
governance_note: "NENHUM arquivo do repo foi modificado — propostas só. Mudanças exigem git worktree (MUST do CLAUDE.md)."
---

# OODA-RECON — ATH × MAOS

## TL;DR (a tese central)

> **MAOS já é ~70% do hub ATH.** O `multi-agent-os` não é um *consumidor* da arquitetura
> agentic-moe-2026 — ele é uma **implementação parcial e convergente** dela. Quase todo artefato
> (a)–(m) do hub proposto na Fase 3 tem um componente correspondente **já existente** no repo
> (Eisenhower→`action-priority`, expert-profile→`rbad`, ISO/registry→`maos-mcp-hub`, model-router
> →`slm-routing`, segurança→`pii-masking`+hooks, observabilidade→`sentinel`, DRY-adoption→
> `agentic-tool-lifecycle`). Logo, a pesquisa ATH funciona como **(1) validação** da arquitetura
> MAOS, **(2) roadmap de gaps** (memória vetorial/graph, OTel, ISO generalizado, AgentShield) e
> **(3) aviso de 1 conflito duro**: MAOS é um maestro L0+L2+L3 *always-on* e **colide** se for
> empilhado com ECC/superpowers/gstack/BASE — deve **rotear** para esses experts, nunca coabitar.

## MAOS é a NOSSA contribuição — e o landscape é o catálogo onde ele entra

Reenquadre essencial: o `multi-agent-os` **não é um cliente da ATH** — é **a nossa contribuição
open-source para a comunidade** (tudo que construímos até aqui). Isso muda a leitura em 2 pontos:

1. **MAOS é, ele próprio, um agentic-tool de classe L3/hub** que o landscape agentic-moe-2026
   *cataloga* — ao lado de `ruflo`/`bmad-method` (exemplares de orquestração L3) **e como referência
   viva de hub**: o `maos-mcp-hub` (MetaToolRouter + progressive-discovery + `_agent_feedback`) é
   exatamente o tipo de gating-network que a Fase 3 projeta. Parte da pesquisa "se olha no espelho".
2. Aplicando o **filtro da própria ATH** ao MAOS: **OSS/MIT ✓** · **não-fork ✓** · **ref-impl de hub
   ✓** · **gate de supply-chain próprio (os3pd) ✓** · estrelas = **emergente** (`<1K` hoje → mantido
   como *cluster*, exatamente como a suíte ChristopherKahler que a ATH preservou abaixo do limiar).
   Veredito honesto: **INCLUDED-candidate (emerging)** — qualifica por arquitetura e licença; falta tração.

> **Implicação estratégica:** o caminho natural **não** é "MAOS consome a ATH", e sim **"MAOS evolui
> para o hub MoE de referência da comunidade"** — fechando os gaps do §Decide (memória, OTel, ISO
> universal, AgentShield) e se posicionando no próprio ecossistema que acabamos de mapear. A pesquisa
> agentic-moe-2026 vira, então, o **estudo de mercado + spec de evolução** da nossa contribuição.

---

# O — OBSERVE · Inventário de agentic-tools do MAOS (2026-06-27)

Fonte: filesystem do repo + `hooks/hooks.json` + `protocols/*` + `mcp-tools/maos-mcp-hub` + lista
`maos:*` do ambiente. Taxonomia conforme o próprio `protocols/agentic-tool-lifecycle.md`
(skill · agent · subagent · command · prompt · MCP-tool).

| Categoria | Qtd | Itens-chave (amostra) | Relevância ATH |
|---|---:|---|---|
| **hooks** (wiring) | 6 eventos / 20 scripts | SessionStart(start+auto-name+preflight) · PreToolUse[Task]=`pre-delegate`+`token-budget-gate` · PreToolUse[Bash]=`worktree-gate` · PreToolUse[Edit/Write]=`preflight-edit-gate` · PostToolUse[Task]=`post-delegate` · PreCompact=`postflight-precompact` · Stop=`session-end` | **L0 guardrails + HITL gates + (h)** |
| **MCP-tool / gateway** | 1 hub · 6 gateways | `maos-mcp-hub`: MetaToolRouter, SchemaRegistry, 4-level progressive discovery (0–2 descoberta, 3 exec), `@with_feedback` → `_agent_feedback`; gateways jira/confluence/bitbucket/compass/common/discover | **(b) Tool-Attention/ISO + (d) registry** |
| **agents / subagents** | 49 | orchestrator · sentinel-monitor · qa-validator · consolidator · forge (meta-agent) · cascade-resolver · persona-pipeline · perspective-trio · governance-auditor · data-validator · validation-auditor · memory-curator · naming-organizer · legacy-archaeologist · prompt-context-engineer · gitops/quarkus/react/angular/supabase-engineer · `consultants/` (~21 arquétipos) · founder-coach · data-privacy-officer | **MoE pool interno (role-experts) + L3** |
| **commands** | 33 | agentic-tool-forge/intake/pipeline · auto-pilot · enhance-pipeline · quiesce · preflight · postflight · work-compass · session-fission · delegate · audit · agentic-status · reveng · claude-code-concierge · opendesign-concierge · mvv · founder-playbook | **L3 amplificador + lifecycle DRY** |
| **skills** | 59 | agentic-tool-{forge,intake,evaluator,trainer} · convergence-engine · cascade/persona/perspective · **slm-routing** · **pii-masking** · response-compression · anti-conflict · worktree-policy · hierarchical-merge · ttl-policy · status-map · delegate-governance · decision-capture · agentic-session-harness · notebooklm · anima · maos-concierge | **cobre (a)–(m) quase inteiro** |
| **protocols** | 11 | **action-priority** (Eisenhower) · **rbad** (Role-Based Agent Design) · **agentic-tool-lifecycle** · agent-delegation · `delegation/` (GaaS/GaaC init/dna/finalize) · hierarchical-merge · exit-hygiene · **os3pd-manifesto** · action-priority | **CTS · expert-profile · DRY-adoption · governança** |
| **observability** | Sentinel | `config.json` · `detection_rules.md` (10 regras, health-score, auto-block HIGH) · `schema/{trace,alert}` · `lib/{trace_writer,alert_handler}` · `statusmap/` (10 templates) | **(f) L9 — bespoke (JSONL, não OTel)** |
| **prompts / rules / governance docs** | dirs | `CLAUDE.md` · `AGENTS.md` · `GEMINI.md` · `claude-md/` · `rules/` · `.claude/` · `templates/` · `ontology/` · `openspec/` (usa OpenSpec!) · `audit/` | **L0 instruction-layer (always-on) + L1 adotado** |

**Leitura:** o MAOS é simultaneamente um **L0** (guardrails+CLAUDE.md/AGENTS.md/hooks/rules), um
**L2** (metodologia de workflow própria: preflight→worktree→delegate→postflight), um **L3**
(orquestrador+convergência+delegação) e tem um **L9** próprio (Sentinel) + um esqueleto de **hub**
(maos-mcp-hub). Ele já *adotou* dois experts ATH: **OpenSpec** (L1, dir `openspec/`) e roteia para
**open-design** (L6, `opendesign-concierge`) e **NotebookLM** (skill).

---

# O — ORIENT · Mapa MAOS ↔ ATH (hub artefatos (a)–(m) e camadas L0–L9)

Status: **BUILT** (existe e cobre) · **PARTIAL** (existe, incompleto) · **GAP** (ausente).

| ATH (Fase 3 / camada) | Componente MAOS correspondente | Evidência | Status |
|---|---|---|---|
| **(a) arquitetura em camadas (pipeline de gating)** | orchestrator + delegation protocols + maos-mcp-hub router | `MetaToolRouter` dispatch + GaaS/GaaC `delegation/` | **PARTIAL** (router só Atlassian) |
| **(b) ISO / Tool-Attention (resolve MCP-tax)** | maos-mcp-hub 4-level progressive discovery + SchemaRegistry; `token-budget-gate` | "levels 0–2 = discovery, level 3 = execution"; gate mede spawn-context | **PARTIAL** (schema-gating só no hub Atlassian; token-gate é reativo p/ Task) |
| **(c) CTS multi-criteria scoring** | `action-priority` (Eisenhower+deps) + `rbad` (4-dim role/authorization) + `agent-select` skill | matriz Q1–Q4 + tiebreaker + RBAD taxonomy | **PARTIAL** (lógica existe, não há scorer ponderado unificado) |
| **(d) tool-registry (YAML SSOT)** | SchemaRegistry (auto-gen) + agentic-tool-lifecycle frontmatter contract | "auto-gen typed schemas from handler signatures" | **PARTIAL** (registry vive no hub, não é SSOT de TODOS os tools) |
| **(e) memory substrate (mem0/graphiti)** | `memory-curator` agent · `decision-capture` · `agentic-session-harness` · postflight seeds · PSMM-like | persistência por arquivo/seed/journal | **GAP** (sem backend vetorial/graph — mem0/cognee/graphiti) |
| **(f) observability (Langfuse/OTel)** | **Sentinel** (traces JSONL + 10 regras + health) + statusmap | `sentinel/config.json`, `detection_rules.md` | **PARTIAL** (bespoke; sem OTel/Langfuse — já é TODO no CLAUDE.md) |
| **(g) model-router (LiteLLM/Switchcraft)** | **`slm-routing`** skill | "route AI work between SLM and remote frontier LLM" | **PARTIAL** (rubric existe; sem gateway LiteLLM real) |
| **(h) guardrail & HITL (warn→correct→block)** | hooks (worktree-gate=block, edit-gate, token-gate=warn) + convergence-engine + COWORK-AUTONOMY-POLICY | `hooks.json` PreToolUse matchers | **BUILT** (framework) / **PARTIAL** (autonomy tiers) |
| **(i) security model (AgentShield)** | **`pii-masking`** (CPF/email/phone) + worktree governance + os3pd-manifesto | skill `pii-masking` CI-time detection | **PARTIAL/GAP** (sem secret-scan sk-/ghp-/AKIA, sem block `--no-verify`, sem CLAUDE.md-exfil guard) |
| **(j) composition recipes** | `enhance-pipeline` · `quiesce` · `auto-pilot` · preflight/postflight | thin presets substrate-first | **BUILT** (recipes próprios) |
| **(k) evaluation + deploy** | `agentic-tool-evaluator` + `rule-quality-tests` + `tests/` + golden-set method | lifecycle §4 behavioral eval | **BUILT** (p/ tools internos) / **GAP** (eval de roteamento do hub) |
| **(l) MCP ref impl** | `maos-mcp-hub` (hub.py + gateways) | é um MCP server real funcionando | **BUILT** (é a referência viva) |
| **(m) pragmatism filter** | os3pd-manifesto + rbad Goldilocks (anti-proliferação) | "disposable agent is a COST" | **BUILT** (cultura DRY/anti-over-eng) |
| **DRY adoption dos experts** | `agentic-tool-pipeline`+`intake`+`evaluator`+`trainer` | conduct→intake(install/absorb/adapt/sub-agent/abandon) | **BUILT** (mecanismo pronto) |
| **L1 Spec** | `openspec/` + `reveng` (src→OpenSpec) | dir presente; skill reveng | **BUILT** (adotou OpenSpec) |
| **L4 Codebase-Intel** | `reveng` · `legacy-archaeologist` · `ontology/` | reverse-eng + ontologia | **PARTIAL/GAP** (sem KG tipo graphify) |
| **L5 PKM** | `notebooklm` skill · `claude-md/` | rota p/ NotebookLM | **PARTIAL** |
| **L6/L7 Design/Slides** | `opendesign-concierge` (rota p/ open-design) | concierge routing | **PARTIAL** (roteia, não nativo) |

## Matriz de IMPACTO (colaboração · benefício · sobreposição · conflito)

| Elemento ATH | Relação com MAOS | Veredito | Ação recomendada |
|---|---|---|---|
| **Frame MoE (experts+gating)** | MAOS já pensa em "atomic role-experts" (RBAD) + orquestrador | **COLABORAÇÃO forte** | Adotar vocabulário MoE explícito no orchestrator/rbad |
| **(b) ISO Tool-Attention** | hub MAOS faz progressive-discovery só p/ Atlassian | **BENEFÍCIO (upgrade)** | Generalizar o `MetaToolRouter` p/ qualquer MCP (resolve o MCP-tax global) |
| **mem0/graphiti (L8)** | MAOS sem backend de memória | **BENEFÍCIO (gap)** | `intake` → adotar mem0 como substrato; graphiti p/ memória temporal |
| **graphify/Understand-Anything (L4)** | MAOS tem reveng/ontology, não KG | **BENEFÍCIO (gap)** | `intake` → adotar graphify p/ codebase-intel pré-refactor |
| **langfuse/OTel (L9)** | Sentinel é bespoke JSONL | **COLABORAÇÃO + benefício** | Exportar traces Sentinel via OTel; Langfuse como sink opcional |
| **LiteLLM (infra)** | `slm-routing` é só rubric | **BENEFÍCIO** | Ligar `slm-routing` a um gateway LiteLLM real |
| **AgentShield (de ECC, L0 sec)** | `pii-masking` é parcial | **BENEFÍCIO (gap crítico)** | Expandir `pii-masking`→secret-scan + block `--no-verify` + CLAUDE.md-exfil guard |
| **ruflo / BMAD (L3)** | MAOS é seu PRÓPRIO orquestrador L3 | **SOBREPOSIÇÃO** | Reusar PADRÕES (Queen→topology, persona→phase) — **não** rodar 2 orquestradores |
| **ECC / superpowers / gstack / BASE (L0+L2)** | MAOS já é gerente always-on de CLAUDE.md+hooks | **⚠️ CONFLITO DURO** | **Não empilhar.** `intake`→verdict `adapt`/`sub-agent`/`abandon`; rotear isolado |
| **spec-kit (L1)** | MAOS adotou OpenSpec | **SOBREPOSIÇÃO leve** | Manter OpenSpec; spec-kit = alternativa, não co-instalar |
| **open-design / slidev (L6/L7)** | concierge já roteia | **COLABORAÇÃO** | Manter como experts roteados sob demanda |
| **GSD / MemPalace (EXCLUÍDOS)** | gate de supply-chain do MAOS (os3pd, intake) | **VALIDAÇÃO** | `intake` deve reproduzir os vetos (rug-pull/star-manip) |

---

# CONFLITOS IDENTIFICADOS (com evidência + severidade)

| # | Conflito | Sev | Evidência | Resolução proposta |
|---|---|---|---|---|
| **C1** | **Instruction-layer collision** — MAOS é maestro L0/L2 always-on; ECC/superpowers/gstack/BASE também querem ser. Empilhar = hooks duplicados, contenção de `CLAUDE.md`, `gstack` bane o browser-MCP que `ECC` empacota. | **ALTA** | ATH 02 §incompat + 01c; MAOS `hooks.json` + `CLAUDE.md`+`AGENTS.md`+`GEMINI.md` always-on | **MAOS = único maestro.** Política explícita "single-conductor": qualquer expert L0/L2 concorrente entra só via `intake`→`sub-agent`/`adapt` em worktree isolado, nunca co-residente. |
| **C2** | **Dois orquestradores (L3)** — rodar ruflo/BMAD por cima do orchestrator MAOS = roteamento duplo, memória/estado concorrentes. | **MÉDIA** | MAOS orchestrator+auto-pilot+convergence vs ruflo Queen/BMAD Orchestrator | Reusar **padrões** (DRY) dentro do orchestrator MAOS; ruflo/BMAD como referência, não runtime co-ativo. |
| **C3** | **Observabilidade divergente** — Sentinel (JSONL bespoke) vs OTel/Langfuse. Risco de telemetria em silos. | **BAIXA** | `sentinel/schema/trace_schema.json` ≠ OTel | Adicionar **exporter OTel** ao `trace_writer` (mantém Sentinel como semântica de domínio; OTel/Langfuse como transporte/sink). Já é TODO no `CLAUDE.md`. |
| **C4** | **MCP-tax não resolvido globalmente** — `token-budget-gate` só mede spawn de Task; o schema-gating ISO só existe no hub Atlassian. Com +experts ATH, o "tools tax" (10k–60k tok/turno) reaparece. | **MÉDIA** | `token-budget-gate.sh` escopo=Task; `maos-mcp-hub` escopo=Atlassian | Generalizar progressive-discovery do hub p/ **todos** os MCP (ISO universal) + summaries ≤60 tok/tool. |
| **C5** | **Memória ausente** — roteamento entre sessões sem backend semântico; risco de "amnésia" que os seeds/postflight mitigam parcialmente. | **MÉDIA** | sem mem0/cognee/graphiti; `memory-curator` opera em arquivos | Adotar mem0 (default) via `intake`; ligar ao `agentic-session-harness`/`decision-capture`. |
| **C6** | **Segurança de conteúdo incompleta** — sem secret-scan (`sk-`/`ghp-`/`AKIA`), sem block `git --no-verify`, sem guarda anti-exfiltração de `CLAUDE.md`. | **ALTA** | `pii-masking` cobre só CPF/email/phone | Expandir `pii-masking`→AgentShield-style PreToolUse scanner (os3pd Princípio 6). |

---

# D — DECIDE · Crítica, validação e propostas (Eisenhower-classificadas)

> Dogfooding do próprio `action-priority` (Q1–Q4) + anotação SDP (JSDoc-Bash) nas decisões estratégicas.

```bash
# /**
#  * Posicionar a ATH como "espelho de maturidade" do MAOS, não como framework externo a consumir.
#  * @context O inventário mostrou cobertura ~70% dos artefatos (a)-(m) por componentes já existentes.
#  * @reason Tratar como roadmap interno (gap-closing) evita reescrever o que já funciona (DRY/os3pd).
#  * @impact Backlog vira "evoluir MAOS→hub completo", não "adotar um produto terceiro".
#  */
```

## Validações (o que a ATH CONFIRMA no MAOS)
- A aposta em **orquestração + observabilidade + anti-conflito + governança de delegação** é a tese
  certa: a ATH chega independentemente à mesma arquitetura (substratos always-on + pipeline + amplificador).
- **RBAD ≈ MoE expert-profile**, **action-priority ≈ CTS-Eisenhower**, **agentic-tool-lifecycle ≈
  o mecanismo DRY de adoção** — convergência conceitual forte, não coincidência.
- O **gate de supply-chain** do MAOS (os3pd + intake) é validado pelos casos GSD/MemPalace.

## Críticas (onde o MAOS está atrás da própria tese ATH)
- **MCP-tax**: o hub resolve só Atlassian; o resto do ecossistema MCP fica exposto ao imposto de tokens.
- **Memória**: depende de arquivos/seeds — frágil para roteamento entre sessões em escala.
- **Segurança de conteúdo**: `pii-masking` é um começo, mas falta o núcleo AgentShield.
- **Observabilidade**: bespoke; sem OTel, não pluga em Langfuse/Datadog/Grafana do mundo real.
- **CTS**: a lógica de priorização existe espalhada (action-priority + rbad + agent-select) mas **não há um scorer único** que componha ISO×Eisenhower×risk×scope×methodology×reversibility.

## Propostas (backlog priorizado — mapeia 1:1 nas stories do prompt Jira já gerado)

| ID | Proposta | Q | ATH artefato | Story Jira | Esforço |
|---|---|---|---|---|---|
| **P0-C1** | Política **single-conductor**: doc + `intake`-rule barrando co-instalação de L0/L2 concorrentes (ECC/superpowers/gstack/BASE); roteá-los como sub-agent isolado | **Q1** | conflito C1 | (nova: governança) | S |
| **P0-C6** | Expandir `pii-masking`→**AgentShield**: secret-scan (`sk-`/`ghp-`/`AKIA`), block `git --no-verify`, guarda anti-exfil de `CLAUDE.md`; PreToolUse | **Q1** | (i) | S7 | M |
| **P1-b** | Generalizar `MetaToolRouter`/progressive-discovery p/ **qualquer MCP** (ISO universal, summaries ≤60 tok/tool) | **Q2** | (b) | S3 | L |
| **P1-c** | **CTS scorer** único: compor `action-priority`+`rbad`+ISO num scoring ponderado com hard-filters-first | **Q2** | (c) | S2 | M |
| **P1-e** | Substrato de **memória**: `intake`→adotar **mem0** (default) + **graphiti** (temporal); ligar a `decision-capture`/`agentic-session-harness` | **Q2** | (e) | S4 | M |
| **P1-f** | **OTel exporter** no Sentinel `trace_writer`; Langfuse como sink opcional | **Q2** | (f) | S5 | M |
| **P2-g** | Ligar `slm-routing` a um **LiteLLM** real (gateway + budgets por categoria) | **Q2** | (g) | S6 | M |
| **P2-d** | Promover `SchemaRegistry`→**tool-registry SSOT** (YAML por tool: layer/role/summary/risk/auth/security) | **Q2** | (d) | S1 | M |
| **P2-L4** | `intake`→adotar **graphify** p/ codebase-intel (pré-refactor), complementando `reveng`/`ontology` | **Q3** | L4 | (nova) | M |
| **P2-k** | Harness de **eval de ROTEAMENTO** do hub (6 famílias × risco; com/sem gating; injeção) — estende `agentic-tool-evaluator` | **Q2** | (k) | S8 | L |
| **P3** | Reconciliar estrelas `[sec]` com API autenticada; rodar os 26 experts pelo `intake` em lote (verdicts INSTALL/ADAPT/SUB-AGENT/ABANDON) | **Q3** | DRY | S10/S9 | M |

---

# A — ACT · O que foi feito e o que proponho

**Feito nesta passada (read-only, sem tocar no repo — governança MUST exige worktree):**
- Inventário completo dos agentic-tools (§Observe).
- Mapa de cobertura ATH↔MAOS por artefato (a)–(m) e camada L0–L9 (§Orient).
- Matriz de impacto + 6 conflitos com severidade/evidência + backlog priorizado (Eisenhower) que
  **reusa as stories do prompt Jira** já gerado (`20260627-prompt-jira-confluence.md`).

**Próximo passo (precisa do seu ok — modifica o repo governado):** implementar os **P0** num
**git worktree** dedicado (respeitando worktree-policy + hierarchical-merge + C07 PR-review):
- `feature/ath-single-conductor-<hex>` → política single-conductor (P0-C1): doc em `protocols/` +
  regra no `agentic-tool-intake`.
- `feature/ath-agentshield-<hex>` → expandir `pii-masking` (P0-C6): novo PreToolUse scanner + testes.

Eu **não** mexi em nenhum arquivo do `multi-agent-os` — só gravei este relatório em `research/`.

## Caveats honestos
- O inventário é estrutural (nomes + hooks + 4 protocolos lidos + README do hub); não li o corpo dos
  59 skills/49 agents um a um — vereditos de cobertura "BUILT/PARTIAL" são **inferência fundamentada**,
  a confirmar arquivo-a-arquivo antes de implementar cada P-item.
- "MAOS ~70% do hub" é uma estimativa de cobertura de artefatos, não medição — calibrar via o eval (P2-k).
- Os números de estrela/segurança herdam os `[sec]`/`[UNVERIFIED]` do agentic-moe-2026.

---
*OODA-RECON · 2026-06-27 · sem modificações no repo · propostas prontas p/ worktree sob aprovação.*
