---
title: "HANDOFF-as-prompt — continuidade no Claude Code (hands-on git-worktrees)"
from: "Cowork design session (Claude Opus 4.8) — 2026-06-27"
to: "Claude Code @ repo multi-agent-os (governança viva: hooks + skills MAOS)"
decision: "docs/adrs/ADR-006-ath-moe-hub-adoption.md"
contract: "openspec/specs/maos-hub/spec.md (os cenários SÃO os critérios de aceite)"
co_creation_review: "maos:governance-auditor (CLEARED-FOR-PR) + maos:persona-pipeline (GO-WITH-FIXES, autonomy 0.35) — correções já incorporadas abaixo"
---

# Handoff — ATH → MAOS Hub (hands-on)

**Por que este handoff existe:** o design/spec/ADR está PRONTO e persistido no repo (Cowork). O
hands-on (worktrees, código, testes, PRs) deve rodar no **Claude Code**, onde a governança MAOS é
**viva** — os hooks de `hooks.json` e as skills (`preflight`, `worktree`, `agentic-tool-intake`,
`enhance-pipeline`, `dogfood-ledger`, `cascade-resolver`…) realmente disparam.

**Co-criação (os experts validaram a si mesmos):** duas personas nativas do MAOS revisaram este
plano. Correções já aplicadas: (1) C1/C6 viram **enforcement de runtime**, não skill-advisory;
(2) **eval-first** — medir o "~70%" antes de construir; (3) cortes anti-over-engineering coerentes
com o `os3pd-manifesto` (≥3 incidentes antes de gateway de runtime); (4) branch names com `<id>`.

**Copie o bloco abaixo e cole numa sessão Claude Code no root do repo.**

---

## ⬇️ COPIE DAQUI ───────────────────────────────────────────────────────────

