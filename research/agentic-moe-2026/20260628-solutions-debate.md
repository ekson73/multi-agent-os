---
title: "Debate de Soluções — rebatendo a análise crítica (Jeff Dean · Sam Altman · Steve Jobs)"
date: "2026-06-28"
method: "dogfood: 3 arquétipos-consultor (eng/mercado/escopo) debatem+rebatem os 8 problemas; síntese via disciplina converge (steelman→critique→compare→synthesize→reject-log)"
upstream: "20260628-critical-analysis.md (os problemas)"
lang: "prosa pt-BR · identifiers en-US"
status: "parecer convergente — não-vinculante; HITL"
---

# Debate de Soluções — a dialética resolveu para cima

> Rodamos 3 lentes ortogonais contra os problemas da banca anterior. **Elas convergiram** — e a
> solução é a MESMA nas três: **cortar para a cunha "instalar a ferramenta certa sem quebrar o
> resto", entregar barato, e GANHAR a plataforma em vez de declará-la.** Toda objeção tem saída.

## §1 — A tese convergente (o achado)

- **Jeff Dean (eng):** *"Nenhum problema é bloqueador — são PRs agendáveis. O build-risk percebido vem
  de escopo não-instanciado, não de dificuldade de engenharia."*
- **Sam Altman (mercado):** *"Há PMF plausível — não na 'plataforma curadora' (prematura, copiável),
  mas na **conflict-safety como cunha** (dor aguda, sem dono, defensável por verificabilidade)."*
- **Steve Jobs (foco):** *"Uma coisa pronta + uma narrativa fingindo de coisa. Corte tudo que não
  serve ao instante em que o operador diz o que quer e instala a coisa certa, só ela, sem quebrar o resto."*

**Síntese:** a recomendação da crítica ("rebaixar ADR-007, minimal-slice") **se confirma — mas
reenquadrada para cima**: não é recuo por fraqueza, é **FOCO**. O núcleo é real e construível; a
ambição de plataforma é o **destino que se ganha**, não a premissa que se declara.

## §2 — Problema → Rebuttal → Solução convergida → Esforço → Residual

| # | Problema (crítica) | Rebuttal (debate) | Solução convergida | Esf. | Residual |
|---|---|---|---|---|---|
| **P1** | "Dentes" não existem no router → maior build-risk | **Exagerado.** Confunde ausência-de-código com dificuldade. O seam já tem irmão (`request.level<3`, router.py:91) | **gating-seam:** após validar `operation` (router.py:141), pré-dispatch — `policy` opcional no `__init__` + bloco `enabled? → conflicts_with vs profile ativo → senão erro estruturado (mesmo envelope `_agent_feedback`)`. ~25-40 linhas + interface `PolicyResolver` (profile vem de fora). `policy=None`=passthrough → 0 regressão nos 96 actions | **S/M** | o `PolicyResolver` (origem do profile) — manter burro v1 (dict em memória, sem watch) |
| **P2** | CI-floor ~60% + gatekeeper inexistente + fixture ausente ("porta antes da fechadura") | **Certo, 100%.** | **Ordem: fixture→floor→hook.** (1) commitar `fixtures/known-bad/{planted-secret.env, second-CLAUDE.md}` (sem alvo o gate não é falsificável); (2) flip Trivy `exit-code:1` + `gate_on:vuln,secret` + **job REQUIRED** no branch-protection (sem "required" o exit-code é decorativo); (3) RULE-012 PreToolUse hook **só depois** que (1)+(2) provarem o floor | **S+S+M** | gatekeeper-agent fica p/ depois do floor provado |
| **P3** | Demanda N=1 + cold-start + "paradoxo do curador" | **Diagnóstico certo, fatalidade errada.** N=1 = demanda visceral instrumentada (founder-as-acute-user). **Paradoxo colapsa:** ninguém confia no *curador*, confia no *artefato* — o conflict-report ou rejeita certo ou não (falsificável na hora, não reputacional) | **Wedge = conflict-safety**, não discovery/educação. WoZ **interativo single-input:** "cole sua lista de plugins/MCPs → recebo o conflict-report (L0 collisions · token-tax · AGPL traps)". Distribuir no Discord do Claude Code + r/ClaudeAI **com o nosso stack como case** ("rodamos 26 tools, 6 colidiam — eis o mapa"). PMF = gente colando *o stack dela* | **S** (1 dia) | medir *pull* (colagens), não views |
| **P4** | Atomicidade-falha: ADR-007 = 2º produto colado por retórica | **Certo (Jobs mais duro):** "ADR-006 é uma COISA (runtime sim/não, atômico); ADR-007 é um NEGÓCIO (editorial-perpétuo) fingindo de produto que fecha em waves" | **Separar:** ratificar ADR-006 (atômico); **ADR-007 → Vision exploratória (Draft)**. Identidade honesta: não "a plataforma curadora do commons", e sim *"o jeito mais simples de descobrir e instalar a ferramenta agêntica certa sem quebrar as outras"* | **S** (status edit) | "Draft" não pode virar gaveta — mantido vivo pelo wedge |
| **P5** | Registry "auto-derivado" × campos editoriais (contradição) | **Certo — contradição real** (spec linha 24 × 30) | **Split limpo:** `registry.generated.yaml` (CI regenera, read-only: id/owner/layer/role/category/requires/harness/license_spdx/provenance/ttl) + `registry.curated.yaml` (PR-reviewed: recipes/good-for/when/`conflicts_with`/activation/rollback). Merge no load — mata drift E honra que conflito é decisão | **S** (spec) / **M** (gerador) | — |
| **P6** | "2 humanos curam firehose; sucesso quebra o modelo" | **Risco invertido = feature, não bug** (se a curadoria agêntica for o produto) | **Inverter inbound→outbound:** não cure o firehose — cure **a fila que o usuário submete** (usuário traz a tool → pipeline agêntico responde → humano ratifica só o borderline). Volume vira **moat de dados**, não gargalo de mão-de-obra | **M** | exige os dentes (P1/P2) primeiro |
| **P7** | CTS scorer unificado = over-engineering | **Crítica certa: corte/adie** (anti-pattern clássico — otimização prematura) | **v1:** hard-filters-first + tie-break por layer-priority (já é o que o spec descreve). Score ponderado = WT4-deferred | **0** (adiar) | só medir com ≥3 tools competindo pela mesma fatia de turno |
| **P8** | Privacy: data-tainting ausente + profile sem data-handling | **Certo e barato** | **1 Requirement** em `maos-hub/spec.md`: profile path `gitignored`, `no-secrets-at-rest`, retention bounded; enum `data_class ∈ {trusted,untrusted,derived}` no tool-record → vira mais um hard-filter no gate do P1 | **S** | — |

