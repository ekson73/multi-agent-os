# Agentic MoE 2026 — RELATÓRIO FINAL (Síntese das Fases 0–3)

> **🔁 Reframe — MAOS Hub (ADR-006, Accepted 2026-06-29):** o hub **"ATH"** projetado nesta série foi
> ratificado e realizado como o **MAOS Hub** — a gating-network MoE **nativa** do MAOS (evolução do
> `maos-mcp-hub`, não um produto novo). **ATH ⊂ agentic-moe-2026 ⊂ MAOS.** Este arquivo é preservado
> como registro histórico datado (2026-06-27); status vivo do hands-on: `README.md` §"Status do hands-on".


> **Fase:** 4 — Final Report (SÍNTESE; sem nova pesquisa web — funde + reconcilia os arquivos existentes).
> **Observado:** 2026-06-27 (toda observação de estrela é datada deste dia; valores = ordem-de-magnitude, não precisão).
> **Nota de idioma:** prosa em **pt-BR**; identificadores, comandos, nomes de repositório, fórmulas e tags de mecanismo em **en-US**.
> **Funde:** `20260627-00-canonicalization.md` + `20260627-01a-substrates.md` + `01b-knowledge.md` + `01c-pipeline.md` + `01d-amplifier.md` + `20260627-02-ntree-moe.md` + `20260627-03-orchestrator-hub.md`.
> **Disciplina epistêmica:** flags `[UNVERIFIED]` / `[sec]` herdadas dos upstreams são **preservadas**, não apagadas. Estrelas extraordinárias são reportadas como valor de API datado, **sem editorializar**, com aviso de magnitude.

---

## 1. SUMÁRIO EXECUTIVO (pt-BR, ~1 página)

**Tese central.** O ecossistema agentic/AI-native de engenharia de software em 2026 **não é vencido por uma única ferramenta**. Ele é uma **STACK COMPONÍVEL DE CAMADAS FUNCIONAIS AGRUPADAS POR PAPEL** (substratos · conhecimento · pipeline · amplificador), roteada como um **Mixture-of-Experts (MoE)**: um *gating network* simbólico-estratificado recebe o intent do operador e decide **quais experts ativar e em que ordem**. O que muda a economia da escolha é que **três substratos ficam sempre ligados** ("always-on"), envelopando densamente toda rota como um *residual* somado: **L0 guardrails + L8 memory + L9 observability**. Sobre esse colchão, a pipeline (L1 spec → L2 workflow → L6 design → L7 slides) e o conhecimento (L4 codebase / L5 PKM) recebem **top-1 esparso por slot** — porque dois specs, dois injetores de instrução ou dois studios **não convergem** no mesmo repo. O L3 (amplifier) é um gating de segundo nível, **opcional e caro**, que só dispara em alta ambiguidade/paralelização.

**Achados de SEGURANÇA (headline) — o que mudou o set INCLUDED.** O gate de supply-chain do RUN 0 **alterou o conjunto** com três achados decisivos:
1. **GSD `$GSD` rug-pull → EXCLUDED (confirmado).** `gsd-build/get-shit-done` (original, ~63K★): token Solana `$GSD`, saque de liquidez (~US$500K), fundador "TÂCHES" deletou contas ~2026-04. **A ameaça é viva:** os pacotes npm ORIGINAIS seguem publicados sob chaves do golpista; um update malicioso comprometeria máquinas locais (GSD pede permissões `shell/bash` profundas). Sucessor seguro auditado: **`open-gsd/gsd-core`** (sem backdoors no fork; risco está nos pacotes originais).
2. **MemPalace → EXCLUDED/FLAGGED em alegações SECUNDÁRIAS NÃO PROVADAS.** Alegações (não-auditadas) de compra de ~42K★ em repo de ~2 meses, "wrapper de ChromaDB" sob nome de celebridade (`milla-jovovich/mempalace`) e benchmark "96.6% LongMemEval" não-reproduzível. **Não se afirma fraude como fato** — pelo gate, sai do INCLUDED até auditoria independente. Substituído por **mem0** (benchmark `memory-benchmarks` reproduzível) como default de memória.
3. **Contexto de vulnerabilidade de skills.** O ambiente de pacotes agent-skill carrega risco material: relatos do período apontam **~13% de pacotes agent-skill com vulnerabilidades críticas** `[UNVERIFIED — re-verificar]`. Isso fundamenta tratar "velocidade de estrela" como **sinal, não prova** (vide MemPalace), e por que o HUB roda AgentShield em PreToolUse.

