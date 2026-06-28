# GRUPO 1a — Substratos Always-On (L0 Guardrails · L8 Memory · L9 Observability)

> **Pesquisa:** Ecossistema AI-native / agentic software-engineering (Claude Code & cross-harness)
> **Grupo:** 1a — substrates (always-on)
> **Observado:** 2026-06-27 (estrelas = ordem de grandeza datada; valores RUN 0 + refinamentos primários quando disponíveis)
> **Nota de língua:** prosa em pt-BR; identificadores, comandos e nomes de repositório em en-US.
> **Disciplina de fontes:** ≥2 fontes independentes por expert; citações ≤15 palavras; itens incertos marcados `[UNVERIFIED]`.

---

## Contexto do grupo

Os **substratos always-on** são as camadas que ficam permanentemente ligadas por baixo de qualquer fluxo agêntico, independentemente da tarefa concreta:

- **L0 — Guardrails:** as regras/princípios injetados no contexto (tipicamente via `CLAUDE.md`/rules) que governam *como* o agente pensa e edita antes de qualquer ação.
- **L8 — Memory:** a camada de memória persistente que sobrevive entre sessões (preferências, fatos, grafos de conhecimento, estado de agente).
- **L9 — Observability:** a camada de tracing/avaliação que torna o comportamento do agente visível para humanos (traces, evals, prompt-mgmt).

Estas três camadas compartilham uma propriedade arquitetural: **não competem pela tarefa** — elas *envelopam* a tarefa. Por isso podem (e tipicamente devem) coexistir.

---

# PROFILE CARDS

---

## L0 — GUARDRAILS

### multica-ai/andrej-karpathy-skills

**Identidade & maturidade.** Um único `CLAUDE.md` que codifica princípios de codificação-com-LLM derivados de observações de Andrej Karpathy. ~154,186★ no RUN 0; a página de repositório observada em 2026-06-27 mostra **183k★ / 18.7k forks** ([github.com/multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)) — ordem de grandeza "centenas de milhares", entre os artefatos de guardrail mais estrelados do ecossistema. Maturidade de *conteúdo* alta, maturidade de *engenharia* baixa: "28 Commits", sem releases publicados. Distribuído também como plugin Claude Code e regra Cursor (`.cursor/rules/karpathy-guidelines.mdc`).

**Propósito (escopo, casos de uso, persona).** Escopo: documento único de princípios. Resolve os pitfalls que Karpathy descreve: *"models make wrong assumptions... don't manage their confusion, don't seek clarifications"* e *"like to overcomplicate code... bloat abstractions"* (README, citações ≤15 palavras). Persona = um *senior-engineer-em-prosa* que força o agente a deliberar antes de codar. Quatro princípios: **Think Before Coding** (não assumir, expor tradeoffs), **Simplicity First** (mínimo código), **Surgical Changes** (tocar só o necessário), **Goal-Driven Execution** (transformar tarefas imperativas em metas verificáveis com tests-first).

**Capabilities (artefatos, automação, cobertura de harness).** Artefato: 1× `CLAUDE.md` + `CURSOR.md` + `EXAMPLES.md`. Automação: nenhuma (é texto injetado no contexto). Cobertura de harness: **Claude Code** (plugin/marketplace + `CLAUDE.md` per-project) e **Cursor** (project rule committada). Qualquer harness que leia `CLAUDE.md`/`AGENTS.md` herda os princípios por convenção.

**Lentes.**
- *OSS posture:* **License = NONE** (autoritativo: GitHub API `license=null` — **sem arquivo LICENSE**). O README/footer menciona "MIT", mas sem um `LICENSE` válido isso **não constitui concessão OSS** (default = all-rights-reserved). Decisão do operador (RUN 0, confirmada): manter como substrato L0 **com flag de licença**. ⚠️ "Sem licença" ≠ open-source para o filtro "state license".
- *S-SDLC fit:* alto como *política de baseline* — "Surgical Changes" e "tests-first" mapeiam diretamente em práticas de PR review seguro.
- *SaaS multi-tenant fit:* N/A (é um arquivo, não um serviço).
- *SDD-methodology fit:* parcial — "Goal-Driven Execution" é spec-light (success criteria + verificação), mas não é uma metodologia spec-driven formal.
- *MoE expert-profile:* layer=L0; role=guardrail/policy; competence=princípios de qualidade de código; persona=senior-engineer cético; abstraction=prosa-de-regra; authorization=read-only sobre o agente (não executa nada).

**SECURITY posture (incl. license).** Superfície de ataque mínima: é texto. O risco é de *provenance* — atribuir a Karpathy princípios que ele não revisou linha-a-linha (o README é explícito que são *"observations"* destiladas de um post, não um endosso). License MIT permite uso comercial. Sem código executável = sem risco de supply-chain.

**INTEGRATION SURFACE (mecanismos):** `{filesystem, git-repo, rules}` (+ `hooks` opcional quando instalado como plugin Claude Code que injeta a skill).

---

### ChristopherKahler/base

**Identidade & maturidade.** "AI builder operating system" — BASE = **Builder's Automated State Engine**. ~87★ (cluster) no RUN 0; página observada mostra **86★ / 18 forks**, "50 Commits", "1 tag" ([github.com/ChristopherKahler/base](https://github.com/ChristopherKahler/base)). Maturidade nascente, single-maintainer (Chris Kahler). Distribuído via npm `@chrisai/base` (`npx @chrisai/base --global --workspace`).

**Propósito (escopo, casos de uso, persona).** Transformar Claude Code *"from a per-session tool into a workspace that remembers, maintains itself, and never goes stale"* (README). Resolve o problema do `CLAUDE.md` que vira *"junk drawer"* e fica obsoleto. Persona = um *gerente-de-estado-de-workspace* para "AI builders" multi-projeto/multi-cliente que saíram da "duct tape phase". Casos de uso: injeção automática de contexto compacto (Projects, Entities, State, PSMM), monitoramento de saúde por **drift score**, ciclos de manutenção (`/base:pulse`, `/base:groom`, `/base:audit`).

**Capabilities (artefatos, automação, cobertura de harness).** Artefatos: **Data Surfaces** (JSON estruturado + hook que auto-injeta sumários no contexto); `workspace.json` (manifest single-source-of-truth); `operator.json` (perfil do operador); **PSMM** (Per-Session Meta Memory — loga DECISION/CORRECTION/SHIFT/INSIGHT/COMMITMENT e re-injeta). Automação: 1 servidor **BASE MCP** (20 ferramentas em 5 módulos — Projects/Entities/State/Operator/PSMM) + hooks Claude Code (`UserPromptSubmit`, `SessionStart`). Comando-chave `/base:audit-claude` audita o diretório `.claude/` (dedup por MD5; classes DUPLICATE/DIVERGED/STALE/etc.). Cobertura de harness: **Claude Code only** (Node ≥16.7, Python 3).

**Lentes.**
- *OSS posture:* **License = NONE** (autoritativo: GitHub API `license=null` — **sem arquivo LICENSE**; o 1c-agent confirmou `license:null` em base/seed). README menciona "MIT — Chris Kahler", mas sem `LICENSE` não há concessão OSS válida (all-rights-reserved por padrão). Flag mantida.
- *S-SDLC fit:* moderado — o valor é *higiene de configuração* (detectar hooks que disparam em duplicata, config stale apontando para ferramentas inexistentes), o que é uma forma de segurança operacional.
- *SaaS multi-tenant fit:* N/A (workspace-local, JSON em `.base/data/`, sem multi-tenant).
- *SDD-methodology fit:* baixo — é state-management, não spec-driven.
- *MoE expert-profile:* layer=L0 (com forte spillover para L8); role=workspace-state/config-hygiene; competence=anti-staleness; persona=operations-manager; abstraction=JSON-surfaces + manifest; authorization=read-only sobre projetos (*"never modifies projects"*), read-write sobre `.base/`.