## §3 — A ameaça competitiva (Anthropic ship-by-default) — e a defesa

**Plausível e mortal SE o produto for "lista curada".** Mas a Anthropic curaria *os tools dela no
marketplace dela* — nunca **cross-ecosystem, security-gated, multi-harness** (o conflito C1 não some
porque a Anthropic só ouve a Anthropic). **O moat não é o catálogo; é o `conflict-graph + AgentShield
+ slot-adapter` que valem ATRAVÉS de marketplaces.** Posicionar como o **"Switzerland do agentic
tooling"** (complemento, não concorrente) e **shipar o conflict-checker antes** que "curadoria" vire
commodity de plataforma. Velocidade > defesa.

## §4 — O produto focado (o que fica, o que sai)

> **MAOS Agora (1 frase):** *"você diz o que quer fazer, e ele instala a ferramenta agêntica certa —
> só ela, sem quebrar o resto."*

- **FICA (o MVP = o produto, não um teste):** `prose-intent → entrevista (≤3 Qs) → setup seguro` +
  um **registry read-only com 15–20 entradas curadas à mão** (what/when/`conflicts_with`) + o
  **conflict-report**. O "no" embutido (reject-by-default) **é a feature**.
- **CORTA agora (ganha-se depois):** integrator inbound · contribution-gatekeeper · console-gating
  com dentes "completo" · distributor-hardening · slot-adapter de 1ª classe · WAVEs 5–10 · os títulos
  "de-facto MoE OS" / "front-door do commons".
- **Constrói em paralelo (barato, destrava o resto):** o **gating-seam** (P1, ~1 PR) — sem ele o
  registry é catálogo advisory; com ele, o "no" é real.

## §5 — Recomendação revisada (converge)

1. **Ratificar ADR-006** (núcleo atômico).
2. **ADR-007 → "Exploratory / Draft Vision"** — foco, não recuo (a plataforma é o destino, não a premissa).
3. **Shipar o experimento mais barato JÁ:** o **conflict-checker single-input** (1 dia) + o nosso
   stack como case, no Discord do Claude Code / r/ClaudeAI. Métrica = quantos colam *o stack deles*.
4. **Em paralelo (1 PR cada, agendáveis):** gating-seam (P1) · fixture→floor→required (P2) · split do
   registry (P5) · data_class+data-handling (P8). Adiar CTS scorer (P7).
5. **Earn, don't declare:** a identidade "MAOS Agora / plataforma" se ratifica quando houver *pull* +
   1ª integração real provando o gate.

## §6 — Reject-log (o que o debate DERRUBOU da crítica)
- ❌ *"Teeth = maior build-risk"* → **derrubado:** é PR S/M (~25-40 linhas); o risco era escopo não-instanciado.
- ❌ *"Paradoxo do curador sem tração"* → **derrubado:** confiança de segurança é **falsificável** (o artefato prova-se), não reputacional.
- ❌ *"Sucesso quebra o modelo de 2 pessoas"* → **reenquadrado:** é o **flywheel** AI-native (fila submetida → moat de dados), não ameaça — *desde que os dentes existam*.
- ⚠️ *Mantido da crítica:* "porta antes da fechadura" (P2), a contradição do registry (P5), o over-eng do CTS (P7), e o **rebaixar ADR-007** (agora como FOCO).

---
**Conclusão:** a crítica não matou o projeto — **afiou-o**. Sai uma plataforma inflada; entra um
produto de uma frase, verdadeiro hoje, barato de provar, e com um caminho honesto para *virar* a
plataforma se o mercado vier. Todo problema tem solução; a melhor é **focar**.