**Ressalva de MAGNITUDE de estrelas.** Vários counts são **extraordinários** para repos de 2025–2026 — rivalizam os maiores do GitHub (ECC ~188K, karpathy ~154–183K, superpowers ~147K, spec-kit ~106K, gstack ~101K). São reportados como **valor de API ao vivo datado (2026-06-27)**, fonte primária, **sem editorializar** — mas com **aviso de magnitude** para verificação humana. Não são precisão; são o melhor sinal verificável hoje.

**O HUB em 3–4 frases.** O Hub (`multi-agent-os`) é o **gating network**: um control plane *stateless* que roteia `intent → CTS scoring → ISO tool-gating → model-router`, sobre os substratos always-on, com **HITL** (human-in-the-loop) obrigatório em ações **irreversíveis** ou de **risco HIGH**. O *Intent Classification* usa o mapa simbólico barato do BMAD (fase do SDLC → persona) e sobe para lookup HNSW (padrão ruflo) só em ambiguidade. O *CTS* (Composite Tool Score) aplica **hard filters de segurança/licença primeiro** e depois pontua candidatos por ISO × Eisenhower × risk × scope × methodology × reversibility, importando o `trust_score` do ruflo verbatim. O *ISO tool-gating* mantém um pool permanente de summaries ≤60 tokens/tool e só promove o schema completo dos top-k — matando o "MCP/Tools Tax" e mantendo a janela abaixo de ~70% de utilização.

---

## 2. PANORAMA MERGED (Fases 0–3, condensado)

### 2.1 Veredito final por categoria (do arquivo 00)

| Veredito | Itens |
|---|---|
| **INCLUDED (26 experts)** | karpathy-claude-md⚠️ · base (cluster)⚠️ · mem0 · letta · cognee · langfuse⚠️ · graphify · understand-anything · obsidian-skills · spec-kit · openspec · gsd-core · superpowers · gstack · ECC · cli-anything · paul · carl · seed⚠️ · open-design · open-codesign · impeccable · slidev · frontend-slides · ruflo · bmad-method |
| **BRIDGE** | getzep/graphiti (L4↔L8) |
| **NEIGHBOR** | agentmemory · openllmetry · lmnr · opik · phoenix · agentic-flow · parruda/swarm · claude-squad |
| **BASELINE** | zep · obsidian app · claude-design/frontend-design · MetaGPT · LangGraph/AutoGen/CrewAI · claude-code |
| **LENS** | SpecDD (rótulo de metodologia SDD; coberto por spec-kit + openspec) |
| **EXCLUDED** | gsd-build/get-shit-done (🚩 $GSD rug-pull) · **MemPalace** (🚩 star-manip/claims não-provadas) · forrestchang/andrej-karpathy-skills (404/mis-attrib) · klaviyo/graphiti_mcp (fork) · goabstract/Awesome-Design-Tools (stale/non-agentic) |
| **INFRA (não-Target)** | BerriAI/litellm (model gateway, usado em Phase 3) |

> ⚠️ = flag de licença/segurança (ver §3). O span da árvore N-Tree é os **26 INCLUDED + BRIDGE graphiti = 27 nós**; NEIGHBOR/BASELINE entram só quando uma aresta os exige.

### 2.2 Landscape compacto por PAPEL (o "para que serve" de cada INCLUDED)