**SECURITY posture (incl. license).** Princípio de design #1: **"If it's not current, it's harmful."** Hooks são *"lightweight Python"*, output XML compacto, silenciosos se nada a reportar. Risco: hooks `UserPromptSubmit` executam código local a cada prompt — superfície de execução não-trivial; o próprio README documenta upgrades v2→v3 que arquivam cópias de hooks *"double-fire-causing"*. Gestão de *rules* propriamente dita é delegada a uma ferramenta separada (CARL), não embutida.

**INTEGRATION SURFACE (mecanismos):** `{MCP, filesystem, git-repo, hooks, rules, memory}` (memory via PSMM/surfaces JSON; git apenas leitura para detecção de projetos).

**⚠️ Conflito conhecido (L0):** BASE e o "ECC" (outro gerenciador de `CLAUDE.md`) **competem pelo mesmo recurso** — ambos querem ser o orquestrador do `CLAUDE.md`/`.claude/`. BASE inclusive embute `/base:audit-claude` para detectar exatamente esse tipo de sprawl/duplicação de config. Rodar dois gerenciadores de `CLAUDE.md` simultaneamente causa hooks duplicados e injeção de contexto redundante (incompatibilidade estrutural, não apenas sobreposição). Ver seção "Overlaps & Conflitos".

---

## L8 — MEMORY

### mem0ai/mem0 — **DEFAULT memory substrate**

