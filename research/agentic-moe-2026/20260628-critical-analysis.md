---
title: "Análise Crítica — dynamic workflow (forge 33Q + persona-pipeline + anima)"
date: "2026-06-28"
method: "dogfood: maos:forge (33 Socratic + RBAD/Goldilocks) · maos:persona-pipeline (6-stage board) · skill anima (naming)"
subject: "maos-moe-ath (working-name) = MAOS Hub (ADR-006) + curated community-integration platform (ADR-007)"
lang: "prosa pt-BR · identifiers en-US"
status: "parecer — não-vinculante; recomendações sujeitas a HITL"
---

# Análise Crítica — o projeto sob fogo amigo (recursivo)

> Rodamos os **próprios experts do MAOS** contra o projeto. Eles **convergiram** numa verdade dura.
> Relato fielmente, sem defender o framing do North Star do turno anterior.

## §1 — O NOME (decisão da `anima`) — [HUMAN_DOMAIN: ratificar]

**`MAOS Agora`** · machine-id **`maos-agora`** (12/12 correção + 4/4 ressonância).
- **Por quê:** a *agora* grega era o centro cívico curado — **lugar de encontro + mercado vetado +
  locus do discurso** — espelhando as três faces da plataforma (integrador + registry + console).
  Postura *gate-by-default* ("nem todos entram pra vender") = o guardrail reject-by-default. Universal,
  secular, 3 sílabas, limpa em EN/PT/ES, **zero colisão** no repo e no espaço de agentic-tooling.
- **Runner-up rejeitado:** `maos-atrium` — etimologia correta (átrio romano), mas **semanticamente
  invertido** (hall interno privado × front-door público); evoca enclausuramento, não curadoria.
- ⚠️ É nome de marca/identidade pública → **ratificação do operador** antes de propagar em docs/ADRs.

## §2 — Veredito executivo

- **`maos:persona-pipeline`:** **GO-WITH-FIXES · autonomy_score 0.62 (MEDIUM, < HIGH 0.85).** "O
  caminho não está errado; está **fora de ordem e super-escopado para a evidência atual**."
- **`maos:forge` (Goldilocks/RBAD):** **ASSET com risco de virar COST.** Atomicidade **falha parcial**:
  ADR-006 (Hub = gating de runtime) é atômico e pronto; **ADR-007 (plataforma curadora) é um SEGUNDO
  produto, de natureza editorial-perpétua, colado por retórica** ("três faces de uma coisa só") —
  ciclos de vida/risco/cadência incompatíveis. *Forte onde **constrói** (Hub, adapters, guardrails);
  fraco onde **se declara** (curador-de-referência, "de-facto MoE OS"). Construir primeiro, declarar depois.*

## §3 — Os 3 fixes críticos (o núcleo acionável — ambos os agentes apontaram)

1. **Os "dentes" do hub NÃO existem → o console está BLOCKED.** `@with_feedback` em
   `mcp-tools/maos-mcp-hub/lib/gateway/router.py` só **anota** `_agent_feedback`; o router executa os
   handlers **incondicionalmente**; gating de `enabled`/`profile`/`conflicts_with` = **nil** (grep).
   Sem isso, registry+console viram **catálogo advisory**, não front-door que enforça. → **adicionar o
   gating-seam no router** (filtro profile+`conflicts_with` antes do dispatch). É o maior build-risk e está **unscheduled**.
2. **O "CI floor bloqueante" é ~60% real; o gatekeeper não existe; o fixture known-bad é nomeado mas
   não instanciado.** Trivy roda `exit-code:"0"` (advisory) em `supply-chain-sentinel.yml:~57`;
   RULE-012 é *proposed* sem hook; `contribution-gatekeeper` ausente de `agents/`; sem `fixtures/known-bad/*`.
   **A porta antes da fechadura.** → (a) flip Trivy → `exit-code:"1"` + job required; (b) commitar
   `fixtures/known-bad/{planted-secret, second-CLAUDE.md}`; (c) RULE-012 como PreToolUse hook **ANTES**
   de qualquer run unattended do gatekeeper (é o checkpoint HITL que o ADR-006 já exige).
3. **Demanda NÃO-VALIDADA (N=1 = a nossa própria pesquisa) + cold-start severo (<1K stars) +
   reject-by-default que se auto-derrota a 2 pessoas.** Curador de confiança **sem tração própria** =
   paradoxo (por que confiar no curador desconhecido?). Modo de colapso: reject-by-default × 2-pessoas
   × gatekeeper-inexistente × catálogo-zero = **curador de prateleira vazia**. → **teste Wizard-of-Oz
   de 1 dia ANTES da WAVE 5-6**: publicar o `conflicts_with`-graph + use-case-map de ~20 tools como
   markdown estático (gist/README) no Discord do Claude Code / r/ClaudeAI / HN. **Vender conflict-safety**
   ("instale tools sem que se quebrem em silêncio"), não "discovery+education" (feature copiável).
   Tracionou → constrói a máquina; crickets → WAVE 5-6 seria theater.

## §4 — Recomendação convergente (o que fazer com isto)

1. **Ratificar ADR-006** (atômico, substrato real, pronto). 
2. **Rebaixar ADR-007** de "North Star ratificável" para **Vision exploratória (Draft)** até (a) o
   **eval-first (WT0)** medir o "~70%"; (b) a **primeira integração real** provar o gate; (c) existir
   **tração mínima**. Ocupar "front-door confiável do commons" é promessa que exige confiança a se
   **ganhar**, não **declarar**.