**SUBSTRATOS always-on (01a) — envelopam toda rota, não competem pela tarefa:**
- **L0 guardrails:** `karpathy-claude-md` — força deliberação antes de codar (Think-Before-Coding, Simplicity, Surgical-Changes, Goal-Driven). · `base` — anti-staleness do workspace (drift score, PSMM) via hooks.
- **L8 memory:** `mem0` (**DEFAULT**) — memória plugável universal, isolada por tenant, benchmark reproduzível. · `letta` — runtime de agente stateful com memória OS-tiered self-editing (lock-in: usar a memória = usar o agente). · `cognee` — memória graph-native + ontologia ("Company Brain"). · `graphiti` (**BRIDGE L4↔L8**) — grafo de contexto bi-temporal (fatos com janela de validade; invalida em vez de deletar).
- **L9 observability:** `langfuse` (**DEFAULT**) — tracing + evals + prompt-mgmt + datasets, OTel-native.

**CONHECIMENTO (01b) — consultado antes de especificar:**
- **L4 codebase:** `graphify` — indexa o repo 1× → grafo queryable (token-efficiency ~71x); exporta Obsidian Vault (ponte L4→L5). · `understand-anything` — grafo interativo/educativo ("graphs that teach"); onboarding + exploração visual.
- **L5 PKM:** `obsidian-skills` — 5 skills oficiais do Obsidian (kepano) que ensinam o agente a operar vaults (wikilinks, Bases, Canvas).

**PIPELINE (01c) — esteira ordenada L1→L2→L6→L7:**
- **L1 spec:** `spec-kit` — SDD canônico/template-rich da GitHub (constitution→specify→plan→tasks→implement; compliance-ready). · `openspec` — SDD leve/brownfield-first/iterativo (change-folders). · `gsd-core` — SDD anti-context-rot via subagentes de contexto-fresco (fork SEGURO).
- **L2 workflow:** `superpowers` — metodologia SDLC via skills (TDD obrigatório; menor footprint do trio). · `gstack` — "virtual eng team" de 23 personas (Garry Tan; reescreve CLAUDE.md). · `ECC` — harness operator system maximalista (232 skills + instincts + hooks + AgentShield). · `cli-anything` — gera CLIs agent-native a partir do código-fonte ("making ALL software agent-native"). · `paul`/`carl`/`seed` (cluster Kahler) — Plan-Apply-Unify in-session / injeção JIT de regras por hook / incubadora de ideação tipada.
- **L6 design:** `open-design` — studio local-first multi-surface (amplo; bypassPermissions). · `open-codesign` — studio desktop enxuto (loop permissionado, mais seguro). · `impeccable` — LAYER de qualidade de design key-free (41 regras determinísticas; não é studio).
- **L7 slides:** `slidev` — framework slides-as-code maduro (2021, human-first, não agent-native). · `frontend-slides` — skill agêntico de slides (Claude Code; anti-slop).

**AMPLIFICADOR (01d) — L3 opcional, meta-routing:**
- `ruflo` — meta-harness/swarm runtime (Queen→topology + MoE+HNSW dispatch; 314 MCP tools; learning loop; **exige L8+L9**). · `bmad-method` — metodologia ágil persona-driven (gating simbólico fase→persona; "Party Mode"; sem L8 nativo).

### 2.3 SPINE de roteamento N-Tree + top-5 incompatibilidades (do arquivo 02)

**Spine (uma frase):** `substrate-check (L0 guardrails + L8 memory recall + L9 trace-on) → KNOWLEDGE (L4 grafo de codebase / L5 PKM) → L1 spec → L2 workflow (TDD/worktree) → L6 design → L7 slides`, com **L3 como amplificador opcional** que envolve L1–L7 quando a tarefa exige swarm/persona-handoff.