**Identidade & maturidade.** "Universal memory layer for AI Agents". RUN 0 ~57–59K★ `[sec]`; página observada mostra **58.2k★ / 6.7k forks**, "2,239 Commits", **331 releases** ([github.com/mem0ai/mem0](https://github.com/mem0ai/mem0)). Y Combinator S24. Maturidade alta: paper arXiv (2504.19413), benchmark framework open-source separado (`mem0ai/memory-benchmarks`). É o **substrato de memória default** do grupo.

**Propósito (escopo, casos de uso, persona).** Camada de memória *universal* e agnóstica de harness. Persona = um *bibliotecário de longo prazo* que lembra preferências de usuário, fatos de sessão e estado de agente. Casos de uso (README): AI assistants, customer support, healthcare, productivity/gaming. **Multi-Level Memory:** retém estado User, Session e Agent com personalização adaptativa.

**Capabilities (artefatos, automação, cobertura de harness).** Três modos de deploy: **Library** (`pip install mem0ai` / `npm install mem0ai`), **Self-Hosted Server** (`docker compose up`, com auth por default), **Cloud Platform** (zero-ops, `app.mem0.ai`). CLI dedicada (`@mem0/cli` / `mem0-cli`) com sign-up *"as an agent"* em <5s. **Novo algoritmo (April 2026):** single-pass ADD-only extraction, entity linking, multi-signal retrieval (semantic + BM25 + entity), temporal reasoning — LoCoMo 91.6, LongMemEval 94.8. Cobertura de harness via **Agent Skills**: Claude Code, Codex, Cursor, Windsurf, OpenCode, OpenClaw (`npx skills add ... --skill mem0`); diretórios `.claude-plugin/`, `.codex-plugin/`, `.cursor-plugin/` no repo.

**Lentes.**
- *OSS posture:* **License = Apache-2.0** (exato, README "Apache 2.0 — see the LICENSE file").
- *S-SDLC fit:* alto — auth-on-by-default no self-hosted, `ADMIN_API_KEY`, controle de chaves. Memória de agente é dado sensível; mem0 trata isso como primeiro-classe.
- *SaaS multi-tenant fit:* **forte** — Cloud Platform é multi-tenant zero-ops; filtros por `user_id`/`agent_id` são nativos.
- *SDD-methodology fit:* indireto (memória apoia qualquer metodologia; não impõe spec).
- *MoE expert-profile:* layer=L8; role=memory-substrate-default; competence=long-term personalization + token-efficient retrieval; persona=librarian; abstraction=add/search/API; authorization=read-write sobre o store de memória, isolado por tenant.

**SECURITY posture (incl. license).** Apache-2.0 (permissivo, patent-grant). Self-hosted com auth obrigatória. **Razão de ser o default (contexto de segurança RUN 0):** MemPalace foi **excluído** no RUN 0 por alegações *secundárias e não comprovadas* de manipulação de estrelas + benchmark não-auditável. mem0, em contraste, abre o **framework de avaliação** (`memory-benchmarks`) para reprodução independente e publica paper revisável — auditabilidade verificável é o diferencial. *(Nota: não se afirma fraude de MemPalace como fato; é a justificativa documentada para preferir o substrato com benchmark reproduzível.)*

**INTEGRATION SURFACE (mecanismos):** `{MCP, memory, filesystem, git-repo, rules, TCP}` (MCP-exposável via OpenMemory/server; REST/TCP via self-hosted server; skills como rules).

---

### letta-ai/letta — ex-MemGPT

**Identidade & maturidade.** "Platform for stateful agents: AI with advanced memory that can learn and self-improve over time." RUN 0 22,891★; página observada **23.5k★ / 2.5k forks**, "7,466 Commits", **177 releases** (v0.16.8) ([github.com/letta-ai/letta](https://github.com/letta-ai/letta)). Origem acadêmica forte (MemGPT, UC Berkeley; `CITATION.cff`). Maturidade alta como *runtime*, não apenas biblioteca.

**Propósito (escopo, casos de uso, persona).** Diferentemente de mem0/cognee (camadas de memória *plugáveis*), Letta é um **runtime de agente completo** com memória OS-tiered self-editing como peça central. Persona = um *agente-com-sistema-operacional-de-memória* que edita seus próprios `memory_blocks` (label `human`/`persona`). Casos de uso: agentes stateful que aprendem e se auto-melhoram; `Letta Code` (CLI no terminal) e `Letta API` (embutir em apps).

**Capabilities (artefatos, automação, cobertura de harness).** **Letta Code** CLI (`npm install -g @letta-ai/letta-code`) com skills + subagents pré-construídos para memória avançada/continual learning; **Letta API** com SDKs Python/TypeScript. `memory_blocks` self-editing; model-agnostic (recomenda Opus 4.5 / GPT-5.2; tem leaderboard próprio). Self-hostável (`compose.yaml`, Postgres + pgvector via `init.sql`; `otel/` para tracing; `WEBHOOK_SETUP.md`). Cobertura de harness: é *o próprio harness* (Letta Code), além de expor API para integração.

**Lentes.**
- *OSS posture:* **License = Apache-2.0** (README + `LICENSE`). Tem `AI_POLICY.md`, `SECURITY.md`, `PRIVACY.md`, `TERMS.md` — governança madura.
- *S-SDLC fit:* alto — `SECURITY.md` formal, webhooks, OTEL embutido.
- *SaaS multi-tenant fit:* forte — `app.letta.com` (hosted), API-key, deploy in-your-cloud.
- *SDD-methodology fit:* baixo-moderado (runtime, não spec-driven).
- *MoE expert-profile:* layer=L8 (mas é também um L1/runtime — *boundary expert*); role=stateful-agent-runtime + self-editing-memory; competence=continual learning, memory hierarchy; persona=self-improving-agent; abstraction=memory_blocks + agents API; authorization=read-write sobre próprio estado de memória (self-edit).

**SECURITY posture (incl. license).** Apache-2.0. Governança de IA explícita (`AI_POLICY.md`). Self-hostable com Postgres próprio = controle de dados. **Tensão competitiva:** por ser runtime completo, há *lock-in* — usar a memória do Letta implica usar o agente Letta (vs mem0/cognee que são memória plugável em qualquer agente). O README do agentmemory cita Letta como *"High (must use Letta)"* em framework lock-in.

**INTEGRATION SURFACE (mecanismos):** `{memory, webhooks, TCP, git-repo, filesystem}` (API REST/SDK; webhooks nativos; OTEL para observability). MCP não é o mecanismo primário (é runtime-first).

---

### topoteretes/cognee — graph-native control-plane

**Identidade & maturidade.** "the open-source AI memory platform for agents... persistent long-term memory across sessions with a self-hosted knowledge graph engine." RUN 0 17,453★; página observada **23.3k★ / 2.2k forks**, **121 releases** (v1.2.2, 2026-06-26), 8,426 commits ([github.com/topoteretes/cognee](https://github.com/topoteretes/cognee)). Primary language Python 85%. Maturidade alta e em rápida ascensão.

**Propósito (escopo, casos de uso, persona).** Memória **graph-native** como *control-plane*: combina vector embeddings + graph reasoning + ontologia "cognitive-science-grounded". Persona = um *arquiteto de conhecimento* que constrói um grafo de conhecimento auto-hospedado a partir de dados em qualquer formato ("Build Company Brain"). API de quatro operações: `remember`, `recall` (busca com auto-routing), `forget`, `improve`. **cognee 1.0** roda toda a camada de memória num único Postgres (relações + embeddings + sessões + metadados), *"~10% faster than the separate graph-plus-vector setup"* em CI.

**Capabilities (artefatos, automação, cobertura de harness).** Pipeline implícito `add + cognify + improve` (*"`remember()` runs add + cognify + improve"*). **MCP server dedicado** (`cognee-mcp`, imagem Docker `cognee/cognee-mcp`, transports HTTP/SSE/stdio). CLI (`cognee-cli` com `remember`/`recall`/`forget`/`-ui`) + UI local. **Backends graph:** Postgres (default), Neo4j, Neptune, Kuzu. **Backends vector:** pgvector (default), LanceDB, Qdrant, ChromaDB, Weaviate, Milvus. Cobertura de harness: **plugin Claude Code oficial** (`claude plugin marketplace add topoteretes/cognee-integrations` → `cognee-memory@cognee`) com hooks de lifecycle (`SessionStart`, `UserPromptSubmit`, `PostToolUse`, `Stop`, `PreCompact`, `SessionEnd`); **OpenClaw** (`@cognee/cognee-openclaw`); clients Python/Rust/TypeScript.

**Lentes.**
- *OSS posture:* **License = Apache-2.0** (badge + sidebar).
- *S-SDLC fit:* alto — isolamento agêntico por user/tenant, traceability, **OTEL collector** embutido, audit traits.
- *SaaS multi-tenant fit:* forte — isolamento de tenant nativo; deploy self-hosted ou Docker.
- *SDD-methodology fit:* moderado — ontologia prescrita via tipos é spec-adjacente (modela o domínio antes de ingerir).
- *MoE expert-profile:* layer=L8 (com forte componente L4-knowledge — é graph-native); role=memory-control-plane / knowledge-graph; competence=graph reasoning + ontologia + unified store; persona=knowledge-architect; abstraction=remember/recall/cognify; authorization=read-write sobre grafo+vetores, isolado por tenant.
- *Nota sobre framing "ECL"/"control-plane":* o termo exato "Extract-Cognify-Load" / "control plane" **não aparece** no README capturado; o framing mais próximo é o pipeline `add → cognify → improve`. Tratar "control-plane" como caracterização funcional (correta), não como termo-de-marca verbatim. `[UNVERIFIED]` quanto ao acrônimo ECL específico.

**SECURITY posture (incl. license).** Apache-2.0. OTEL + audit traits + tenant isolation = postura defensável para produção. A unificação em Postgres único reduz a superfície (menos serviços = menos vetores).

**INTEGRATION SURFACE (mecanismos):** `{MCP, memory, filesystem, git-repo, hooks, rules, TCP}` (MCP dedicado; hooks Claude Code; HTTP/SSE/stdio; graph+vector DBs via TCP).

---

### getzep/graphiti — temporal knowledge graph (BRIDGE L4↔L8)

**Identidade & maturidade.** "Build Real-Time Knowledge Graphs for AI Agents" / "Build Temporal Context Graphs for AI Agents". RUN 0 26,380★; página observada **27.8k★ / 2.8k forks**, **196 releases** (v0.29.2, 2026-06-08) ([github.com/getzep/graphiti](https://github.com/getzep/graphiti)). Python 99.4%. Paper arXiv 2501.13956 ("Zep: A Temporal Knowledge Graph Architecture for Agent Memory"). **Tratado como BRIDGE L4↔L8** — é simultaneamente engine de grafo de conhecimento (L4) e substrato de memória de agente (L8).

**Propósito (escopo, casos de uso, persona).** Grafo de **contexto temporal** onde cada fato tem janela de validade ("Kendra loves Adidas shoes *as of March 2026*"). Diferente de knowledge graphs estáticos, rastreia *o que é verdade agora* vs *o que era verdade antes*, com proveniência total até os **episodes** (dados crus). Persona = um *historiador bi-temporal* que invalida fatos em vez de deletá-los. Componentes: Entities (nodes), Facts/Relationships (edges com validade temporal), Episodes (proveniência), Custom Types (ontologia via Pydantic).

**Capabilities (artefatos, automação, cobertura de harness).** `pip install graphiti-core`. Backends: **Neo4j 5.26 / FalkorDB / Amazon Neptune / Kuzu (deprecated)**. Hybrid retrieval (semantic + BM25 + graph traversal), sub-second latency, fact invalidation automática. **MCP server** (`mcp_server/`) — *"Give Claude, Cursor, and other MCP clients powerful context graph-based memory with temporal awareness"* (README). REST service (FastAPI, `server/`). **OTEL tracing** (`OTEL_TRACING.md`). LLM-agnostic (OpenAI default; Anthropic, Gemini, Groq, Azure, Ollama/vLLM/local via OpenAI-compatible). Telemetria anônima opt-out (PostHog).

**Lentes.**
- *OSS posture:* **License = Apache-2.0** (badge + `LICENSE` + `Zep-CLA.md` para contribuições).
- *S-SDLC fit:* alto — proveniência/lineage de cada fato é auditoria por design; OTEL embutido.
- *SaaS multi-tenant fit:* via **Zep** (a infra gerenciada comercial cujo core OSS é o graphiti) — sub-200ms a escala, governança, dashboard. graphiti puro é self-hosted only.
- *SDD-methodology fit:* moderado-alto — ontologia *prescrita* via Pydantic models é spec-driven knowledge modeling.
- *MoE expert-profile:* layer=L4↔L8 bridge; role=temporal-knowledge-graph-engine; competence=bi-temporal fact management + provenance; persona=bi-temporal-historian; abstraction=episodes/entities/facts; authorization=read-write sobre o grafo.

**SECURITY posture (incl. license).** Apache-2.0 (+ CLA para contribuidores). `SECURITY.md` formal. Telemetria explícita e opt-out, com lista clara do que **não** é coletado (*"never: API keys or credentials... your actual data"*). Proveniência temporal = trilha de auditoria nativa.

**INTEGRATION SURFACE (mecanismos):** `{MCP, memory, git-repo, filesystem, TCP}` (MCP server; REST/FastAPI; graph DBs Neo4j/FalkorDB/Neptune via TCP; OTEL export).

**Relação BASELINE/NEIGHBOR.** **Zep** = SaaS (graphiti é seu core OSS) — relação engine↔plataforma idêntica ao par Graphiti/Zep documentado no README ("Choose Zep [turnkey]... Choose Graphiti [flexible OSS core]").

---

### rohitg00/agentmemory — coding-agent memory (NEIGHBOR)

**Identidade & maturidade.** "Persistent memory for AI coding agents... No more re-explaining." RUN 0 14,818★, Apache-2.0. Construído sobre o **iii engine** ([github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory)). npm `@agentmemory/agentmemory`; pinado a `iii-engine v0.11.2`. NEIGHBOR especializado em **memória de coding-agent** (não memória genérica de assistente).

**Propósito (escopo, casos de uso, persona).** Foco estreito e deliberado: memória para *coding agents*, capturada silenciosamente via hooks. Persona = um *gravador-de-sessão-de-código* que elimina o re-explicar arquitetura a cada sessão. Exemplo canônico do README: Session 1 monta JWT auth → Session 2 pede rate limiting e o agente *"already knows your auth uses jose middleware in `src/middleware/auth.ts`"*. Diferencial declarado: built-in memory (`CLAUDE.md`, `.cursorrules`) *"caps out at 200 lines and goes stale"*.

**Capabilities (artefatos, automação, cobertura de harness).** Servidor de memória local (`:3111`) + real-time viewer (`:3113`) com **Session Replay** (importa JSONL do Claude Code). **53 MCP tools**, **12 auto hooks**, **0 external DBs** (SQLite + iii-engine). Busca híbrida **BM25 + Vector + Graph (RRF fusion)**, 4-tier consolidation + decay + auto-forget. Embeddings locais (`all-MiniLM-L6-v2`, $0). **Cobertura de harness extremamente ampla** — *"any agent that speaks MCP or HTTP"*: Claude Code (plugin nativo + 12 hooks + MCP), Codex CLI (plugin + 6 hooks), OpenCode (22 hooks), OpenClaw, Hermes, pi, Cursor, Gemini CLI, Cline, Goose, Kilo Code, Aider (REST), Claude Desktop, Windsurf, Roo Code. Templates de deploy (fly.io, Railway, Render, Coolify).

**Lentes.**
- *OSS posture:* **License = Apache-2.0** (RUN 0). Badge de licença presente (shields.io/github/license).
- *S-SDLC fit:* alto para o nicho — audit policy codificada em *"every delete path"*, governance_delete tool, HMAC secret no deploy, drop de privilégios `root`→`node` via gosu.
- *SaaS multi-tenant fit:* moderado — self-hosted por default; coordenação multi-agent via *"MCP + REST + leases + signals"*; deploy templates mas não SaaS gerenciado.
- *SDD-methodology fit:* baixo (memória, não spec).
- *MoE expert-profile:* layer=L8; role=coding-agent-memory-specialist; competence=hook-driven silent capture + hybrid retrieval; persona=session-recorder; abstraction=remember/observe/smart-search (iii functions); authorization=read-write local, HMAC-gated.

**SECURITY posture (incl. license).** Apache-2.0. **Dependência crítica de supply-chain:** todo o sistema é *"already a running iii instance"* — funções, triggers, KV, streams, OTEL são primitivos do `iii-engine` (binário nativo separado, **não publicado no crates.io**, instalado via script `sh`/Docker/binário pré-compilado). Isso concentra risco no upstream `iii-hq/iii`. Viewer fica em loopback; só `:3111` é publicado.

**INTEGRATION SURFACE (mecanismos):** `{MCP, memory, hooks, filesystem, git-repo, rules, TCP, webhooks}` (53 MCP tools; REST `:3111`; iii functions via `ws://`; hooks de lifecycle; triggers HTTP/cron/event).

---

## L9 — OBSERVABILITY

### langfuse/langfuse — **DEFAULT observability**

**Identidade & maturidade.** "Open source LLM engineering platform: LLM Observability, metrics, evals, prompt management, playground, datasets." RUN 0 28,219★; página observada **27.2k★ / 2.8k forks**, 7,015 commits ([github.com/langfuse/langfuse](https://github.com/langfuse/langfuse)). Y Combinator W23. **Default de observability** do grupo. Backed por ClickHouse.

**Propósito (escopo, casos de uso, persona).** Plataforma de **LLMOps/LLM-engineering** para times *"collaboratively develop, monitor, evaluate, and debug AI applications"* (README). Persona = um *engenheiro-de-observabilidade* que dá visibilidade humana sobre traces de LLM, retrieval, e ações de agente. Cinco pilares: Observability (tracing), Prompt Management (versionado), Evaluations (LLM-as-judge + feedback + manual), Datasets (benchmarks), Playground.

**Capabilities (artefatos, automação, cobertura de harness).** **OTel-native** — `LangfuseSpanProcessor` plugado no `@opentelemetry/sdk-node`; ingere qualquer app que emita spans OTLP. SDKs tipados Python + JS/TS; OpenAI drop-in (`from langfuse.openai import openai`). Deploy: Docker Compose / VM / **Kubernetes (Helm, preferido prod)** / Terraform (AWS/Azure/GCP). **Regiões de dados incl. HIPAA** (`hipaa.cloud.langfuse.com`). Cobertura de harness/framework muito ampla: OpenTelemetry, LangChain, LlamaIndex, Vercel AI SDK, LiteLLM (100+ LLMs), CrewAI, AutoGen, Google ADK, Haystack, DSPy, smolagents, Goose, etc. **Integração agêntica direta:** *"Langfuse Agent Skill"* ([github.com/langfuse/skills](https://github.com/langfuse/skills), `npx skills add langfuse/skills`), **Cursor Plugin** (`cursor.com/marketplace/langfuse`), e **Docs MCP Server** (`langfuse.com/docs/docs-mcp`). Isto confirma o "Claude plugin" mencionado no RUN 0 via o canal de skills/plugin cross-harness.

**Lentes.**
- *OSS posture:* **License = NOASSERTION / source-available** — *"This repository is MIT licensed, except for the `ee` folders"* (README). RUN 0 registrou `license=NOASSERTION` (GitHub não consegue classificar por causa do split MIT-core + EE). Tratar como **MIT-core com pastas Enterprise Edition proprietárias**.
- *S-SDLC fit:* alto — prompt management versionado + evals em CI são práticas seguras de SDLC; região HIPAA; página `Security & Guardrails`.
- *SaaS multi-tenant fit:* **forte** — Langfuse Cloud multi-região (EU/US/Japan/HIPAA) + Enterprise tier; self-host com Helm.
- *SDD-methodology fit:* moderado — datasets + evals estruturados aproximam-se de spec-driven validation.
- *MoE expert-profile:* layer=L9; role=observability-default + LLMOps; competence=tracing + evals + prompt-mgmt; persona=observability-engineer; abstraction=traces/observations/spans (OTel); authorization=read-write sobre store de traces, multi-tenant por project.

**SECURITY posture (incl. license).** **Modelo source-available, NÃO 100% OSS** — o core é MIT mas as pastas `ee/` são proprietárias (Enterprise Edition). Esta é a distinção de licença mais importante do grupo: ao contrário de mem0/letta/cognee/graphiti (Apache-2.0 puro), langfuse tem componentes não-livres. Compliance: região HIPAA dedicada, SOC2/segurança documentados em `langfuse.com/security`. Self-hostável em minutos = controle de dados.

**INTEGRATION SURFACE (mecanismos):** `{MCP, webhooks, filesystem, git-repo, rules, TCP, hooks}` (OTel/OTLP ingest via TCP; Docs MCP server; Agent Skill + Cursor plugin como rules; SDK; ClickHouse backend).

---

### traceloop/openllmetry — OTel instrumentation (NEIGHBOR)

**Identidade & maturidade.** "Open-source observability for your GenAI or LLM application, based on OpenTelemetry." RUN 0 7,153★ Apache-2.0; página observada **7.1k★ / 960 forks**, **257 releases** (0.60.0) ([github.com/traceloop/openllmetry](https://github.com/traceloop/openllmetry)). YC. Python 100%. NEIGHBOR de instrumentação.

**Propósito (escopo, casos de uso, persona).** *Não* é uma plataforma — é o **conjunto de instrumentações OTel** que alimenta plataformas. Persona = um *plugue-padrão* que emite spans OpenTelemetry conectáveis a Datadog, Honeycomb, Grafana, e qualquer backend OTel. *"It's built and maintained by Traceloop under the Apache 2.0 license."* Suas semantic conventions foram **adotadas pelo OpenTelemetry** (*"Our semantic conventions are now part of OpenTelemetry"*).

**Capabilities (artefatos, automação, cobertura de harness).** `pip install traceloop-sdk` + `Traceloop.init()` (uma linha). Instrumenta LLM providers (OpenAI, Anthropic, Bedrock, Cohere, Gemini, Groq, Mistral, Ollama, etc.), Vector DBs (Chroma, Pinecone, Qdrant, Weaviate, Milvus, LanceDB, Marqo), frameworks (LangChain, LlamaIndex, CrewAI, Haystack, LangGraph, AWS Strands, OpenAI Agents, Agno) e **MCP** (o protocolo). ~21 destinos testados. JS/TS via `openllmetry-js` separado.

**Lentes.**
- *OSS posture:* **License = Apache-2.0** (puro; `GOVERNANCE.md` + `MAINTAINERS.md`).
- *S-SDLC fit:* moderado-alto (instrumentação é fundação de observabilidade; sem opinião sobre SDLC).
- *SaaS multi-tenant fit:* via Traceloop (plataforma comercial); o SDK em si é vendor-neutral.
- *SDD-methodology fit:* N/A.
- *MoE expert-profile:* layer=L9; role=OTel-instrumentation-foundation; competence=vendor-neutral span emission; persona=standard-plug; abstraction=OTel spans; authorization=read-only (apenas emite telemetria).

**SECURITY posture.** Apache-2.0 puro (mais permissivo que langfuse). Não coleta mais telemetria no SDK (≥v0.49.2). Por ser vendor-neutral, reduz lock-in. **Pareamento natural:** openllmetry (instrumentação) → langfuse/opik/phoenix/qualquer-OTel-backend (visualização). É *complemento*, não competidor, das plataformas.

**INTEGRATION SURFACE (mecanismos):** `{filesystem, git-repo, TCP}` (emissão OTLP/TCP para qualquer backend; instrumenta MCP como protocolo).

---

### lmnr-ai/lmnr — Laminar, agent-debug (NEIGHBOR)

**Identidade & maturidade.** "Laminar - open-source observability platform purpose-built for AI agents. YC S24." RUN 0 ~2.8K★ `[sec]` Apache-2.0 (ex-`laminar`, renomeado para `lmnr`); página observada **3k★ / 205 forks**, **86 releases** (v0.1.46) ([github.com/lmnr-ai/lmnr](https://github.com/lmnr-ai/lmnr)). TypeScript 72% + **Rust 23%**. NEIGHBOR focado em *debug de agentes*.

**Propósito (escopo, casos de uso, persona).** Observabilidade *purpose-built for AI agents* (não LLM apps genéricos). Persona = um *depurador-de-agente em tempo real*. Diferenciais: motor realtime em **Rust** para ver traces *enquanto acontecem*, full-text search ultra-rápido sobre spans, **SQL access** a todos os dados (SQL editor embutido), AI monitoring via eventos descritos em linguagem natural ("signals").

**Capabilities (artefatos, automação, cobertura de harness).** OTel-native, 1 linha (`Laminar.initialize(...)` / `@observe()` decorator). Auto-traça Vercel AI SDK, Browser Use, Stagehand, LangChain, OpenAI, Anthropic, Gemini. Evals (SDK + CLI, local/CI). Dashboards + data annotation + datasets. **`pii-redactor`** e gRPC exporter. Self-host fácil (`docker compose up`, UI em `:5667`); LLM provider configurável (Gemini/OpenAI/Bedrock).

**Lentes.**
- *OSS posture:* **License = Apache-2.0** (badge).
- *S-SDLC fit:* alto — PII redactor nativo + SQL auditável + evals em CI/CD.
- *SaaS multi-tenant fit:* via `laminar.sh` (managed). Self-host full via `docker-compose-full.yml`.
- *SDD-methodology fit:* moderado (evals + datasets).
- *MoE expert-profile:* layer=L9; role=agent-debug-observability; competence=realtime tracing + SQL + agent-specific signals; persona=realtime-debugger; abstraction=OTel spans + SQL; authorization=read-write sobre traces.

**SECURITY posture.** Apache-2.0. PII redactor embutido (`pii-redactor/`) é diferencial de privacidade. Rust no caminho crítico = menor superfície de bugs de memória. **Nota de identidade (RUN 0):** confirmado o rename `laminar` → `lmnr` — mesmo projeto, não confundir com outras "laminar".

**INTEGRATION SURFACE (mecanismos):** `{filesystem, git-repo, TCP}` (OTel + gRPC exporter via TCP; SQL API; rules via `rules/` dir no repo).

---

### comet-ml/opik — eval+observability (NEIGHBOR)

**Identidade & maturidade.** "Debug, evaluate, and monitor your LLM applications, RAG systems, and agentic workflows with comprehensive tracing, automated evaluations, and production-ready dashboards." RUN 0 18,829★ Apache-2.0; página observada **19.7k★ / 1.5k forks**, **493 releases** (2.0.73) ([github.com/comet-ml/opik](https://github.com/comet-ml/opik)). Python 55% + TS 44%. Por **Comet**. NEIGHBOR full-platform.

**Propósito (escopo, casos de uso, persona).** Plataforma OSS de observability + evaluation *"from prototype to production"*, cobrindo *"RAG chatbots to code assistants to complex agentic systems"*. Persona = um *avaliador-e-monitor* com forte ênfase em evals automatizados. Quatro pilares: Comprehensive Observability (tracing de chamadas LLM + agent activity), Advanced Evaluation (LLM-as-judge, experiment mgmt), **Opik Agent Optimizer** (SDK + otimizadores de prompts/agents), **Opik Guardrails** (AI segura/responsável).

**Capabilities (artefatos, automação, cobertura de harness).** SDKs Python, TypeScript, **Ruby (via OpenTelemetry)** + REST API. OTel para chamadas suportadas. Self-host: **Docker Compose** + **Kubernetes/Helm**; Cloud via Comet.com. Integra OpenAI, Anthropic, Gemini, Bedrock, Cohere, Groq, Mistral, LiteLLM, LangChain, LangGraph, LlamaIndex, Haystack, CrewAI, AutoGen, AG2, DSPy, Dify, Flowise, Google ADK, BeeAI; validações Guardrails AI. Integração pytest; LLM-as-judge para hallucination detection + moderation. Prompt Playground.

**Lentes.**
- *OSS posture:* **License = Apache-2.0** (puro).
- *S-SDLC fit:* **muito alto** — único do grupo a empacotar **Guardrails** + **Agent Optimizer** + pytest integration juntos; evals como gate de CI.
- *SaaS multi-tenant fit:* via Comet.com / Opik Cloud (managed); self-host Docker/K8s. Multi-tenancy enterprise não destacada no README `[UNVERIFIED]`.
- *SDD-methodology fit:* alto — experiments + datasets + evals automatizados.
- *MoE expert-profile:* layer=L9 (+ spillover L0-guardrails via Opik Guardrails); role=eval-centric-observability; competence=automated evals + agent optimization + guardrails; persona=evaluator; abstraction=traces + experiments + optimizers; authorization=read-write sobre traces/experiments.

**SECURITY posture.** Apache-2.0. **Opik Guardrails** torna-o parcialmente um expert L0 também (safe/responsible AI). Sem claims explícitos de SOC2/HIPAA/RBAC no README (`[UNVERIFIED]` para multi-tenant enterprise).

**INTEGRATION SURFACE (mecanismos):** `{filesystem, git-repo, TCP, rules, hooks}` (OTel/REST via TCP; pytest hooks; Guardrails como rules). MCP server dedicado **não** anunciado no README.

---

### Arize-ai/phoenix — OpenInference-based (NEIGHBOR)

**Identidade & maturidade.** "AI Observability & Evaluation". RUN 0 9,918★ NOASSERTION; página observada **9.7k★ / 869 forks** ([github.com/Arize-ai/phoenix](https://github.com/Arize-ai/phoenix)). Python + TS/JS + Java. Por **Arize AI**. NEIGHBOR construído sobre **OpenInference**.

**Propósito (escopo, casos de uso, persona).** *"an open-source AI observability platform designed for experimentation, evaluation, and troubleshooting"* (README), *"vendor and language agnostic"*. Persona = um *observador-vendor-agnóstico* que roda *"practically anywhere... local machine, Jupyter notebook, containerized deployment, or in the cloud"*. Capabilities: Tracing (OTel-based), Evaluation (response + retrieval evals), Datasets (versionados), Experiments, Playground, Prompt Management.

**Capabilities (artefatos, automação, cobertura de harness).** `pip install arize-phoenix` / conda; Docker Hub (`arizephoenix/phoenix`); Helm; Jupyter notebook. Construído sobre **OpenTelemetry + OpenInference** (projeto de auto-instrumentação separado, `openinference-instrumentation-*`). **MCP server** (`@arizeai/phoenix-mcp` — *"unified interface to Phoenix's capabilities"*, badge "MCP Enabled" + deeplink Cursor). **Integração de coding-agent forte:** `@arizeai/phoenix-cli` é *"CLI for fetching traces, datasets, and experiments for use with Claude Code, Cursor, and other coding agents"*; ships **"Coding Agent Skills"** em `.agents/skills/` (`phoenix-cli`, `phoenix-evals`) + `CLAUDE.md`/`AGENTS.md` no repo. **Claude Agent SDK** instrumentação dedicada (Python + JS). Cobre OpenAI Agents SDK, LangGraph/LangChain (+ Java), CrewAI, LlamaIndex, DSPy, Haystack, Smolagents, Pydantic AI, Autogen, BeeAI, NVIDIA NeMo.

**Lentes.**
- *OSS posture:* **License = NOASSERTION** (RUN 0). O README capturado **não** mostra a string SPDX exata (`[UNVERIFIED]` quanto a ser Elastic vs Apache vs BSD; o sidebar de licença não foi capturado). RUN 0 registra NOASSERTION — tratar como source-available/non-standard até confirmar o arquivo LICENSE.
- *S-SDLC fit:* alto — evals + experiments + Claude Code skills para troubleshooting in-loop.
- *SaaS multi-tenant fit:* via **Arize** (cloud em `app.phoenix.arize.com`); Phoenix OSS é self-host.
- *SDD-methodology fit:* moderado-alto (datasets + experiments versionados).
- *MoE expert-profile:* layer=L9; role=vendor-agnostic-observability + OpenInference; competence=tracing + evals + coding-agent integration; persona=vendor-neutral-observer; abstraction=OTel/OpenInference spans; authorization=read-write sobre traces.

**SECURITY posture (incl. license).** **License NOASSERTION** (igual flag de cautela que langfuse, mas pior: a string não é nem confirmável do README — requer leitura do `LICENSE` + `IP_NOTICE` + `CLA.md` presentes no repo). Por ser OpenInference/OTel-based, é vendor-neutral. Relação com Arize: Phoenix é o OSS, Arize é a SaaS comercial parente (mesmo padrão engine↔plataforma de graphiti↔Zep).

**INTEGRATION SURFACE (mecanismos):** `{MCP, filesystem, git-repo, rules, TCP, hooks}` (`@arizeai/phoenix-mcp`; phoenix-cli para coding agents; Coding Agent Skills como rules; OTel/OpenInference via TCP).

---

# OVERLAPS, COLABORAÇÃO vs COMPETIÇÃO vs INCOMPATIBILIDADES (com evidência)

## L0 Guardrails — competição estrutural por um recurso único

**karpathy-skills vs BASE: sobreposição parcial, não competição direta.** karpathy-skills é *conteúdo de princípios* (estático, prosa); BASE é *gestão de estado de workspace* (dinâmico, JSON+hooks+MCP). Podem coexistir: karpathy-skills define *como pensar*, BASE define *o que está no contexto*. Mas ambos escrevem em/sobre `CLAUDE.md`/`.claude/`.

**BASE vs ECC: INCOMPATIBILIDADE estrutural (evidência).** O prompt RUN 0 marca BASE como *"rules-OS / CLAUDE.md manager (conflicts with other CLAUDE.md managers e.g. ECC)"*. A evidência interna corrobora: BASE embute `/base:audit-claude` que detecta exatamente *"duplicated hooks running twice, stale config referencing nonexistent tools, skills duplicated across project dirs"* e o upgrade v2→v3 arquiva cópias de hooks *"double-fire-causing"*. Dois gerenciadores de `CLAUDE.md` rodando juntos produzem hooks que disparam em duplicata e injeção redundante de contexto. **Veredito:** escolher UM orquestrador de `CLAUDE.md` por workspace; rodar BASE + ECC simultaneamente é anti-padrão.

## L8 Memory — backends concorrentes (mem0 vs letta vs cognee vs graphiti vs agentmemory)

**A competição mais direta do grupo.** Há evidência *de primeira mão* num dos próprios experts: o README do agentmemory publica uma tabela comparativa explícita "vs Competitors" (agentmemory vs mem0 vs Letta vs Built-in):

| Eixo (do README agentmemory) | agentmemory | mem0 | Letta/MemGPT |
|---|---|---|---|
| Type | Memory engine + MCP server | Memory layer API | **Full agent runtime** |
| Search | BM25+Vector+Graph (RRF) | Vector+Graph | Vector (archival) |
| Framework lock-in | None (any MCP) | None | **High (must use Letta)** |
| External deps | None (SQLite+iii) | Qdrant/pgvector | Postgres+vector DB |

**Distinções arquiteturais que determinam competição vs coexistência:**
- **letta é categorialmente diferente** — é um *runtime de agente completo*, não uma camada plugável. Competir "letta vs mem0" é parcialmente uma falsa dicotomia: usar letta = usar o agente letta (lock-in alto); usar mem0/cognee/agentmemory = plugar memória em *qualquer* agente. **Incompatibilidade prática:** letta não é um "backend de memória" que se acopla a Claude Code do mesmo jeito que mem0 — é um harness rival.
- **mem0 vs cognee:** ambos plugáveis, ambos Apache-2.0, ambos com MCP + skills cross-harness. Diferença = **modelo de dados**: mem0 é memory-layer (semantic+BM25+entity, store flexível); cognee é **graph-native** (knowledge graph + ontologia como control-plane). Competem pelo slot "substrato de memória default" — RUN 0 elege **mem0 como default** (benchmark reproduzível/auditável); cognee é a alternativa graph-first quando o caso de uso exige raciocínio sobre relações.
- **graphiti é o BRIDGE L4↔L8** — não compete *de frente* com mem0 porque resolve um eixo ortogonal: **temporalidade** (fatos com janela de validade, invalidação automática). Pode *complementar* mem0 (mem0 para preferências, graphiti para fatos que mudam no tempo) OU competir com cognee (ambos graph-native). Diferença cognee vs graphiti: cognee = ontologia cognitive-science + unified Postgres; graphiti = bi-temporal + proveniência por episode.
- **agentmemory é nicho** — só coding-agents, hook-driven, 0 DBs externos. Não compete com mem0 no mercado de "memória de assistente genérico"; compete no slot estreito "memória de coding-agent" — onde sua tabela o posiciona contra `CLAUDE.md`/`.cursorrules` built-in mais do que contra mem0.

**Incompatibilidade de backend compartilhado:** mem0, cognee, graphiti e agentmemory **todos** podem querer pgvector/Postgres/Qdrant. Rodar múltiplos substratos de memória sobre o mesmo store sem namespacing causa colisão de embeddings — escolher UM substrato primário de memória por agente é a recomendação (embora graphiti-como-bridge + mem0-como-layer seja uma composição válida por serem eixos diferentes).

## L9 Observability — instrumentação vs plataforma (composição, não competição)

**openllmetry NÃO compete com langfuse/opik/phoenix — ele os ALIMENTA.** Evidência: openllmetry é *"a set of extensions built on top of OpenTelemetry"* cujas *"semantic conventions are now part of OpenTelemetry"*; emite OTLP para *"Datadog, Honeycomb, and others"*. langfuse, opik e phoenix são todos **OTel-native** (langfuse via `LangfuseSpanProcessor`; phoenix via OpenInference; opik via OTel SDKs). **Pareamento canônico:** openllmetry (instrumentação vendor-neutral) → qualquer backend OTel (langfuse/opik/phoenix/lmnr) para visualização. Esta é a relação de *colaboração* mais limpa do grupo inteiro.

**langfuse vs opik vs phoenix vs lmnr: competição real entre plataformas full-stack.** Todas fazem tracing + evals + datasets + playground. Diferenciadores:
- **langfuse** = default, prompt-management mais maduro, mais integrações de framework, região HIPAA. **Mas:** licença source-available (MIT-core + `ee/` proprietário) — a única não-Apache-pura entre as plataformas-default.
- **opik** = único com **Guardrails + Agent Optimizer + pytest** empacotados (mais "S-SDLC"); Apache-2.0 puro.
- **phoenix** = vendor-agnóstico via OpenInference, mais forte em coding-agent skills (`phoenix-cli` para Claude Code/Cursor) + Claude Agent SDK instrumentation; **mas** licença NOASSERTION (cautela).
- **lmnr** = purpose-built para *agentes* (não LLM apps), realtime Rust, SQL access, PII redactor; menor/mais novo (3k★).

**Qual observability pareia com qual memory?** Não há acoplamento forçado — todos os pares funcionam por serem camadas ortogonais. Pareamentos naturais por afinidade:
- **graphiti + langfuse/phoenix** — ambos têm OTEL embutido; graphiti emite traces que langfuse/phoenix ingerem nativamente.
- **cognee + qualquer-OTel-backend** — cognee tem OTEL collector embutido.
- **mem0 (default) + langfuse (default)** — o par "default×default" recomendado pelo RUN 0; ambos maduros, multi-tenant, com skills cross-harness para Claude Code.
- **opik** se o requisito for *evals-como-gate + guardrails* no S-SDLC.

## Padrão recorrente: OSS-engine ↔ SaaS-platform

Três experts seguem o mesmo modelo *open-core*: **graphiti↔Zep**, **phoenix↔Arize**, **langfuse-core↔langfuse-EE/Cloud**. Implicação de governança: o roadmap do OSS é influenciado pelo produto comercial; features enterprise (governança, SLA, sub-200ms) ficam atrás de paywall ou em pastas `ee/`. mem0 e letta também têm Cloud, mas mantêm Apache-2.0 puro no core.

---

# MATRIZ DE COMPARAÇÃO

| expert | layer | role | license | stars+date | scope | harnesses | MCP? | git-flow | S-SDLC | multi-tenant | memory? | observability? | security |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| multica-ai/andrej-karpathy-skills | L0 | guardrail/policy (princípios de código) | **none** (README diz MIT; sem LICENSE) | ~154k (API) · 2026-06-27 | arquivo único de princípios | Claude Code, Cursor | não | só rules/repo | médio (policy baseline) | N/A | não | não | mínima (texto); risco=provenance |
| ChristopherKahler/base | L0(+L8) | workspace-state / config-hygiene | **none** (README diz MIT; sem LICENSE) | 87 (API) · 2026-06-27 | OS de workspace, anti-staleness | Claude Code only | **sim** (BASE MCP, 20 tools) | leitura p/ detecção | médio (config hygiene) | não (JSON local) | sim (PSMM/surfaces) | parcial (drift score) | hooks exec local; ⚠️conflito c/ ECC |
| mem0ai/mem0 | L8 | **memory default** | **Apache-2.0** | ~58k · 2026-06-27 | memória universal plugável | Claude Code, Codex, Cursor, Windsurf, OpenCode, OpenClaw | **sim** (OpenMemory/server) | rules/repo + skills | alto (auth-on) | **forte** (Cloud) | **sim (core)** | não | Apache-2.0; benchmark reproduzível |
| letta-ai/letta | L8(+L1 runtime) | stateful-agent runtime + self-edit mem | **Apache-2.0** | ~23.5k · 2026-06-27 | runtime de agente c/ memória OS-tiered | é o próprio harness (Letta Code) + API | parcial (não primário) | repo/CI | alto (SECURITY.md, OTEL) | forte (app.letta.com) | **sim (self-edit)** | OTEL embutido | Apache-2.0; lock-in de runtime |
| topoteretes/cognee | L8(+L4) | memory control-plane / KG | **Apache-2.0** | ~23.3k · 2026-06-27 | memória graph-native + ontologia | Claude Code (plugin+hooks), OpenClaw | **sim** (cognee-mcp Docker) | hooks + repo | alto (OTEL, tenant iso) | forte (tenant iso) | **sim (graph+vector)** | OTEL collector | Apache-2.0; unified Postgres |
| getzep/graphiti | **L4↔L8 bridge** | temporal knowledge graph | **Apache-2.0** | ~27.8k · 2026-06-27 | grafo de contexto bi-temporal | Claude, Cursor, MCP clients | **sim** (mcp_server) | repo/CI | alto (proveniência=auditoria) | via Zep (SaaS) | **sim (temporal)** | OTEL (OTEL_TRACING.md) | Apache-2.0+CLA; lineage nativo |
| rohitg00/agentmemory | L8 | coding-agent memory (NEIGHBOR) | **Apache-2.0** | ~14.8k · 2026-06-27 | memória hook-driven p/ coding agents | 16+ (Claude Code, Codex, Cursor, OpenCode, Gemini, Cline, Goose, Aider...) | **sim** (53 tools) | hooks + repo | alto p/ nicho (audit paths, HMAC) | moderado (self-host) | **sim (BM25+vec+graph)** | iii OTEL embutido | Apache-2.0; ⚠️dep iii-engine (não em crates.io) |
| langfuse/langfuse | L9 | **observability default** + LLMOps | **NOASSERTION** (MIT-core + `ee/` propr.) | ~28.2k · 2026-06-27 | tracing+evals+prompt-mgmt | OTel + LangChain/LlamaIndex/CrewAI/AutoGen... + Skill/Cursor plugin | **sim** (Docs MCP) | repo/CI | alto (HIPAA, prompt-versioning) | **forte** (Cloud multi-região) | não | **sim (core)** | source-available (ee/ não-livre); HIPAA |
| traceloop/openllmetry | L9 | OTel instrumentation (NEIGHBOR) | **Apache-2.0** | ~7.1k · 2026-06-27 | instrumentação vendor-neutral | qualquer backend OTel; instrumenta MCP | instrumenta MCP (protocolo) | repo/CI | médio-alto (fundação) | via Traceloop | não | **sim (emite OTLP)** | Apache-2.0 puro; sem telemetria SDK |
| lmnr-ai/lmnr (Laminar) | L9 | agent-debug observability (NEIGHBOR) | **Apache-2.0** | ~3k · 2026-06-27 | observability p/ agentes, realtime Rust | Vercel AI, Browser Use, LangChain, OpenAI/Anthropic/Gemini | parcial (OTel/gRPC) | repo (rules/) | alto (PII redactor, SQL) | via laminar.sh | não | **sim (realtime)** | Apache-2.0; PII redactor embutido |
| comet-ml/opik | L9(+L0) | eval-centric observability (NEIGHBOR) | **Apache-2.0** | ~19.7k · 2026-06-27 | observability+evals+guardrails+optimizer | OpenAI/Anthropic/Gemini/LangChain/CrewAI/AutoGen/ADK... | não (sem MCP dedicado) | pytest hooks + repo | **muito alto** (Guardrails+pytest) | Comet Cloud (`[UNVERIFIED]` enterprise) | não | **sim (eval-first)** | Apache-2.0; Guardrails embutido |
| Arize-ai/phoenix | L9 | vendor-agnostic observability (NEIGHBOR) | **NOASSERTION** (`[UNVERIFIED]` string) | ~9.7k · 2026-06-27 | tracing+evals via OpenInference | Claude Code/Cursor (phoenix-cli+skills), Claude Agent SDK, LangGraph... | **sim** (@arizeai/phoenix-mcp) | skills + repo | alto (evals + coding-agent in-loop) | via Arize (app.phoenix.arize.com) | não | **sim (OpenInference)** | NOASSERTION (cautela); vendor-neutral |

> Legenda: ★ = ordem de grandeza datada (2026-06-27). "RUN0=" indica discrepância com o valor de licença do RUN 0. ⚠️ = ponto de atenção (licença/segurança/conflito).

---

# Fontes

Fontes PRIMÁRIAS (repo README/docs), via `mcp__workspace__web_fetch`, observadas 2026-06-27:

**L0 Guardrails**
- https://github.com/multica-ai/andrej-karpathy-skills (README: 4 princípios, license MIT, 183k★)
- https://github.com/ChristopherKahler/base (README: BASE MCP 20 tools, hooks, /base:audit-claude, drift score, MIT)

**L8 Memory**
- https://github.com/mem0ai/mem0 (README: Apache-2.0, novo algoritmo April 2026, modos library/self-hosted/cloud, agent skills cross-harness)
- https://github.com/letta-ai/letta (README: Apache-2.0, Letta Code CLI, memory_blocks self-edit, OTEL, runtime)
- https://github.com/topoteretes/cognee (README: Apache-2.0, cognee-mcp, graph+vector backends, Claude Code plugin+hooks, OTEL collector, v1.2.2)
- https://github.com/getzep/graphiti (README: Apache-2.0, temporal context graph, MCP server, Neo4j/FalkorDB/Neptune, OTEL_TRACING.md, paper arXiv 2501.13956, Zep relationship)
- https://raw.githubusercontent.com/rohitg00/agentmemory/main/README.md (README: Apache-2.0, 53 MCP tools, 12 hooks, BM25+Vector+Graph RRF, tabela vs mem0/Letta, iii-engine dependency, 16+ harnesses)

**L9 Observability**
- https://github.com/langfuse/langfuse (README: MIT-core+ee/, ClickHouse, YC W23)
- https://langfuse.com/docs/observability/get-started (docs: OTel-native LangfuseSpanProcessor, Agent Skill github.com/langfuse/skills, Cursor plugin, Docs MCP, região HIPAA)
- https://github.com/traceloop/openllmetry (README: Apache-2.0, OTel semantic conventions adotadas pelo OTel, ~21 destinos, instrumenta MCP)
- https://github.com/lmnr-ai/lmnr (README: Apache-2.0, Laminar, Rust realtime, SQL access, pii-redactor, YC S24)
- https://github.com/comet-ml/opik (README: Apache-2.0, Opik Guardrails + Agent Optimizer, pytest, Docker/K8s, by Comet)
- https://github.com/Arize-ai/phoenix (README: OpenInference, @arizeai/phoenix-mcp, phoenix-cli para Claude Code/Cursor, Claude Agent SDK instrumentation, Arize relationship)

**Fontes secundárias / cross-referência (independentes do repo principal):**
- Tabela "vs Competitors" do agentmemory (fonte independente sobre mem0 R@5 68.5% LoCoMo, Letta 83.2%, lock-in)
- README do graphiti seção "Graphiti and Zep" / "Zep vs Graphiti" (fonte primária sobre a relação engine↔SaaS)
- Cross-referência openllmetry↔langfuse/phoenix via convergência OpenTelemetry (semantic conventions compartilhadas, confirmada em ambos os READMEs)
- Prompt RUN 0 (valores datados de estrelas/licença/identidade canonicalizada; contexto de exclusão de MemPalace)

> **Itens `[UNVERIFIED]`:** (1) acrônimo "ECL/Extract-Cognify-Load" / termo "control-plane" verbatim em cognee — não aparece no README (framing funcional confirmado, marca não); (2) string SPDX exata de phoenix — README não a expõe, RUN 0 registra NOASSERTION; (3) claims de multi-tenancy enterprise (SOC2/RBAC) de opik — não no README; (4) discrepâncias de licença L0 (karpathy=MIT no README vs RUN0=NONE; base=MIT no README vs RUN0=none) — resolvidas a favor do README com baixa confiança de provenance.