3. **Reduzir ao minimal-viable-slice:** registry SSOT auto-derivado de frontmatter + **15–20 entradas
   hand-curated** (what/when/`conflicts_with`) renderizadas como view `context-aware` **read-only**.
   Sem gatekeeper, sem integrator, sem console-gating, sem distributor-hardening. **Isto É o Wizard-of-Oz.**
4. Só **depois** de sinal de demanda + floor bloqueante real → expandir p/ WAVE 5-6.

## §5 — Risco × Mitigação (consolidado)

| Risco | Sev | Mitigação acionável |
|---|---|---|
| Console sem dentes (router não gateia) | **ALTA** | gating-seam em `lib/gateway/router.py` (profile+conflicts antes do dispatch) — **agendar** |
| CI floor advisory + gatekeeper inexistente + sem fixture | **ALTA** | flip Trivy `exit-code:1`; commitar `fixtures/known-bad/*`; RULE-012 hook antes do gatekeeper unattended |
| Demanda não-validada + cold-start | **ALTA** | WoZ 1-dia (conflict-graph estático) antes de construir; vender conflict-safety |
| Scope-creep (3 produtos sob 1 North Star) | **MÉDIA** | minimal-viable-slice; rebaixar ADR-007 a Draft; ratificar só ADR-006 |
| Registry "auto-derivado" para dados editoriais (good-for/when/conflicts) | **MÉDIA** | aceitar curadoria humana p/ campos de julgamento; auto-derivar só id/layer/role |
| Profile SSOT sem data-handling; data-tainting ausente do maos-hub spec | **MÉDIA** | add Requirement: path gitignored/retention/no-secrets; add tainting (trusted/untrusted/derived) |
| "Sucesso quebra o modelo de 2 pessoas" | **MÉDIA** | curadoria agêntica madura **antes** de divulgar; HITL como gargalo conhecido |
| Rollback "receita presente" ≠ "rollback validado"; co-author honor-system | **BAIXA** | testar rollback no DoD; checar trailer co-author em workflow |

## §6 — Best-practices a fixar
1. **Minimal-viable-slice primeiro** (anti-scope-whiplash os3pd) — registry read-only + conflict-graph; é o WoZ.
2. **Fechar os DoD prose-judged antes de qualquer worktree** — instanciar o fixture known-bad; definir
   `risk=HIGH` (WT4), `k`/tokenizer "≤60 tok" (WT3), a "compatibility flagged" do cenário AGPL.
3. **Fechar 2 gaps de privacy/compliance hoje** (spec-level, baratos) — data-handling do profile + data-tainting.

## §7 — As 33 Perguntas Socráticas (forge — condensado)

**Proposta** — (1) problema atômico é real (discovery+confiança+contexto), mas mistura 3 produtos. (2) tese "ATH=MAOS" forte conceitual, **frágil empírica** até o eval. (3) "index+gate+adapter, não re-host" = melhor decisão (mantém ASSET). (4) **mal diferencia** Hub-runtime × plataforma-editorial (maior fraqueza de framing).
**Usabilidade** — (5) modos do console sensatos; `prose-intent` é a cunha de UX certa. (6) "profile-com-dente" só vale **dentro** do runtime MAOS; fora, advisory. (7) `context-aware` promete auditável mas **não especifica** como sinais viram ranking. (8) ASCII-first + HTML-opcional = decisão madura/DRY.
**Viabilidade** — (9) "~80% reúso" parcial: o que importa pro Hub é **GAP/PARTIAL**; valor concentra nos 20% novos. (10) registry "auto-derivado" contradiz: `good-for/when/conflicts` **não derivam** de frontmatter. (11) "2 humanos curam firehose" elegante mas **frágil/não-comprovado**. (12) sequência de waves sã (segurança-primeiro; YAGNI nos cortes).
**Riscos** — (13) existencial e **binário**: 1 integração ruim colapsa a confiança. (14) scope-creep **não plenamente** controlado (fala DRY, desenha plataforma). (15) risco latente de "absorção = theater de legitimação". (16) manutenção perpétua tratada como waves finalizáveis (descompasso).
**Segurança** — (17) threat-model surpreendentemente sólido (C6 marcado ALTA). (18) "nenhum agente sozinho" = guardrail certo (reviewer é alvo de injeção). (19) "guardrail ≠ gateway adiável" se sustenta (falha silenciosa). (20) licença levada a sério (caso karpathy testado).
**Mitigações** — (21) 7 guardrails cobrem bem, **mas advisory até virarem CI/hook**. (22) DoD-gate falsificável = melhor defesa anti-theater. (23) rollback simétrico, mas "quem testa?" indefinido. (24) TTL+auto-eject depende de cron/CI que ainda não prova.
**Soluções** — (25) slot-adapter = a inovação genuína certa. (26) `contribution-gatekeeper` = agente RBAD válido (não disposable). (27) **CTS scorer unificado = solução à procura de problema** (ausência não dói medida). (28) memória (mem0 só) = proporcional.
**Mercado** — (29) gap de mercado real (ninguém é curado+gated+fresco). (30) **MAOS tem direito frágil** (emerging, <1K — paradoxo do curador sem tração). (31) cunha educação/discovery é a certa. (32) **sucesso quebra** o modelo de 2 pessoas (risco invertido). (33) ROI indeterminado até eval+1ª-integração+tração.

## §8 — Meta-nota honesta
A recursão funcionou: rodamos os experts do MAOS contra o próprio MAOS, e eles **rebaixaram a euforia
do North Star** que eu ajudei a construir. Isso é o sistema funcionando — não um fracasso. O projeto é
**bom e ratificável no núcleo (ADR-006 / MAOS Hub)**; a ambição de plataforma (`MAOS Agora`) é **certa
mas prematura como fato** — vira Draft, prova-se com um WoZ barato, e **se ganha o direito de declarar**.