**Top-5 incompatibilidades (arestas negativas — NÃO compor):**
1. **spec-kit ✗ openspec** (L1) — modelos de spec **mutuamente exclusivos**; dois diretórios + duas convenções no mesmo repo não convergem.
2. **superpowers ✗ gstack ✗ ECC** (L2) — colisão de instrução always-on; três workflows "mandatory" = precedência imprevisível + erosão de contexto (ECC: 200k→~70k). Escolher **um**.
3. **base ✗ ECC** (L0) — dois gerenciadores de CLAUDE.md → hooks em duplicata (o próprio `/base:audit-claude` detecta o sprawl).
4. **mem0 ✗ letta ✗ cognee** (L8) — backends concorrentes; **letta = lock-in de runtime** ("must use Letta"); colisão de embeddings se compartilham pgvector sem namespacing.
5. **open-design ✗ open-codesign** (L6) — mesma vaga **e** postura de segurança incompatível (bypassPermissions total vs loop permissionado). *(Bônus: paul ✗ gsd-core — filosofia oposta in-session vs subagentes; gstack bane `mcp__claude-in-chrome__*` que ECC empacota; carl ✗ ECC — dois hook-engines per-prompt.)*

### 2.4 Arquitetura do HUB em ~8 bullets (essência (a)–(m) do arquivo 03)

- **(a) Control plane stateless de 5 estágios:** `Intent Classification → CTS Scoring → Tool-Gating/Lazy-Schema → Model Router → Tool Registry`, com substratos cross-cutting todos. Reusa o gating de fase **BMAD** como classificador barato; sobe para **HNSW (ruflo)** em ambiguidade.
- **(b) ISO tool-gating (Tool-Attention):** pool permanente de summaries ≤60 tok/tool; promove schema completo só dos top-k via *gated attention* (sparse top-k softmax). Padrão **NanoClaw hot-load** / lazy-schema. Mata o "Tools Tax" (`60·N + k·|schema|` vs `Σ|schema|`); mantém utilização <70%.
- **(c) CTS (Composite Tool Score):** **hard filters de segurança/licença PRIMEIRO** (HF1 EXCLUDED/FLAGGED, HF2 license none/NOASSERTION em redistribuição comercial, HF3 escala de privilégio, HF4 incompatibilidade de camada, HF5/HF6 risk=HIGH/irreversível → HOLD), depois soma ponderada. Importa o **`trust_score` do ruflo verbatim** (`0.4·success + 0.2·uptime + 0.2·threat + 0.2·integrity`).
- **(d) Tool Registry YAML (SSOT):** cada nó do grafo 02 = um registro com `layer, role, summary≤60tok, preconditions, risk_tier, authorization, harness_coverage, security_status, mechanisms[]`. Alimenta (b)–(c).
- **(e) Memory substrate (L8):** memória de roteamento tiered (working→session→operator→episodic→temporal) em **mem0** + **graphiti** (temporal). Consolidação = **Learning-Loop do ruflo** (RETRIEVE→JUDGE→DISTILL→CONSOLIDATE) — rotas frequentes viram fast-paths.
- **(f)+(h) Observability + gates (L9):** todo route emite spans OTLP para **langfuse**; LLM-as-judge realimenta a cadeia **warn→correct→block**. L0 sempre primeiro (PreToolUse); HITL obrigatório em risk=HIGH/irreversível/escolha mutuamente-exclusiva de alto impacto.
- **(g) Model Router (Switchcraft-style):** modelo capaz **mais barato** por tool-call via **LiteLLM (INFRA)** + budgets por categoria; downgrade ou HITL se estourar.
- **(i)+(m) Security model + pragmatism filter:** **AgentShield (ECC)** como scanner L0 de supply-chain (block `--no-verify`, secrets, exfil de CLAUDE.md); **tool-output tainting** de 3 estados (trusted/untrusted/derived — taint não escala privilégio); sandbox+egress por tool. **Rejeitados explicitamente:** blockchain audit (graphiti já dá trilha), quantum-routing, swarms auto-replicantes, "L10 gateway layer" (LiteLLM/MCP são INFRA, não camada de experts), gating neural denso (este é simbólico+estratificado).

