# Research: Caveman Claude → response-compression

> **Sessão**: caveman  
> **Data**: 2026-04-10  
> **Autor**: Claude-Sonnet-4.6 + Claude-Opus-4.6 + Emilson Moraes  
> **Status**: Análise completa (v5 final) — pronto para implementação  
> **Iterações**: v1 (proposta externa) → v2 (contra-proposta) → v3 (pós-inventário) → v4 (harmonizada) → v5 (refinada com peer review)

---

## Índice

1. [Pesquisa primária: Caveman Claude](#1-pesquisa-primária-caveman-claude)
2. [Análise da proposta v1 (externa)](#2-análise-da-proposta-v1-externa)
3. [Contra-proposta v2 (pré-inventário)](#3-contra-proposta-v2-pré-inventário)
4. [Questão de naming (prefixo maos-)](#4-questão-de-naming-prefixo-maos-)
5. [Análise v3 (pós-inventário dos repos reais)](#5-análise-v3-pós-inventário-dos-repos-reais)
6. [Análise da proposta revisada (v1-R)](#6-análise-da-proposta-revisada-v1-r)
7. [Proposta final harmonizada (v4)](#7-proposta-final-harmonizada-v4)
8. [Peer review externo e refinamentos v5](#8-peer-review-externo-e-refinamentos-v5)

---

## 1. Pesquisa Primária: Caveman Claude

### 1.1 O que é

**Caveman** é um Claude Code skill/plugin criado por **Julius Brussee** (16 anos, holandês) que força o agente a comunicar em estilo "homem das cavernas" — frases fragmentadas, sem artigos, sem pleasantries, sem hedging — reduzindo tokens de output.

**Não é**: MCP server, API layer, ou modificação do modelo. É **um prompt empacotado** no formato `SKILL.md` da Anthropic, com hooks Node.js para tracking de modo.

- **GitHub**: https://github.com/JuliusBrussee/caveman
- **License**: MIT
- **Stars**: 9.100+ (abril 2026)
- **SkillsLLM**: https://skillsllm.com/skill/caveman
- **Site**: https://juliusbrussee.github.io/caveman/ ("Lithic Token Compression")

### 1.2 Anatomia técnica real

| Componente | Caminho | Função |
|---|---|---|
| **SKILL.md** (source of truth) | `skills/caveman/SKILL.md` | Prompt principal — 6 níveis de intensidade |
| **plugin.json** | `.claude-plugin/plugin.json` | Manifest com 2 hooks: `SessionStart` + `UserPromptSubmit` |
| **marketplace.json** | `.claude-plugin/marketplace.json` | Metadata para marketplace |
| **Hooks JS** | `hooks/caveman-activate.js`, `hooks/caveman-mode-tracker.js` | Node.js scripts (5s timeout) |
| **Evals** | `evals/measure.py` | Harness de 3 braços (normal vs caveman vs terse genérico) |
| **caveman-compress** | `caveman-compress/` | Ferramenta de compressão de memória/CLAUDE.md (~45% input) |
| **Sync CI** | `.github/` | CI replica `SKILL.md` para `.cursor/`, `plugins/`, `caveman/` |

### 1.3 O prompt real (SKILL.md verbatim core)

```
Respond terse like smart caveman. All technical substance stay. Only fluff die.
Default: full. Switch: /caveman lite|full|ultra.

Rules:
Drop: articles (a/an/the), filler (just/really/basically/actually/simply),
pleasantries (sure/certainly/of course/happy to), hedging.
Fragments OK. Short synonyms. Technical terms exact.
Code blocks unchanged. Errors quoted exact.
Pattern: [thing] [action] [reason]. [next step].
```

### 1.4 Seis níveis de intensidade

| Nível | Descrição | Exemplo ("Why React re-render?") |
|---|---|---|
| **lite** | Sem filler, mantém artigos + frases completas | "Your component re-renders because you create a new object reference each render." |
| **full** (default) | Drop artigos, fragmentos OK | "New object ref each render. Inline object prop = new ref = re-render." |
| **ultra** | Abreviações (DB/auth/fn/impl), setas (→) | "Inline obj prop → new ref → re-render. `useMemo`." |
| **wenyan-lite** | Semi-clássico chinês | "組件頻重繪，以每繪新生對象參照故。" |
| **wenyan-full** | 文言文 completo, 80-90% redução | "物出新參照，致重繪。useMemo。" |
| **wenyan-ultra** | Compressão extrema chinês | "新參照→重繪。useMemo Wrap。" |

### 1.5 Auto-Clarity guardrail

O skill **desliga automaticamente** para:
- Security warnings
- Confirmações de ações irreversíveis
- Sequências multi-step onde fragmentos geram ambiguidade
- Quando o usuário parece confuso

### 1.6 Performance: claims vs. realidade

| Métrica | Claim oficial | Realidade sessão completa |
|---|---|---|
| Redução output tokens | 65% média (range 22-87%) | **confirmado** |
| Custo total da sessão | "75% de tokens" | **4-10%** (input domina o custo) |
| React re-render | 87% (1180→159 tokens) | confirmado para output only |
| caveman-compress (input) | ~45% em arquivos de memória | mais impactante que output |

**Gap central**: marketing diz "75% token reduction" sem qualificar "de output apenas". Em workflows agentic com muitos tool calls, input/context/thinking dominam o custo.

### 1.7 Paper acadêmico de suporte

**"Brevity Constraints Reverse Performance Hierarchies in Language Models"**  
arXiv 2604.00025 | Março 2026 | MD Azizul Hakim

- 31 modelos (0.5B–405B params), 1.485 problemas, 5 benchmarks
- Em 7.7% dos problemas, modelos grandes performam **pior** que pequenos (até 28.4pp)
- Causa: "spontaneous scale-dependent verbosity" — overelaboration gera erros
- Brevity constraints melhoram accuracy em **26pp** e reduzem gaps por **2/3**

**Caveat**: valida que brevity pode melhorar accuracy; não valida o caveman skill especificamente.

### 1.8 Evals do projeto

Harness de 3 braços: Normal Claude vs. Caveman Claude vs. Terse genérico (controle).
Run: `uv run --with tiktoken python evals/measure.py`

Mede token count. Não mede: follow-up turns gerados por ambiguidade, custo total, satisfação, erros induzidos.

### 1.9 Críticas e gaps (síntese)

| Problema | Impacto |
|---|---|
| Foco em output quando custo real é input | Savings reais de 4-10%, não 75% |
| Skill consome tokens para existir | Em sessões curtas pode anular savings |
| "Mesma accuracy técnica" não comprovado | Evals medem tokens, não task success |
| Distribution shift risk | Caveman speech fora do training distribution |
| Follow-up cost inversion | Respostas muito curtas geram N follow-ups |
| Marketing infla os números | Autor admitiu no HN: "~75% needs benchmarking rigor" |

### 1.10 Quando usar / não usar

**USE caveman**
- Code review interno (senior→senior)
- Triagem de logs/erros
- Resumo de função/método
- Respostas de yes/no com justificativa
- CI/CD pipeline feedback (máquina lendo)

**NÃO USE caveman**
- Docs user-facing
- Ensino/onboarding (follow-ups custam mais)
- Domínio sensível (legal, médico, security)
- Primeiro contato com codebase
- Tasks onde accuracy > velocidade

### 1.11 Alternativas nativas do Claude Code

| Estratégia | Escopo | Redução estimada |
|---|---|---|
| `/compact` proativo | Context reset | Alta |
| `/clear` entre tasks | Input | Alta |
| Mover instruções para Skills (on-demand) | Input | Média |
| Model routing (Haiku para tasks simples) | Global | Custo/token |
| Hooks de pré-processamento | Input | Alta |
| Subagents para ops verbosas | Output isolado | Alta |
| `/effort` para reduzir thinking | Thinking tokens | Alta |
| Prompt caching (automático) | Input repetido | Automático |

---

## 2. Análise da Proposta v1 (Externa)

> Proposta recebida: forkar o caveman e integrá-lo ao multi-agent-os como plugin `multi-agent-os-lithic`, com compression profiles + execution autonomy como dois pilares.

### 2.1 O que a proposta v1 acertou

| Ponto | Avaliação |
|---|---|
| Fork + crédito MIT | Correto. MIT permite reutilização com preservação de copyright. |
| Renomear de "caveman" | Correto. "Caveman" é meme, não taxonomia. |
| Separar compressão de autonomia | Conceitualmente correto (dimensões ortogonais). |
| Usar hierarquia nativa de escopos Claude Code | Correto. |
| Alerta sobre `unattended` precisar de governance | Correto e importante. |
| Mover autonomia para permissions/hooks/settings | Correto. |

### 2.2 Os 5 erros arquiteturais da proposta v1

#### Erro 1 — Coupling de dois domínios ortogonais em um plugin

`compressionProfile` + `executionAutonomy` no mesmo plugin. Mas:

| Dimensão | Compressão | Autonomia |
|---|---|---|
| Risco | Baixo (style) | Alto (operações irreversíveis) |
| Stakeholder | Dev individual | Plataforma/admin |
| Frequência de mudança | Alta (por task/agente) | Baixa (por política) |
| Proprietário | Skill/prompt | Permissões/hooks |

#### Erro 2 — Reinvenção do Sentinel

O `sentinel/config.json` já tem:
```json
"enforcement_modes": {
  "soft":     "Log violations, suggest corrections",
  "moderate": "Require acknowledgment for HIGH",
  "strict":   "Block all violations"
}
```

`supervised | autonomous | unattended` = aliases para `strict | moderate | soft`. Era duplicação.

#### Erro 3 — "lithic" naming toma emprestado a marca do Julius

O site do Julius se chama "Lithic Token Compression". Nomear `multi-agent-os-lithic` criaria confusão de marca.

#### Erro 4 — Ausência da dimensão de input tokens

A proposta focava 90% em output compression. Mas o custo real em agentic workflows é input/context/thinking. O `context-prep` já tinha minimização — integração ignorada.

#### Erro 5 — Ausência de role-based compression matrix

A proposta usava modelo onde o **usuário escolhe** o perfil. Em multi-agent orchestration, a compressão ideal é determinada pelo **papel do agente**, não preferência do usuário.

---

## 3. Contra-Proposta v2 (Pré-Inventário)

### 3.1 O que eu propus

- Dois skills separados (`response-compression` + sem autonomia)
- Integrar `context-compressor` com `context-prep`
- Extensão do Sentinel ao invés de novo sistema
- Alt B (reimplementação com atribuição) para o skill

### 3.2 O que estava correto

- Não duplicar Sentinel
- Naming descritivo sem marca emprestada
- context-compressor integrado com context-prep
- Alt B para o skill

### 3.3 O que estava incompleto

- Não considerou o GaaS como princípio fundante
- Tratou o problema como prompt engineering apenas (probabilístico)
- Não propôs hook determinístico
- Não verificou o código real antes de propor

---

## 4. Questão de Naming (prefixo maos-)

### Pergunta
> "Assim como `maos-mcp-hub` (plugin de MCP dentro do multi-agent-os) recebe o prefixo do projeto [maos=multi-agent-os], penso que alguns artefatos internos também possam seguir esse padrão. Sim ou não?"

### Resposta: Não — com regra formal

O `maos-mcp-hub` tem prefixo porque é um **componente standalone com identidade própria no namespace global** — registrado como MCP server externo, pode ser instalado independentemente, compete com outros servidores no mesmo espaço de nomes.

Skills, commands e agents vivem **dentro** do plugin. Já estão namespaciados pelo plugin `maos` por definição.

**Evidência factual (100% dos artefatos internos):**

| Artefato | Nome atual | Tem prefixo? |
|---|---|---|
| MCP tool (externo) | `maos-mcp-hub` | sim |
| Skill (14 existentes) | `agent-select`, `context-prep`, `anti-conflict`, `ttl-policy`, `find-docs`, etc. | **não** |
| Command (6 existentes) | `sync`, `audit`, `status`, `worktree`, `delegate`, `mvv` | **não** |
| Agent (14+ existentes) | `orchestrator`, `sentinel-monitor`, `qa-validator`, `forge`, etc. | **não** |

**Regra formal derivada:**

> `maos-` prefix → componentes com identidade standalone ou visibilidade externa  
> sem prefix → artefatos internos ao plugin, já namespaciados por escopo

**Exceção legítima**: se um skill for extraído e publicado como produto independente, aí faz sentido publicar como `maos-response-compression`. O arquivo interno continua `response-compression`.

---

## 5. Análise v3 (Pós-Inventário dos Repos Reais)

### 5.1 Inventário dos repositórios

#### multi-agent-os v1.5.0 — estrutura real

```
├── Governance (GaaS)
│   ├── .githooks/          ← Motor 1: hooks locais determinísticos
│   ├── hooks/hooks.json    ← Motor 2: lifecycle hooks (SessionStart, PreToolUse, PostToolUse, Stop)
│   ├── sentinel/           ← RULE-009 Token Bloat já existe (severity LOW, auto_block false)
│   ├── rules/              ← auto-loaded (core-directive, axial-principles, agent-scm, etc.)
│   └── plugin-scripts/governance/ ← worktree-gate.sh, auto-name-session.sh
│
├── Skills (14 existentes, sem prefixo maos-)
│   ├── Delegation: agent-select, context-prep (já tem Context Minimization Step 3)
│   ├── Governance: hierarchical-merge, worktree-policy, anti-conflict, ttl-policy
│   ├── Observability: audit, status-map
│   ├── Developer: find-docs, sync-to-git
│   └── Meta: skill-writer, ontological-analysis, mvv-synthesis
│
├── Commands (6): sync, audit, status, worktree, delegate, mvv
│   └── Padrão: todos são AÇÕES, nenhum é setter de configuração
│
├── Agents (14+ consultants)
│   ├── Core: orchestrator, sentinel-monitor, qa-validator, consolidator, forge
│   ├── Specialist: governance-auditor, naming-organizer, data-validator, validation-auditor
│   ├── Domain: code-reviewer, debugger, data-analyst, legacy-archaeologist, memory-curator
│   ├── DevOps: gitops-engineer, SCM (agent-scm.md em rules/)
│   └── Consultants: 12+ personas (Elon, Gates, Linus, etc.)
│
└── mcp-tools/maos-mcp-hub/  ← ÚNICO componente COM prefixo (standalone externo, 6 gateways, 96 actions)
```

#### eko-claude-plugins

```
└── plugins/multi-agent-os  ← marketplace pessoal com 1 plugin, submodule
```

### 5.2 As três descobertas que mudam o frame

#### Descoberta 1 — GaaS é o princípio fundante

Do `docs/gaas-architecture-manifesto.md`:

```
Instrucoes Markdown = sugestoes probabilísticas (o LLM pode ignorar)
Exit code + stderr  = fatos determinísticos (o LLM nao pode contornar)
```

Os 3 Motores do GaaS:
1. **Motor 1**: Git hooks locais (pre-commit, pre-push) — ação imediata
2. **Motor 2**: CI/CD pipeline (bots reviewers, governance validation) — ação remota
3. **Motor 3**: Policy-as-Code (OPA/Rego) — planejado

**Implicação**: um skill de compressão é **probabilístico** — o LLM lê e pode ignorar. Para ser coerente com o DNA do projeto, compressão efetiva precisa de uma camada **determinística** (hook). Ambas as propostas anteriores (v1 e v2) resolviam o problema como prompt engineering apenas.

#### Descoberta 2 — Forge + Goldilocks é o processo de criação

Do `agents/forge.md`:

```
ESPECÍFICO o suficiente para caber em escopo atômico (papel reconhecível)
GENÉRICO o suficiente para ser REUTILIZADO em qualquer tarefa desse escopo
```

E do `rules/axial-principles.md`:

> "Aja como um cirurgião: alta precisão técnica aliada a clareza zen sobre o que realmente importa."

Qualquer novo artefato deve ser **atômico** (role profissional) E **reutilizável** (não task-specific).

#### Descoberta 3 — context-prep já tem Context Minimization

O `skills/context-prep/SKILL.md` já contém Step 3 com 5 regras de minimização:

```
1. Include ONLY files mentioned in task
2. If file > 500 lines, extract relevant sections only
3. Summarize history instead of full transcripts
4. Use references for stable docs
5. Remove internal notes not relevant to sub-agent's task
```

O problema de compressão de input **já está parcialmente resolvido**. Não precisa de novo artefato — precisa de extensão com uma 6ª regra.

### 5.3 Proposta v3 original

| Dimensão | v1 (externa) | v2 (minha, pré-inventário) | **v3 (pós-inventário)** |
|---|---|---|---|
| Alinhamento com GaaS | Não | Parcial | **Total** |
| Naming | lithic (marca Julius) | response-compression | **response-compression** |
| Novos plugins | 1 novo | 0 | **0** |
| Novos commands | 4 | 0 | **0** |
| Compressão output | skill | skill | **skill + hook GaaS** |
| Compressão input | mencionado | integrar context-prep | **extensão context-prep** |
| Autonomia | nova dimensão | extensão Sentinel | **extensão Sentinel config** |
| Artefatos novos | 1 plugin + 5 skills | 1 skill + 1 tool + 1 config | **1 skill + 1 hook + 2 extensões** |
| Goldilocks compliant | não avaliado | não avaliado | **sim** |

---

## 6. Análise da Proposta Revisada (v1-R)

> Após ver o inventário real, o proponente externo revisou sua posição. Esta seção analisa essa revisão.

### 6.1 Correções feitas (dos 5 erros originais)

| Erro original | Status na revisão |
|---|---|
| Plugin separado do MAOS | **Corrigido** — agora propõe feature interna |
| Naming "lithic" (marca Julius) | **Mantido** — ainda propõe `maos-lithic` |
| Autonomia como nova dimensão | **Parcialmente corrigido** — reconhece governança existente, mas cria `maos-autonomy` |
| Foco só em output tokens | **Não abordado** |
| Ausência de role-based matrix | **Corrigido** — propõe defaults por agente |

### 6.2 O que a revisão trouxe de novo e válido

**Role-based defaults combinados (compressão + autonomia por agente):**

```
orquestrador → lite + supervised
reviewer     → full + supervised
consolidator → full + supervised
subagentes   → ultra + autonomous
```

Isso melhora sobre a v3 original que tratava as duas dimensões separadamente. A combinação por agente é pragmaticamente mais útil para o orquestrador na hora de delegar. **Incorporado na v4.**

### 6.3 Os 4 pontos de divergência remanescentes

#### Divergência 1 — Prefixo `maos-` em artefatos internos

A revisão muda de posição e recomenda `maos-` para artefatos internos. Minha posição: **não**.

**Evidência**: 14 skills, 6 commands, 14+ agents — **zero** com prefixo `maos-`. O único componente com prefixo é o MCP hub (standalone externo). Criar `maos-lithic`, `maos-autonomy`, `maos-profile` quebraria o padrão de naming de 100% dos artefatos internos existentes.

#### Divergência 2 — "lithic" como naming

A revisão mantém `maos-lithic`. Meu argumento:

1. O site do Julius se chama "Lithic Token Compression" — é a marca dele
2. O `docs/naming-conventions.md` do MAOS define: *"Semântica: Nomes descrevem propósito, não implementação"*
3. Compare: `context-prep` (propósito), `agent-select` (propósito), `anti-conflict` (propósito) vs `lithic` (metáfora estética)

`response-compression` descreve o **propósito**. `lithic` descreve a **origem**.

#### Divergência 3 — Número de artefatos

A revisão cria: 3 skills (`maos-lithic`, `maos-autonomy`, `maos-profile`) + 3 commands (`/compress`, `/autonomy`, `/profile show`) + hooks = **6+ artefatos novos**.

Minha v3: **1 skill + 1 hook + 2 extensões de existentes** = 4 toques cirúrgicos.

Adicionalmente, os commands existentes (`/sync`, `/audit`, `/status`, `/delegate`, `/worktree`, `/mvv`) são todos **ações que fazem algo**. Nenhum é setter de configuração. `/compress full` e `/autonomy autonomous` seriam setters — quebraria o padrão.

#### Divergência 4 — GaaS insight ausente

A revisão reconhece hooks como mecanismo de enforcement mas não articula o princípio GaaS:

- **Revisão**: cria skills que "pedem" ao LLM para ser conciso → Governance by Hope
- **v3**: cria skill **E** hook que detecta token bloat via stderr → GaaS

Para um framework que inventou o conceito "GaaS vs Governance by Hope", essa distinção é identitária.

### 6.4 Veredicto comparativo

| Aspecto | v1-R (revisada) | v3 (pós-inventário) | Quem está certo |
|---|---|---|---|
| Feature interna (não plugin) | Sim | Sim | **Convergência** |
| Prefixo `maos-` | Sim | Não | **v3** — 0% dos internos usam |
| Nome "lithic" | Sim | Não — `response-compression` | **v3** — naming-conventions.md |
| Autonomia como artefato novo | `maos-autonomy` | Extensão Sentinel config | **v3** — não duplicar |
| Commands novos | 3 | 0 | **v3** — commands são ações |
| GaaS hook | Reconhece, não cria | `token-budget-gate.sh` | **v3** — alinhado com DNA |
| Role matrix combinada | Compressão + autonomia | Separada | **v1-R** — mais prático |
| Crédito Julius | NOTICE/ATTRIBUTION | Frontmatter attribution | **Convergência** |

**Score**: v1-R acerta ~60% (5/9), v3 acerta ~80% (7/9).

---

## 7. Proposta Final Harmonizada (v4)

> Incorpora o melhor de todas as iterações. Resolve as divergências restantes.

### 7.1 Princípio unificador

> Compressão que depende apenas do LLM ler um SKILL.md é **Governance by Hope**.  
> Compressão com um hook que detecta, registra e sugere é **GaaS**.  
> O objetivo é combinar os dois: skill para o LLM + hook para o sistema.

### 7.2 Estrutura de arquivos (4 toques cirúrgicos)

```
multi-agent-os/
├── skills/
│   ├── context-prep/SKILL.md          ← ESTENDER (Step 3, regra 6: verbosity by audience)
│   └── response-compression/
│       └── SKILL.md                   ← NOVO (output verbosity, lineage caveman)
├── sentinel/
│   └── config.json                    ← ESTENDER (execution_policy aliases)
└── plugin-scripts/
    └── governance/
        └── token-budget-gate.sh       ← NOVO (GaaS hook determinístico)
```

**0 novos plugins. 0 novos commands. 0 duplicação do Sentinel.**

### 7.3 Artefato 1: extensão do `context-prep`

Adicionar ao `skills/context-prep/SKILL.md` uma 6ª regra no Step 3 (Context Minimization):

```markdown
Rule 6: Apply response verbosity by audience:
  - Output goes to human      → lite compression (articles kept, no fragments)
  - Output goes to agent/pipe → full compression (fragments OK, no filler)
  - Output goes to CI/machine → ultra compression (abbreviate, arrows for causality)
```

**Justificativa**: não criar artefato separado para "compressão antes de delegação" — o `context-prep` já é exatamente isso. Goldilocks: extensão > criação.

### 7.4 Artefato 2: `response-compression` skill (novo)

#### Frontmatter

```markdown
---
name: response-compression
version: 1.0.0
description: >
  Controls output verbosity. Cuts output tokens 60-85% for machine-facing or
  internal tasks while preserving full technical accuracy. Auto-maps compression
  level to agent role. Use when: "be brief", "less tokens", "caveman mode",
  or when Sentinel fires RULE-009 (Token Bloat). Profiles: none | lite | full | ultra.
attribution: Derived from JuliusBrussee/caveman (MIT). Core rules adapted, role matrix added.
protocols:
  - RULE-009  # Sentinel Token Bloat
agnostic: [os, project]
---
```

#### Role-based combined matrix (da v1-R, integrada, audience formalizada na v5)

```
AGENT ROLE           AUDIENCE     COMPRESSION  AUTONOMY     RATIONALE
─────────────────────────────────────────────────────────────────────────
orchestrator         human        none         supervised   Nuance matters; human reads output
documentation agent  external     none         supervised   External audience; clarity > efficiency
consolidator         human        lite         supervised   Final synthesis; human-facing
code reviewers       senior dev   full         supervised   Known context; senior audience
sub-agents técnicos  orchestrator full         autonomous   Machine parses output
log/error triage     pipeline     full         autonomous   Structured data; no prose needed
CI/pipeline agents   machine      ultra        autonomous   No human reads; max compression
batch/scheduled      machine      ultra        unattended   Full governance stack required
```

#### Regras de compressão (herdadas do Julius, adaptadas)

```
Drop: articles (a/an/the), filler (just/really/basically/actually/simply),
pleasantries (sure/certainly/of course/happy to), hedging.
Fragments OK on full/ultra. Short synonyms. Technical terms exact.
Code blocks unchanged. Errors quoted exact.
Pattern: [thing] [action] [reason]. [next step].
```

#### Níveis de intensidade

| Nível | Definição |
|---|---|
| none | Sem compressão. Estilo padrão Claude. |
| lite | Sem filler/hedging. Mantém artigos + frases completas. Profissional mas conciso. |
| full | Drop artigos, fragmentos OK, sinônimos curtos. Clássico caveman. |
| ultra | Abreviações (DB/auth/fn/impl), setas para causalidade (X → Y). Telegráfico. |

#### Auto-clarity guardrails (herdados do Julius)

```
DROP compression for: security warnings, irreversible action confirmations,
multi-step sequences where fragment order risks misread, user confused.
RESUME compression after critical section ends.

Example — destructive op:
  "Warning: This will permanently delete all rows in `users` table. Cannot be undone."
  (caveman resumes after warning is clear)
```

#### Ativação

```
Triggers: "be brief", "less tokens", "caveman mode", "compress output",
          Sentinel RULE-009 alert, agent role auto-detection
Deactivation: "normal mode", "stop compression", session end
Level persists until changed or session ends.
```

#### Atribuição

```
Based on JuliusBrussee/caveman (MIT License)
https://github.com/JuliusBrussee/caveman
Core compression rules adapted. Role-based matrix, Sentinel RULE-009 integration,
and GaaS enforcement layer added by multi-agent-os.
```

#### Success metrics (v5 — incorporado de peer review)

Três métricas core para validar se compressão está ajudando ou prejudicando:

| Métrica | O que mede | Como coletar | Sinal de problema |
|---|---|---|---|
| **Output tokens por turn** | Efetividade da compressão | Sentinel `collect_token_usage` | Sem redução vs baseline |
| **Follow-up turns por task** | Inversão de custo por ambiguidade | Contagem de turns entre task start e completion | Mais turns com compressão que sem |
| **Auto-clarity activations** | Frequência do guardrail desligando compressão | Contagem de reversões (security, irreversible, confused) | >30% de turns revertendo = profile muito agressivo |

**Nota**: métricas de escopo maior (task completion, retrabalho) pertencem ao Sentinel, não ao skill de compressão.

### 7.5 Artefato 3: extensão do Sentinel config

Adicionar ao `sentinel/config.json` (seção `execution_policy`):

```json
"execution_policy": {
  "_comment": "Maps human-readable autonomy profiles to existing Sentinel enforcement modes. No new system — aliases for enforcement_modes.",
  "profiles": {
    "supervised": {
      "sentinel_enforcement_mode": "strict",
      "description": "Human in loop. Sentinel blocks HIGH violations. Default for interactive sessions."
    },
    "autonomous": {
      "sentinel_enforcement_mode": "moderate",
      "description": "Controlled action. Acknowledgment required for HIGH. For trusted internal ops."
    },
    "unattended": {
      "sentinel_enforcement_mode": "moderate",
      "requires": ["allowlist_defined", "budget_limit_set", "audit_enabled"],
      "description": "Isolated execution. Full governance stack mandatory. For batch/scheduled agents."
    }
  },
  "default": "supervised"
}
```

**Nenhum código novo.** Apenas config que mapeia aliases para enforcement modes já existentes.

### 7.6 Artefato 4: `token-budget-gate.sh` (GaaS hook)

Caminho: `plugin-scripts/governance/token-budget-gate.sh`

Ativado via `PreToolUse[Task]` (hook já configurado em `hooks/hooks.json`).

```bash
#!/usr/bin/env bash
# token-budget-gate.sh
# GaaS Motor 1: detecta context bloat antes de delegação
# Integra com RULE-009 do Sentinel (Token Bloat — severity LOW)
# Não bloqueia (RULE-009 não tem auto_block) — sugere compressão
#
# MEASUREMENT NOTE (v5):
#   wc -c mede caracteres, não tokens. Heurística: ~4 chars/token para inglês.
#   Threshold 4000c ≈ ~1000 tokens. Para conteúdo misto (código + prose + unicode),
#   a variância é alta. Aceitável como MVP advisory. Evolução futura: usar tiktoken
#   ou chars/4 como estimativa explícita.
#
# PROV: https://github.com/ekson73/multi-agent-os/blob/main/plugin-scripts/governance/token-budget-gate.sh
# Version: 1.1.0 | Created: 2026-04-10 | Updated: 2026-04-10 (v5 measurement note)

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')

if [[ "$TOOL" != "Task" ]]; then
  echo "{}"
  exit 0
fi

SPAWN_PROMPT_LENGTH=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' | wc -c)
THRESHOLD=4000

if [[ "$SPAWN_PROMPT_LENGTH" -gt "$THRESHOLD" ]]; then
  # Sugestão não-bloqueante (alinhado com RULE-009 auto_block: false)
  echo "{\"decision\":\"allow\",\"reason\":\"token-budget-gate: spawn context ${SPAWN_PROMPT_LENGTH}c exceeds ${THRESHOLD}c threshold. Consider response-compression:full for sub-agent.\",\"hookSpecificOutput\":{\"sentinel_rule\":\"RULE-009\",\"suggestion\":\"response-compression:full\",\"context_size\":\"${SPAWN_PROMPT_LENGTH}\"}}"
else
  echo "{}"
fi
```

#### Hook enforcement roadmap (v5 — incorporado de peer review)

O hook MVP opera em modo **advisory** (sugere, não bloqueia), alinhado com RULE-009 `auto_block: false`.

| Modo | Comportamento | Quando ativar |
|---|---|---|
| **advisory** (MVP) | Sugere compressão via `hookSpecificOutput` | Agora — default |
| **shaping** (futuro) | Ajusta compression profile default no spawn prompt | Quando telemetria confirmar benefício |
| **strict** (futuro) | Impede spawn acima de budget sem compactação prévia | Quando mapeado a Sentinel `enforcement_mode: strict` |

Cada modo mapeia diretamente a um `enforcement_mode` do Sentinel: advisory=soft, shaping=moderate, strict=strict.

**Registrar no `hooks/hooks.json`** sob `PreToolUse[Task]`:

```json
{
  "type": "command",
  "command": "${CLAUDE_PLUGIN_ROOT}/plugin-scripts/governance/token-budget-gate.sh"
}
```

### 7.7 Naming final

| Artefato | Nome | Justificativa |
|---|---|---|
| Skill | `response-compression` | Propósito > metáfora. Sem prefixo — padrão existente. |
| Hook | `token-budget-gate.sh` | GaaS Motor 1. Em `governance/` junto com `worktree-gate.sh`. |
| Config | `execution_policy` em `sentinel/config.json` | Extensão, não duplicação. |
| Extension | Regra 6 em `context-prep/SKILL.md` | Evolução natural do artefato existente. |

### 7.8 Sobre o `eko-claude-plugins` marketplace

O marketplace tem hoje 1 plugin: `multi-agent-os`.

**Sequência recomendada:**
1. `response-compression` entra primeiro como **skill interno** ao multi-agent-os
2. Quando (e se) o skill crescer para produto autônomo com hooks próprios, extrair como segundo plugin no marketplace
3. Seguir o Framework Consumption Model: framework primeiro, extração depois

### 7.9 Decisões de não-fazer (deliberadas)

| O que não fazer | Por quê |
|---|---|
| Não criar plugin `multi-agent-os-lithic` ou `maos-lithic` | Plugin `maos` v1.5.0 já existe. Feature interna, não produto lateral. |
| Não criar commands `/compress`, `/autonomy`, `/profile` | Commands existentes são ações, não setters de config. Padrão do MAOS. |
| Não criar `maos-autonomy` ou `maos-profile` como artefatos | Sentinel já tem `enforcement_modes`. Duplicação desnecessária. |
| Não usar prefixo `maos-` em skills internos | 0% dos 14 skills existentes usam prefixo. Padrão consolidado. |
| Não usar nome "lithic" | É a marca do Julius (juliusbrussee.github.io/caveman = "Lithic Token Compression"). |
| Não forkar estruturalmente o repo do Julius | SKILL.md tem ~50 linhas de prompt. Reimplementar com atribuição (Alt B) é suficiente. |
| Não criar `context-compressor` como skill separado | `context-prep` já tem Context Minimization (Step 3). Extensão > criação. |
| Não criar wenyan modes (文言文) | Escopo desnecessário para multi-agent-os. Pode ser adicionado depois se demanda surgir. |

---

## 8. Peer Review Externo e Refinamentos v5

> O proponente externo leu o documento v4, validou-o como baseline principal, e ofereceu contribuições adicionais. Esta seção documenta a análise desse peer review.

### 8.1 Veredicto do peer reviewer

O proponente admitiu explicitamente: "o documento anexado venceu a comparação" e "se eu tivesse que escolher entre minha proposta anterior e a proposta do documento, eu escolheria a do documento". Pontos de convergência total:

- Não criar plugin novo
- Skill `response-compression` sem prefixo `maos-`
- Estender `context-prep` em vez de criar artefato separado
- Estender Sentinel config em vez de novo sistema de autonomia
- Hook determinístico GaaS
- Reimplementação com atribuição ao Julius

### 8.2 Contribuições aceitas (com ajuste de escopo)

| Contribuição | Ação tomada | Seção afetada |
|---|---|---|
| Token estimation no hook (chars ≠ tokens) | Documentado como nota de medição no hook; `wc -c` como heurística MVP | §7.6 |
| Telemetria operacional formal | 3 success metrics adicionadas ao skill | §7.4 (novo bloco) |
| Matriz role × audience formalizada | Audience adicionado como coluna formal na matrix | §7.4 |
| Hook com modos evolutivos (advisory→shaping→strict) | Documentado como roadmap, mapeado a enforcement_modes | §7.6 (novo bloco) |
| ADR para decisão de não-plugin | Já coberto pela seção 7.9; não criar arquivo separado | Sem mudança |

### 8.3 Sugestões rejeitadas ou já cobertas

| Sugestão | Decisão | Motivo |
|---|---|---|
| Renomear para `response-policy`/`response-shaping` | Rejeitada | Premature abstraction. YAGNI. Renomear skill é trivial se necessário. |
| "Documento pende para mínima mudança" | Rejeitada como crítica | Extração para plugin independente leva ~30 min. Arquitetura não impede. |
| ADR separado para "por que não plugin" | Já coberta | Seção 7.9 ("Decisões de não-fazer") documenta com justificativas. |

### 8.4 Ponto de observação não resolvido

O proponente nota que o hook "sugere mas não muda nada automaticamente" e que isso pode ser conservador para subagents internos. A análise reconhece isso como válido, mas a decisão deliberada é: **começar em modo advisory e evoluir baseado em dados de telemetria**, não em suposições. Os 3 modos do roadmap (advisory→shaping→strict) endereçam isso como evolução, não como MVP.

### 8.5 Comparação final consolidada (todas as propostas)

| Aspecto | v1 (externa) | v1-R (revisada) | v2 (pré-inv.) | v3 (pós-inv.) | **v4/v5 (final)** |
|---|---|---|---|---|---|
| Alinhamento MAOS | Baixo | Médio | Parcial | Alto | **Total** |
| Alinhamento GaaS | Nenhum | Parcial | Nenhum | Total | **Total** |
| Naming | lithic | maos-lithic | response-compression | response-compression | **response-compression** |
| Novos plugins | 1 | 0 | 0 | 0 | **0** |
| Novos commands | 4 | 3 | 0 | 0 | **0** |
| Artefatos novos | 6+ | 6+ | 3 | 4 | **4** (1 skill + 1 hook + 2 extensões) |
| Autonomia | Nova dimensão | maos-autonomy | Ext. Sentinel | Ext. Sentinel | **Ext. Sentinel** |
| Input tokens | Ignorado | Ignorado | Integrar context-prep | Ext. context-prep | **Ext. context-prep** |
| Role matrix | Ausente | Por agente | Separada | Combinada | **Combinada + audience formal** |
| Métricas | Nenhuma | Nenhuma | Nenhuma | Nenhuma | **3 success metrics** |
| Hook enforcement | Nenhum | Reconhece | Nenhum | Advisory | **Advisory + roadmap evolutivo** |
| Peer-reviewed | Não | Não | Não | Não | **Sim (4 rounds)** |

### 8.6 Status de convergência

Após 5 iterações de design e 4 rounds de peer review cruzado (propostas externas analisadas por Claude + Claude analisado por proponente externo), o design atingiu **convergência assintótica**: os dois últimos rounds produziram zero contribuições arquiteturais novas, confirmando maturidade para implementação.

### 8.7 Rounds 3 e 4 — Fechamento do ciclo

#### Round 3 (proponente leu v5 com refinamentos)

**Veredicto do proponente**: mudou de "approve with changes" para "approve with minor reservations" — confirmando que as incorporações da v5 resolveram seus pontos anteriores.

**Pontos levantados e status:**

| Ponto | Onde já estava coberto na v5 | Ação |
|---|---|---|
| `unattended` ainda frágil | §7.5 (execution_policy com `requires`) | Nenhuma — ver nota 8.7.1 |
| Métricas mínimas | §7.4 (3 Success Metrics) | Suficiente para MVP |
| Hook advisory vs shaping | §7.6 (Hook enforcement roadmap) | Roadmap documenta evolução |
| chars vs tokens | §7.6 (MEASUREMENT NOTE) | Documentado como heurística MVP |

**Zero contribuições genuinamente novas.** Tudo repetição ou confirmação do que já existia.

#### Round 4 (proponente leu v5 final)

**Veredicto do proponente**: "A v5 ganhou. Adote a v5 como design final." Mudou para "approve with minor reservations" sem nenhum must-fix novo. Auto-crítica explícita: "minha sugestão ajudou a empurrar a solução, mas o documento final ficou superior ao que eu propus isoladamente."

**Contribuições novas**: zero. Quarto round consecutivo de validação sem alteração arquitetural.

#### 8.7.1 Nota sobre `unattended → moderate` (justificativa técnica)

O proponente questionou repetidamente (rounds 2, 3 e 4) se `unattended → moderate` é permissivo demais. A decisão deliberada é mantida, com justificativa:

- `strict` no Sentinel **bloqueia** HIGH violations esperando acknowledgment humano — humano que **não existe** em modo unattended. O agente ficaria travado indefinidamente.
- `moderate` **permite** execução com logging, enquanto o campo `requires: [allowlist_defined, budget_limit_set, audit_enabled]` garante que só roda se a governance stack estiver completa.
- São **duas camadas complementares**, não alternativas: `enforcement_mode` controla reação a violações; `requires` controla pré-condições de ativação.

Criar um quarto enforcement_mode (ex: `strict_unattended`) seria duplicação do Sentinel para resolver um caso que `moderate + requires` já cobre.

### 8.8 Decisão final de encerramento

**Ciclo de peer review encerrado em 2026-04-10** após 4 rounds sem contribuições arquiteturais novas. O design v5 é o baseline de implementação.

| Métrica do processo | Valor |
|---|---|
| Iterações de design | 5 (v1 → v2 → v3 → v4 → v5) |
| Rounds de peer review | 4 |
| Contribuições aceitas (total) | 4 (token estimation, telemetria, audience, hook roadmap) |
| Contribuições rejeitadas (total) | 5 (lithic naming, maos- prefix, risk_class dimension, response-policy rename, ADR separado) |
| Contribuições redundantes (últimos 2 rounds) | 100% — zero novidade |
| Status final | **Approved — ready for implementation** |

---

## Referências

### Fontes primárias (pesquisa caveman)
- [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) — repositório original
- [caveman SKILL.md](https://github.com/JuliusBrussee/caveman/blob/main/skills/caveman/SKILL.md) — prompt verbatim
- [caveman plugin.json](https://github.com/JuliusBrussee/caveman/blob/main/.claude-plugin/plugin.json) — manifest
- [Lithic Token Compression](https://juliusbrussee.github.io/caveman/) — site oficial
- [SkillsLLM listing](https://skillsllm.com/skill/caveman) — 9.100+ stars, 409 forks
- [arXiv 2604.00025](https://arxiv.org/abs/2604.00025) — "Brevity Constraints Reverse Performance Hierarchies"
- [HN Discussion](https://news.ycombinator.com/item?id=47647455) — críticas técnicas, respostas do autor
- [Decrypt article](https://decrypt.co/363440/devs-claude-talk-like-caveman-cut-costs-work-better) — savings reais
- [Hackaday article](https://hackaday.com/2026/04/06/so-expensive-a-caveman-can-do-it/) — análise técnica
- [36kr article](https://eu.36kr.com/en/p/3756289723286272) — perspectiva comunidade chinesa
- [Claude Code cost docs](https://code.claude.com/docs/en/costs) — estratégias nativas oficiais
- [Dev.to article](https://dev.to/onsen/caveman-claude-the-token-cutting-skill-thats-changing-ai-workflows-4hmc) — tutorial e análise
- [drona23/claude-token-efficient](https://github.com/drona23/claude-token-efficient) — alternativa concorrente
- [om-patel5/Caveman-Claude](https://github.com/om-patel5/Caveman-Claude) — optimization layer fork

### Fontes internas (multi-agent-os)
- `docs/gaas-architecture-manifesto.md` — GaaS como princípio fundante (3 Motores)
- `docs/GaaS_INSTALLATION_GUIDE.md` — guia de instalação dos 3 Motores
- `docs/framework-consumption.md` — Source of Truth + PROV tags + TTL Policy
- `docs/naming-conventions.md` — padrões de nomenclatura (semântica > implementação)
- `docs/ai-native-environment.md` — especificação do ambiente AI-Native
- `sentinel/config.json` — RULE-009 Token Bloat, enforcement_modes (soft/moderate/strict)
- `skills/context-prep/SKILL.md` — Context Minimization Step 3 (5 regras existentes)
- `skills/skill-writer/SKILL.md` — padrão de criação de skills (validação, frontmatter)
- `agents/forge.md` — Goldilocks Principle, RBAD taxonomy, 33 Socratic Questions
- `agents/governance-auditor.md` — Law Taxonomy (SEC/NAM/API/DAT/CMP)
- `rules/axial-principles.md` — 5 princípios operacionais (Forge, Boy Scout, Eisenhower)
- `rules/core-directive.md` — C01 directive, cadeia de delegação
- `rules/agent-scm.md` — SCM agent, modelo de escopo atômico
- `hooks/hooks.json` — lifecycle hooks existentes (4 hooks, 5 scripts)
- `.claude-plugin/plugin.json` — manifest do plugin (maos v1.5.0)
- `skills/README.md` — catálogo de skills com categorias
- `agents/README.md` — catálogo de agents com convenção de naming
- `commands/README.md` — catálogo de commands com padrão de estrutura

### Repositório marketplace
- [ekson73/eko-claude-plugins](https://github.com/ekson73/eko-claude-plugins) — marketplace pessoal (1 plugin: multi-agent-os)

---

*Análise por Claude-Sonnet-4.6 + Claude-Opus-4.6 + Emilson Moraes + Peer Review Externo (Perplexity/Sonar, 4 rounds) | Sessão: caveman | 2026-04-10 | v5 final — Approved, ready for implementation*