```text
ROLE: Você é o Claude Code no repo `multi-agent-os` (maos v1.16.0), continuando uma sessão de design
do Cowork. O design/specs JÁ EXISTEM no repo. Função = HANDS-ON: implementar o backlog ATH→MAOS Hub
em git-worktrees, dogfoodando as skills do MAOS. Prosa pt-BR, código en-US.

LEIA PRIMEIRO (fonte da verdade, nesta ordem):
1. docs/adrs/ADR-006-ath-moe-hub-adoption.md           (decisão + §Co-creation review = estes fixes)
2. protocols/moe-hub-architecture.md                   (arquitetura nativa + mapa (a)-(m) + invariantes)
3. openspec/specs/maos-hub/spec.md                     (CONTRATO — Scenarios = critérios de aceite)
4. research/agentic-moe-2026/20260627-ATH-OODA-RECON.md (inventário + backlog + conflitos C1-C6)
5. research/agentic-moe-2026/20260627-final-report.md   (síntese + gate de supply-chain)

GOVERNANÇA (MUST — AGENTS.md §Branching + ADR-004 GitHub Flow + worktree-policy + hierarchical-merge + C07):
- 1 worktree por item. Branch = `feature/<id>-slug` (o `<id>` é OBRIGATÓRIO — minte a chave Jira via
  research/agentic-moe-2026/20260627-prompt-jira-confluence.md, ex.: feature/VKS-1701-ath-routing-eval).
- NUNCA commitar em `main`; sempre PR → squash-merge → delete branch; merge/tag = gate humano.
- Antes do PR: `bash tests/validate-plugin.sh` + gitleaks limpo + atualizar CHANGELOG/ADR + assinar
  (agent ID + ISO-8601). Revisores via C07. Comece com `/preflight`; por item `/worktree` →
  implementar → `/agentic-tool-evaluator` + testes → PR → `/dogfood-ledger`.
- DoD-GATE (regra dura, exigida pela banca): NENHUM worktree fecha num Scenario cujo THEN seja julgado
  por PROSA — todo aceite tem de ser um CAMPO LOGADO ou um GOLDEN FIXTURE. Sem isso, o item não fecha.

SEQUÊNCIA CORRIGIDA (eval-first + safety-runtime-first — NÃO reordene):
WAVE 0 — MEDIR + FUNDAÇÃO DE SEGURANÇA  [ENFORCEMENT = HÍBRIDO · cascade-resolved → autonomy 0.721]
  ENFORCEMENT TOPOLOGY (cascade-resolver, consenso 4/4): C1/C6 = runtime-hook NA Claude Code + advisory
  cross-harness + PISO CI BLOQUEANTE (gitleaks/trivy, harness-agnóstico). Razão: guardrail de SEGURANÇA
  ≠ o "runtime proxy gateway" que o os3pd adia (o invariante falha em SILÊNCIO, nunca acumula os ≥3
  incidentes do gatilho). MERGE-GATE de WT1/WT2 = teste FALSEÁVEL contra fixture known-bad (segredo
  plantado + CLAUDE.md-conductor): RULE-011 decision∈{taint,refuse} · RULE-012 secret_match≠null &
  decision=block em channel=model_output · ci_floor verdict=fail (SARIF resolvível).
  WT0 feature/<id>-ath-routing-eval  ⟵ PRIMEIRO. Harness de eval de roteamento (6 famílias × risco;
      com/sem gating; injeção) estendendo agentic-tool-evaluator. OBJETIVO: MEDIR a cobertura real do
      hub (validar/refutar o "~70%") ANTES de construir o resto. Se medir alto, metade do plano cai.
  WT1 feature/<id>-ath-single-conductor  C1 como HOOK DE RUNTIME (SessionStart/PreToolUse): detectar
      managers co-residentes (ECC/superpowers/gstack/BASE/ruflo/BMAD) por footprint em disco e
      HARD-BLOCK; a regra no agentic-tool-intake é o complemento advisory, não o único controle.
      Aceite: cenários "Single-conductor" + um campo logado de bloqueio.
  WT2 feature/<id>-ath-agentshield  AgentShield = EGRESS ALLOWLIST + SESSION-TAINTING (CLAUDE.md/segredo
      lido ⇒ toda egress não-allowlisted bloqueia) — NÃO denylist de prefixos. Defense-in-depth: ampliar
      assinaturas (incluir sk-ant-, xox, JWT, PEM, base64/split, read-into-var-then-emit) + bloquear
      `git --no-verify`. Inclui data-tainting (trusted/untrusted/derived). Aceite: "Supply-chain gate" + tainting com fixtures.
WAVE 1 — SUBSTRATOS & GATING (só o que a WT0 mostrar necessário)
  WT3 feature/<id>-ath-iso-universal  generalizar o progressive-discovery do maos-mcp-hub → ISO universal.
      DEFINIR explicitamente: `k` (top-k) e o tokenizer do "≤60 tok/tool" (sem isso o threshold é incomputável).
  WT4 feature/<id>-ath-cts-scorer  scorer CTS único (action-priority + rbad + ISO, hard-filters-first).
      DEFINIR `risk=HIGH` como predicado concreto (não "irreversible-ish").
  WT5 feature/<id>-ath-memory  UM backend só: mem0 (default) via /agentic-tool-intake. graphiti = ADIADO
      até haver workload temporal medido (sem gold-plating).
WAVE 2 — REGISTRY (keystone) + condicionais
  WT8 feature/<id>-ath-tool-registry  registry AUTO-GERADO (derivado por decorator do SchemaRegistry, NÃO
      YAML hand-maintained que dá drift). É o keystone que tira o contrato do wiring divergente dos gateways.
  [ADIADO] WT6 OTel-Sentinel — C3 é severidade BAIXA; só quando houver consumidor de telemetria real.
  [CORTADO] WT7 LiteLLM router — o os3pd-manifesto adia gateway de runtime até ≥3 incidentes e o slm-routing
      se autodeclara "NOT a runtime router"; sem multi-tenant/escala, fora do caminho crítico.
WAVE 3 — ADOTAR EXPERTS (só após WAVE 0)
  WT10 chore/<id>-ath-intake-batch  rodar os 26 experts INCLUDED pelo /agentic-tool-intake → verdicts
       INSTALL/ADAPT/SUB-AGENT/ABANDON; reproduzir GSD/MemPalace = EXCLUDED.
WAVE 4 — DOCS
  WT11 docs/<id>-ath-reframe  reframe dos headers da série p/ "MAOS Hub"; regenerar CONSOLIDATED.pdf/html +
       exec-deck; aplicar o toque de MVV no CLAUDE.md §Organizational Identity — MUDANÇA HITL-ESCALADA
       (toca SSOT bootstrap): só no PR de ratificação, nunca num WT lateral. Fechar a entrada do CHANGELOG.

DoR (por item): fontes lidas + worktree criado + cenários de aceite localizados no openspec spec + `<id>` mintado.
DoD (por item): código + testes verdes + validate-plugin + gitleaks limpo + CHANGELOG/ADR + PR (C07) +
  dogfood-ledger + a regra DoD-GATE (nenhum aceite julgado por prosa).

PRIMEIRA AÇÃO: `/preflight` → leia as 5 fontes → `/agentic-status` (confirmar hooks vivos) → abra a WT0
(eval-first). Pare e reporte ao operador ao fim de cada WAVE (gate humano de merge). Se o operador
discordar dos cortes (WT6/WT7) ou do enforcement-de-runtime, rode `/cascade-resolver` sobre o sub-tópico
"runtime-enforcement vs advisory-skill para C1/C6" antes de prosseguir.
```

## ⬆️ COPIE ATÉ AQUI ──────────────────────────────────────────────────────────

---

### Notas para o operador
- **Mudanças vs plano inicial (incorporadas da banca de co-criação):** eval-first (WT0 movido p/ frente);
  C1/C6 viram enforcement de runtime; cortes WT7 (LiteLLM) e adiamentos WT6 (OTel) / metade-WT5 (só mem0);
  branch names com `<id>`; regra DoD-GATE (sem aceite por prosa); definir `k`/tokenizer/`risk=HIGH`.
- **autonomy_score 0.721** (cascade-resolved, consenso 4/4; banda MEDIUM-HIGH, abaixo de HIGH 0.85) =
  autonomia LIMITADA: o teste-de-aceitação known-bad é o checkpoint HITL antes do 1º run não-supervisionado.
  Escale só se o CI-gate for rebaixado de bloqueante p/ advisory.
- O `openspec/specs/maos-hub/spec.md` é o contrato spec-driven; cada WT fecha quando seus Scenarios passam.