---

## 3. RECONCILIAÇÃO DE ESTRELAS & LICENÇAS (com datas)

> Todas as observações são de **2026-06-27**. "kit v5" = valor citado no prompt-objeto v5. "RUN0 API" = valor da API ao vivo do RUN 0 (sem tag) ou `[sec]` (secundário, API vazia). "Phase-1 page-obs" = contagem da página de repositório observada no arquivo 01a–d. **Valor canônico adotado** = o que o HUB usa, com nota de reconciliação.

| expert | kit v5 (citado) | RUN0 API 2026-06-27 | Phase-1 page-obs 2026-06-27 | valor canônico adotado + nota |
|---|---:|---:|---:|---|
| karpathy-claude-md | ~183K | 154,186 | **183k** (01a) | **~154–183K** · divergência grande: API 154K vs página 183K; reportar faixa, ⚠️ magnitude extraordinária |
| base | — | 87 | 86 (01a) | **~86–87** · cluster <1K, estável |
| mem0 | — | ~57–59K `[sec]` | 58.2k (01a) | **~58K** · `[sec]` no RUN0 (API vazia); página corrobora |
| letta | — | 22,891 | 23.5k (01a) | **~23K** · crescimento normal API→página |
| cognee | — | 17,453 | **23.3k** (01a) | **~17–23K** · divergência: API 17.4K vs página 23.3K; reportar faixa |
| graphiti (BRIDGE) | ~26K | 26,380 | 27.8k (01a) | **~27K** · consistente |
| langfuse | — | 28,219 | 27.2k (01a) | **~28K** · consistente |
| graphify | ~73K | 52,657 | ~56–69k `[sec]` (01b) | **~52–57K** · v5 73K [SUPERSEDED]; adoto API 52.7K, faixa secundária acima |
| understand-anything | ~68K | ~55–66K `[sec]` | 64.9k `[sec]` (01b) | **~55–65K** · `[sec]`; migrou Lum1104→Egonex-AI |
| obsidian-skills | ~36K | 33,438 | 35k (01b, CONFIRMADO) | **~35K** · página confirmou "35k stars" |
| spec-kit | ~90–97K | **106,332** | dinâmico (01c) | **~106K** · ↑ vs v5; ⚠️ magnitude (GitHub-owned, crescimento rápido) |
| openspec | ~56K | 51,175 | dinâmico (01c) | **~51K** · ↓ vs v5 |
| gsd-core | — | ~4.2K `[sec]` | — | **~4.2K** · `[sec]`; fork SEGURO (original tinha 65K+) |
| superpowers | ~240K | **~147K** `[sec]` | dinâmico (01c) | **~147K** `[sec]` · ↓↓ vs v5 240K; ⚠️ magnitude + `[sec]` |
| gstack | ~117K | 101,289 | dinâmico (01c) | **~101K** · ↓ vs v5; ⚠️ magnitude |
| ECC | ~163K (abr) | **187,680** `[sec]` | README diz "182K+"; busca live 222K+ (01c) | **~188K** `[sec]` · maior divergência do conjunto; ver nota abaixo; ⚠️ magnitude extrema |
| cli-anything | ~42–44K | ~42–44K `[sec]` | 40K em 2026-05-24 (01c) | **~42–44K** `[sec]` |
| paul | — | 976 | 976 (01c, API exato) | **976** · cluster, API autoritativa |
| carl | — | 353 | 353 (01c, API exato) | **353** · cluster |
| seed | — | 288 | 288 (01c, API exato) | **288** · cluster |
| open-design | ~70K | 48,662 | só badge (01c) | **~49K** · ↓ vs v5; ⚠️ version-drift (19/71 do brief SUPERSEDED) |
| open-codesign | — | 6,993 | só badge (01c) | **~7K** |
| impeccable | — | 30,054 | só badge (01c) | **~30K** |
| slidev | — | 47,037 | só badge (01c) | **~47K** · ©2021 antfu |
| frontend-slides | — | 19,093 | — | **~19K** |
| ruflo | ~38–62K | 54,569 | ~61.7k (01d) | **~54–62K** · v5 amplo; API 54.6K, página 61.7K; reportar faixa |
| bmad-method | ~43K | 47,753 | ~49.6k (01d) | **~48–50K** · ↑ vs v5 |

> **A maior divergência de estrela reconciliada: ECC.** Três fontes contraditórias num único dia — **RUN0 API ~188K `[sec]`**, **README hardcoda "182K+"** (prosa de marketing), **busca live dá 222K+**. Adoto **~188K `[sec]`** (valor de API do RUN0) como canônico, marco `[UNVERIFIED]` para o dígito exato, e sinalizo magnitude extrema. *(Runner-up: superpowers v5 240K → API ~147K `[sec]`, queda de ~93K.)*

### 3.1 Sub-tabela de correções de LICENÇA (gate "state license")

| expert | licença citada (v5/page) | realidade verificada 2026-06-27 | ação |
|---|---|---|---|
| karpathy-claude-md / base | MIT (README/prosa) | **none** — README diz MIT mas **sem arquivo LICENSE** → all-rights-reserved por default | flag OSS-posture; HF2 bloqueia redistribuição comercial; manter como baseline |
| **BMAD-METHOD** | NOASSERTION (RUN0) | **MIT (CONFIRMADO)** — leitura direta do LICENSE: "MIT License, Copyright (c) 2025 BMad Code, LLC". O NOASSERTION do RUN0 era **artefato de parsing SPDX do GitHub** (trademark rider BMad™ + MIT) | **corrigido para MIT**; trademark separado cobre "BMad™" |
| langfuse | MIT (page) | **NOASSERTION / source-available** — MIT-core **exceto pastas `ee/`** (Enterprise Edition proprietárias) | flag: único default não-Apache-puro; se OSS-puro, usar só core ou trocar por openllmetry+opik |
| phoenix (NEIGHBOR) | OSS | **NOASSERTION / source-available** — string SPDX não confirmável do README `[UNVERIFIED]` | flag cautela; fora do span INCLUDED |
| CLI-Anything | Apache-2.0 `[confirm]` | **Apache-2.0 (CONFIRMADO)** — arquivo LICENSE completo lido; "Copyright [2026] [HKUDS CLI-Anything Team]"; grant de patente | confirmado; era load-bearing; redistribuição comercial OK |
| seed / base | MIT (prosa) | **license=null na API** — LICENSE ausente/vazio; claim MIT só na prosa | maior risco legal do cluster; HF2; não redistribuir sem clareza |
| litellm (INFRA) | MIT | **NOASSERTION** — cláusula custom | flag infra; usado em Phase 3, não-Target |

> **Flags `[sec]`/`[UNVERIFIED]` herdadas (todas preservadas):** estrelas via secundário (API vazia) em mem0, superpowers, understand-anything, cli-anything, gsd-core, lmnr, parruda/swarm; dígitos exatos de ECC; string SPDX de phoenix; acrônimo "ECL/control-plane" de cognee; `od mcp install` de open-design; webhooks de ruflo; benchmarks self-reported de ruflo ("89% routing accuracy", AgentDB speedup, "1.953× faster than LangGraph").

---

## 4. CHEAT-SHEET DE ROTEAMENTO ("qual expert, quando")

> Eixo: **quadrante de Eisenhower × risco × escopo → stack recomendado + nota HITL.** Regra de ouro: **substrate-first SEMPRE** (L0 karpathy/base + L8 mem0/graphiti + L9 langfuse) antes de qualquer pipeline. `**|**` = escolha mutuamente-exclusiva resolvida pelo CTS/HITL.

| Quadrante | Cenário (risco · escopo) | Stack recomendado (substrate-first → pipeline) | Nota HITL |
|---|---|---|---|
| **Q1** urgente+importante | Incidente em prod, risco HIGH, escopo repo/org | L0 base(drift)+karpathy · L8 mem0 · L9 langfuse(evals) → graphify(L4 blast-radius) → **gsd-core** **\|** gstack(`/ship`,`/cso` OWASP+STRIDE) → impeccable(linter CI) | **HITL obrigatório** (risk=HIGH): aprovação de PR + canary; ⚠️ gsd-core = SÓ o fork `open-gsd` (HF1); taint-check em qualquer fonte externa |
| **Q1** urgente+importante | Hotfix pontual, risco MED, escopo file/module | L0 karpathy · L8 mem0 · L9 langfuse → **openspec**(brownfield leve) → **superpowers**(TDD+worktree, menor footprint) | HITL no code-review com severidade ("Critical issues block progress"); pular L3 (over-kill) |
| **Q2** importante, não-urgente | Greenfield/feature nova, risco LOW-MED, escopo module→repo | L0 karpathy · L8 mem0 · L9 langfuse → seed(ideação) → **spec-kit** **\|** openspec(L1) → superpowers(L2 TDD) → open-codesign(L6 enxuto+seguro) → frontend-slides(L7 pitch) | HITL na **escolha spec-kit↔openspec** (HF4 mutuamente exclusivos) + aprovação do plano (clarify) |
| **Q2** importante, não-urgente | Refactor de legado, risco MED, escopo module | L0 karpathy+base · L8 **cognee**(graph) · L9 langfuse → understand-anything(L4 onboarding) → graphify(L4 contexto) → **openspec**(brownfield) → superpowers(worktree+review) | HITL no code-review; ⚠️ não commitar grafo com segredos extraídos; CTS escolhe openspec (0.779>0.590 vs spec-kit) |
| **Q2** importante, não-urgente | Feature enterprise/compliance, risco MED-HIGH, escopo org | L0 karpathy · L8 **graphiti**(temporal/auditoria) · L9 langfuse(HIPAA) → graphify(L4) → **spec-kit**(constitution+compliance) → gstack **\|** superpowers → open-design(L6) → slidev(L7) | HITL nos gates de compliance (`/speckit.analyze`, `/cso`); **não empilhar gstack+ECC** (HF4) |
| **Q3** urgente, não-importante | Slides/design rápido, risco LOW, escopo file | L0 karpathy · L8 mem0 · L9 langfuse → **open-codesign** **\|** open-design(L6) → **frontend-slides** **\|** slidev(L7) | HITL baixo/opcional; se open-design: sandbox reforçado (bypassPermissions é risk=HIGH) |
| **Q3** urgente, não-importante | Onboarding de codebase, risco LOW (read-mostly), escopo repo | L0 karpathy · L8 cognee · L9 langfuse → understand-anything(L4 dashboard+tour) → graphify(L4 export Obsidian) → obsidian-skills(L5 vault) | Risco baixo (read-mostly); HITL opcional na revisão do domínio extraído |
| **Q3 / sessão longa** | Sessão longa com memória cross-session, risco MED, escopo repo | L0 karpathy · L8 **letta**(self-edit) **\|** mem0+graphiti · L9 langfuse → ECC **\|** gsd-core(L1/L2 STATE persistente) → **ruflo**(L3 learning-loop, opcional) | ⚠️ letta = **lock-in de runtime**; ruflo = **over-kill** se solo/budget-limitado (27 hooks+daemon); HITL na decisão letta-vs-mem0 |
| **Q4** nem-nem | Experimento/PoC descartável, risco LOW, escopo file | L0 karpathy (só) · L8 mem0(efêmero) · L9 langfuse(opcional) → cli-anything **\|** superpowers leve | **Pular L3 inteiramente** (amplifier overkill em CI efêmero/PoC); sem HITL; não persistir aprendizado |

> Cobertura confirmada: **Q1, Q2, Q3, Q4** todos presentes. Inclui as linhas-exemplo pedidas (Q1 incidente prod HIGH-risk; Q2 greenfield; Q2 legacy refactor; Q3 slides/design quick-turn; sessão longa com memória).

---

## 5. LIMITAÇÕES & PRÓXIMOS PASSOS

**Nota epistêmica honesta.**
- **Estrelas datadas/divergentes/extraordinárias.** Todo count é de 2026-06-27 e é **ordem-de-magnitude, não precisão**. Vários divergem materialmente entre API/página/v5 (ECC 188K vs 222K vs "182K+"; superpowers 240K→147K; karpathy 154K↔183K; cognee 17.4K↔23.3K; graphify 52.7K↔69K). Counts extraordinários (ECC/karpathy/superpowers/spec-kit/gstack) são reportados sem editorializar mas sinalizados — repos rivalizando os maiores do GitHub em ~1 ano merecem ceticismo de magnitude.
- **Itens `[sec]` a re-verificar com token autenticado.** mem0, superpowers, understand-anything, cli-anything, gsd-core, lmnr, parruda/swarm tiveram estrelas via fonte **secundária** (API retornou corpo vazio). Re-tentar com retry/token autenticado para confirmar dígitos.
- **MemPalace: alegações NÃO PROVADAS.** A exclusão é por **gate de cautela**, não por fraude comprovada. As alegações de star-manip e benchmark não-auditável são **secundárias** — exigir auditoria independente antes de qualquer reinclusão.
- **Pesos de design da Fase 3 são PROPOSTAS.** Os valores numéricos default dos pesos CTS (`w_iso=0.30`, `w_trust=0.30`, `w_risk=0.50`…), os thresholds `θ_layer/θ_warn/θ_ok` e a contagem de tokens do pool ISO **não são medições** — são extrapolações de engenharia a calibrar empiricamente no plano de testes (k). Os benchmarks do ruflo herdados ("89% routing accuracy", "1.953× faster") são **self-reported, `[UNVERIFIED]`**.

**Próximos passos concretos (3–5):**
1. **Re-rodar a coleta de estrelas/licenças com token GitHub autenticado** — eliminar os `[sec]` (API vazia), confirmar dígitos de ECC/superpowers e resolver as divergências API↔página de cognee/karpathy/graphify/ruflo.
2. **Auditoria de supply-chain pendente** — verificar a alegação de **~13% de pacotes agent-skill com vulns críticas** `[UNVERIFIED]`; rodar AgentShield (102 rules) sobre os experts INCLUDED com canal de instrução pesado (ECC, gstack, carl, base) para mapear hooks/MCP-risk reais.
3. **Calibrar os pesos CTS e thresholds** empiricamente via a matriz 6×3 (6 task-families × {low,med,high} risk) do plano de testes (k); medir A/B com vs sem o ISO tool-gating (token cost + % context-fracture acima de 70%).
4. **Confirmar termos das licenças NOASSERTION** (langfuse `ee/`, phoenix SPDX, litellm cláusula custom) e os `license=null` (seed/base/karpathy) antes de qualquer redistribuição comercial.
5. **Implementar o Tool Registry YAML (SSOT)** para os 26 INCLUDED + graphiti (só 4 estão expandidos no arquivo 03) e o sketch do MCP server `maos-hub` (`hub.route`/`hub.score`/`hub.registry.get`/`hub.gate.approve`/`hub.trace`), revisando o MemPalace e re-validando os `[UNVERIFIED]` a cada TTL (revisão recomendada: 2026-09-27).

---

*Phase 4 · Final Report · funde 00 + 01a–d + 02 + 03 · 26 experts INCLUDED + BRIDGE graphiti · observado 2026-06-27. Prosa pt-BR, identificadores/fórmulas en-US. Sem nova pesquisa web — merge + reconciliação. Flags `[UNVERIFIED]`/`[sec]` preservadas. Estrelas = ordem-de-magnitude datada, não precisão.*
