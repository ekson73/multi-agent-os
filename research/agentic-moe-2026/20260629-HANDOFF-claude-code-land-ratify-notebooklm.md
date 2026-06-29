---
title: "HANDOFF-as-prompt → Claude Code · land + ratify + notebooklm"
date: "2026-06-29"
from: "Claude (Cowork) — research/decision session (Loops 1–4 converged, DEFER@n*)"
to: "Claude Code (Opus, inside ~/Projects/multi-agent-os)"
intent: "Execute the operator-dispositioned residue of the agentic-moe-2026 goal-loop: land the stranded work, ratify ADR-006 + the name, harden supply-chain, park R2 behind dogfood, and produce the human-comprehension NotebookLM kit."
governance: "ADR-004 GitHub-Flow · [C04] worktree-always · [C07] commit/PR/merge flow · COWORK-AUTONOMY-POLICY carve-outs · git-governance handoff 2026-06-28"
lang: "prose pt-BR · identifiers/code/commits en-US"
---

# HANDOFF → Claude Code — finalize the agentic-moe-2026 goal-loop

> **Como usar:** cole este prompt inteiro numa sessão **Claude Code** aberta na raiz de
> `~/Projects/multi-agent-os`. Ele é auto-contido. Execute os blocos **na ordem T1→T8**.
> Toda escrita nasce em **worktree** ([C04]); gates [C07] verdes antes de cada commit;
> **merge→main = HITL** (peça meu OK explícito antes do squash-merge).

## 0 · Contexto (o que aconteceu antes de você)

Uma sessão Cowork rodou 4 loops de pesquisa/decisão (`--goal-n-loop`) sobre absorver o
`agentic-moe-2026` como **MAOS Hub** nativo. Resultado, já convergido (não re-debata):

- **Loop 2 (BUILD):** o **gating-seam** foi construído e **test-provado** (0-regressão).
- **Loop 3 (DEMAND):** a demanda bifurcou — a dor existe (prior 0.45→0.68), mas adoção é HARD.
- **Loop 4 (v3-canônico):** score 6-fatores → agent-doable **0.79** / full-goal **0.71** (binding=`certainty`) → **DEFER@n*** (o resíduo é ato-humano, não cognição).

O operador (Emilson / ekson73) **dispositou** os 7 HITLs. Este handoff os executa. **Fonte da verdade**
do raciocínio: `research/agentic-moe-2026/20260628-goal-loop-closure.md` (Loops 1–4) +
`20260628-{critical-analysis,solutions-debate}.md`.

## 1 · Estado na chegada (verifique antes de tocar)

```bash
git -C ~/Projects/multi-agent-os status --short      # ~12 arquivos não-commitados em main
git worktree list                                    # main + 2 prunable (rabat · claude/ecstatic-raman)
ls -la .git/index.lock 2>/dev/null                   # lock órfão de 13:03 (0 byte) — ver T1
git log --oneline -1                                 # 8224e07 = #176 (ADR-006/007 [Proposed])
```

**Os 12 arquivos não-commitados** (autorados pela Cowork, pré-validados — `validate-plugin.sh` PASSED,
seam compila, 16/16 testes):
- **Build:** `mcp-tools/maos-mcp-hub/lib/gateway/{policy.py,conflicts.yaml,router.py}` + `mcp-tools/maos-mcp-hub/tests/test_gateway_policy.py`
- **Docs:** `research/agentic-moe-2026/20260628-{critical-analysis,solutions-debate,goal-loop-closure}.md` + `20260629-demand-probe-post.md`
- **Edições:** `docs/adrs/ADR-007-…md` (demoção Draft-frozen) + `research/agentic-moe-2026/20260627-notebooklm-{exec,source-digest,tech}-prompt.md`
- **Apoio (não no commit do seam, mas no repo):** `research/agentic-moe-2026/PR-body.md` (= o `--body-file` da PR) + ESTE handoff.

---

## T1 · Lock órfão — diagnosticar (read-only) → remover só se stale

> Regra [git-governance]: **nunca `rm` cego**. O holder pode ser o `com.apple.Virtualization`
> (fd read-only `…r` = falso-positivo), não git.

```bash
lsof .git/index.lock 2>/dev/null            # com.apple…*r = falso-positivo; se aparecer "git" → PARE
pgrep -fl '[g]it ' || echo "nenhum git vivo"
stat -f '%Sm' .git/index.lock               # mtime congelado (horas) + sem git vivo => STALE
rm -f .git/index.lock                        # SÓ se stale
```
**DoD:** `.git/index.lock` ausente **ou** justificado-vivo (então aguarde o git terminar).

---

## T2 · Landing dos 12 arquivos (worktree [C04] + gates [C07] → PR → merge HITL)

O script **já corrigido** vive em `research/agentic-moe-2026/20260628-goal-loop-closure.md`
(seção "## Script (operator-manual git · [C04] worktree-based · [C07] gates …)"). Resumo:

```bash
cd ~/Projects/multi-agent-os
git stash push -u -m maos-agora-loop-closure
git worktree add .worktrees/eko-loop-closure -b feature/EKO-XX-maos-agora-land origin/main
cd .worktrees/eko-loop-closure && git stash pop
# gates C07 verdes ANTES do commit:
gitleaks detect --no-banner && openspec validate --specs && bash tests/validate-plugin.sh
# (rode também a suíte do gateway p/ confirmar 0-regressão:)
( cd mcp-tools/maos-mcp-hub && python -m pytest tests/ -q )   # esperado: 192 pass / 3 pré-existentes
# stage EXPLÍCITO (nunca git add -A) dos 12 + ADR-006 (T3) + Anima/rule (T4) quando prontos:
git add -- docs/adrs/ADR-007-curated-community-integration-platform.md \
        research/agentic-moe-2026/20260628-critical-analysis.md \
        research/agentic-moe-2026/20260628-solutions-debate.md \
        research/agentic-moe-2026/20260628-goal-loop-closure.md \
        research/agentic-moe-2026/20260629-demand-probe-post.md \
        research/agentic-moe-2026/20260629-HANDOFF-claude-code-land-ratify-notebooklm.md \
        research/agentic-moe-2026/PR-body.md \
        research/agentic-moe-2026/20260627-notebooklm-*.md \
        mcp-tools/maos-mcp-hub/lib/gateway/policy.py \
        mcp-tools/maos-mcp-hub/lib/gateway/conflicts.yaml \
        mcp-tools/maos-mcp-hub/lib/gateway/router.py \
        mcp-tools/maos-mcp-hub/tests/test_gateway_policy.py
git commit -m "feat(maos-hub): additive gating-seam (policy=None passthrough) + 16 conflict edges + 16 tests (0-regression)" \
           -m "docs(goal-loop): critical-analysis + solutions-debate + closure (Loops 1-4) + demand-probe + handoff; demote ADR-007 to Draft(frozen)" \
           -m "Co-Authored-By: Claude <noreply@anthropic.com>"
git push -u origin HEAD
gh pr create --base main --title "feat(maos-hub): gating-seam + goal-loop closure (Loops 1-4)" \
             --body-file research/agentic-moe-2026/PR-body.md
# PDCA até convergência (Amazon Q + CI verdes; Snyk ERROR≠finding; CodeRabbit PENDING≠blocker)
# → quando verde, peça meu OK e: gh pr merge --squash --delete-branch
```
> **Decisão de escopo:** você pode **dobrar T3 (ADR-006 Accepted) e T4 (Anima rule) no MESMO PR**
> (recomendado — uma "feature de fechamento") OU separar em PRs próprios se preferir revisão atômica.
> Use seu julgamento; ambos respeitam ADR-004.

**DoD:** PR aberta com os 12 (+ T3/T4) · gates verdes · 192 pass/3 pré-existentes confirmado ·
merge **só após meu OK** · branch deletada · worktree removida.

---

## T3 · Ratificar ADR-006 — **Accepted** (operador aprovou: "absorver aprovado")

```bash
# em docs/adrs/ADR-006-ath-moe-hub-adoption.md:
#   - **Status**: Proposed (…)   →   - **Status**: **Accepted** (ratified by operator ekson73, 2026-06-29)
```
Propague a ratificação (boy-scout, mesmas edições no PR de T2):
- **`CHANGELOG.md`** — mova a entrada ADR-006 de "**proposed**" para ratificada (Accepted) no `[Unreleased]`.
- **`docs/adrs/ADR-006-…md`** — adicione 1 linha em Consequences: "Ratified 2026-06-29; WAVE-0 (gating-seam) já entregue neste mesmo ciclo (ver `goal-loop-closure` Loop 2)."
- **`research/agentic-moe-2026/README.md`** — troque "proposed, pending HITL ratification" → "**ratified (ADR-006 Accepted 2026-06-29)**; ATH realizado como MAOS Hub".
- **NÃO** mexa no ADR-007 (segue **Draft-frozen** — só ADR-006 foi ratificado).
- **Ative como guidance** (não mais "proposto"): o **single-conductor invariant** + o risco de **colisão always-on** (não co-residir com ECC/superpowers/gstack/BASE — rotear, nunca empilhar).

**DoD:** ADR-006 Status=Accepted · CHANGELOG/README propagados · ADR-007 intocado · invariantes ativos.

---

## T4 · "Always Anima's Call" — naming-authority rule + enhance Anima

**Decisão do operador:** o nome **`MAOS Agora`** está **ratificado** — foi *call da Anima*. E mais:
naming é, daqui pra frente, **autoridade da Anima** (capacidade + autoridade + autorização de decisão),
removendo o gargalo burocrático humano. Codifique isto em **3 lugares** + **enhance** a Anima.

### T4.1 — Rule (texto pronto p/ colocar em governança + memórias)
Crie `.claude/rules/naming-authority.md` (e referencie em `CLAUDE.md` §memórias + `AGENTS.md` se houver):
```markdown
# Naming Authority — "Always Anima's Call"  [C-naming]
- TODA decisão de nomeação (diretórios · arquivos · módulos · identificadores · agents · skills ·
  servidores · DB/schema/tabela · protocolos · acrônimos · projetos · marcas · artefatos · prompts)
  é DELEGADA ao agent/skill `anima`, que detém capacidade, autoridade e autorização para DECIDIR o nome.
- Razão: nomear é decisão recorrente e pesquisável; rotear por ratificação humana desperdiça tempo.
  A Anima foi criada exatamente para owns isto — research-first, 12 aspectos de correção + 4 de
  ressonância, UMA decisão soberana + rationale + runner-up rejeitado.
- Fronteira de escopo: a Anima decide o NOME — não ganha autoridade além de nomear. O humano pode
  fazer override post-hoc, mas o default é **Anima-autônoma (sem gate de pré-aprovação)**.
- Carve-out autorizado pelo operador: naming SAI do HUMAN_DOMAIN e passa a ser Anima-autônomo.
- Precedente ratificado: `MAOS Agora` (nome do projeto) foi call da Anima e fica ratificado por esta rule.
```
- Em `CLAUDE.md` (memória de trabalho): 1 linha no índice de rules → "naming = Always Anima's Call ([C-naming])".
- Atualize os artefatos que marcam "⚠️ pendente ratificação" do nome (`ADR-007`, `CHANGELOG`, MVV,
  `notebooklm-*`) → "**`MAOS Agora` — ratificado (Anima's call, [C-naming], 2026-06-29)**".

### T4.2 — Enhance Anima (mais high-score: confidence + capabilities + awareness + holisticity)
Use **`maos:agentic-tool-trainer`** (ou `forge`) para evoluir o profile — não hand-hack:
- **Autoridade explícita:** na description/frontmatter da Anima, afirmar o carve-out [C-naming]
  (Anima decide, sem HITL gate) + a fronteira de escopo (só naming).
- **Confidence derivado:** Anima emite um `naming_confidence` (research-coverage × aspect-fit) e só
  escala em **genuíno data-gap** (mantém o comportamento atual, agora formalizado).
- **Holisticidade:** garanta register-classification (machine/agent/human) + os sub-adapters de domínio
  (databases · agentic-tools · brand) + o self-extending sub-KB; reforce **web-research-first obrigatório**.
- **Treino:** adicione `MAOS Agora` como caso-âncora resolvido (a *ágora* grega = encontro + mercado
  vetado + discurso = as 3 faces) no sub-KB da Anima.
- Rode o `agentic-tool-evaluator` antes/depois p/ provar o uplift (KPI), e registre via `dogfood-ledger`.

**DoD:** `naming-authority.md` criado + referenciado · artefatos do nome atualizados · Anima enhanced
(profile + KB + confidence) com eval before/after registrado.

---

## T5 · R2 demand-probe — **ADIADO** (dogfood-first) → task BLOQUEADA

**Decisão do operador:** **não postar ao mundo ainda.** Primeiro **implementar · simular · testar ·
dogfood** — garantir utilidade para nós mesmos antes de apresentar. Portanto:

- **NÃO** poste `20260629-demand-probe-post.md` em lugar nenhum agora. Ele fica como munição pronta.
- **Crie a task BLOQUEADA** no tracker (Linear EKO — L4 routing; ou `TASKS.md` se preferir local):
  - **Título:** `[exp] R2 demand-probe — post conflict-checker (Discord/r-ClaudeAI)`
  - **Status:** `Blocked`
  - **Blocked-by:** `[dogfood] MAOS Agora conflict-checker — implement + simulate + self-use proven`
  - **Unblock-criteria (DoR p/ postar):** o conflict-checker single-input roda end-to-end **no nosso
    próprio stack** (26 tools, 6 colisões reproduzidas via `conflicts.yaml`), gera o report, e **nós o
    usamos de verdade** ≥1 ciclo (dogfood-ledger). Só então o kill-criterion pré-registrado do
    `demand-probe-post.md` vale para o mundo.
- **Crie a task de dogfood** (a que bloqueia): `[dogfood] conflict-checker self-use` — implementar o
  checker (consumindo o `policy.py`/`conflicts.yaml` já existentes), simular com o nosso stack, provar
  utilidade interna. Esta é a **próxima feature real** após o landing.

**DoD:** task R2 registrada como `Blocked` por `[dogfood]` · post NÃO publicado · unblock-criteria explícito.

---

## T6 · R4-ops — endurecer o piso de supply-chain (dry-run → exit-code:1 → required)

> Em `.github/workflows/supply-chain-sentinel.yml` o Trivy hoje é `exit-code: "0"` (decorativo).

1. **Dry-run primeiro** (não red-walle o repo às cegas): rode Trivy fs localmente/CI e cheque se há CVE
   pré-existente que bloquearia. Resolva/allowliste o que for ruído antes de armar.
2. **Arme:** `exit-code: "0"` → `"1"` + `gate_on: vuln,secret` (mantenha `pip-audit --strict` e `gitleaks`).
3. **Required (por ÚLTIMO, admin):** torne o job `trivy-fs` **required** no branch-protection de `main`
   (precisa de **repo-admin** — é seu, peça-me se faltar permissão).

**DoD:** dry-run limpo documentado · Trivy bloqueante · job required · um PR de teste prova que um
fixture known-bad (secret plantado) **falha** o gate (a fechadura agora tranca).

---

## T7 · Boy-scout — podar as 2 worktrees prunable

```bash
# de DENTRO de uma worktree (no raiz os hooks bloqueiam branch-ops):
git worktree prune
git worktree remove .worktrees/eko-loop-closure        # a sua, após o merge de T2
# as 2 antigas (rabat · claude/ecstatic-raman) — confirme abandono, então:
git worktree remove --force <path-da-worktree>          # só se realmente órfãs/squash-merged
```
**DoD:** `git worktree list` = só `main` (+ ativas legítimas) · nenhuma `prunable` órfã.

---

## T8 · NotebookLM — kit de compreensão humana (exec + técnico)

**Objetivo do operador:** a `--audience` **humana** ganhar a **melhor compreensão possível** do projeto:
*o que é · o que faz · o que significa · impacto na produtividade · impacto na comunidade · como usar ·*
*conceitos necessários.* Duas visões: **executiva** e **técnica**.

Use a skill **`maos:notebooklm`** (roteia `notebooklm-py` CLI / `notebooklm-mcp-cli` / `@notebooklm-mcp`;
escolha a conta certa: pessoal/Vek):

1. **Criar notebook:** `"MAOS Agora — agentic-moe-2026 (Vek)"`.
2. **Upload de fontes** (a seleção curada está em `…-notebooklm-source-digest.md` §A/§C/§D):
   - Núcleo: o **digest** + `20260627-final-report.md`.
   - Suporte: `20260627-00-canonicalization.md` · `02-ntree-moe.md` · `03-orchestrator-hub.md`.
   - Evolução: `ADR-006` · `ADR-007` · `docs/vision/maos-integration-platform.md` ·
     `20260628-{critical-analysis,solutions-debate,goal-loop-closure}.md` · `20260629-demand-probe-post.md`.
   - **Não suba** o código (`*.py`/`*.yaml`) nem o PDF/HTML (redundantes) — cite como evidência.
3. **Rodar os prompts** (já prontos, com blocos 2026-06-29):
   - **Executivo:** `…-notebooklm-exec-prompt.md` → Audio Overview pt-BR ~10–12 min + Briefing Doc.
   - **Técnico:** `…-notebooklm-tech-prompt.md` → Audio Overview ~18–25 min + study-guide + Q&A.
4. **Gerar os MELHORES artefatos standalone** (além do áudio) — salve em `research/agentic-moe-2026/notebooklm-out/`:
   - **`exec-onepager.md`** (1 pág, zero jargão): o que é · por que importa p/ o Vek · impacto em
     produtividade (menos lock-in, menos token-tax, instalar-certo-sem-quebrar) · impacto na comunidade
     (front-door curado/seguro — *quando* ganho) · 3 próximos passos. Honesto: plataforma = destino, não fato.
   - **`tech-deepdive.md`**: o frame MoE (L0–L9) · o hub/gating-seam (`policy=None`=passthrough, 0-regressão)
     · roteamento N-Tree + incompatibilidades · o score 6-fatores · governança (C04/C07) · o que foi rejeitado.
   - **`how-to-use.md`**: como o operador usa hoje (o seam + o conflict-checker quando o dogfood T5 fechar).
5. **Honestidade obrigatória nos artefatos** (carregue do material): estrelas = ordem-de-grandeza datada;
   ADR-006 **Accepted**, ADR-007 **Draft-frozen**; R2 **adiado p/ dogfood**; nunca empilhar 2 maestros.

**DoD:** notebook criado · fontes subidas · Audio Overviews (exec+téc) gerados · 3 artefatos standalone
salvos em `notebooklm-out/` · tudo factualmente fiel às fontes.

---

## 9 · Ordem + DoD global

`T1 (lock) → T2 (land, espere meu OK p/ merge) → T3 (ADR-006 Accepted) + T4 (Anima) no mesmo PR →
T6 (R4) → T7 (prune) → T5 (registrar task bloqueada) → T8 (NotebookLM)`.

**Global DoD:** seam mergeado (após meu OK) · ADR-006 Accepted propagado · [C-naming] codificado +
Anima enhanced · R2 bloqueada-por-dogfood (não postada) · Trivy bloqueante+required · worktrees limpas ·
NotebookLM kit + artefatos exec/téc entregues · boy-scout (nada solto).

## 10 · Guard-rails (invioláveis — operator-auth NÃO dispensa)
- **Nunca** exponha secrets em log/output/commit (LGPD/compliance). **Sem** `--no-verify`/hook-skip. **Sem** force-push em protegida.
- **merge→main = HITL** — drive a PR até verde, **peça meu OK**, então squash-merge.
- **[C04]** toda escrita em worktree; **[C07]** gates verdes + stage explícito + Conventional + Co-Author.
- DRY/SSOT/KISS/YAGNI/ANTI-OVER-ENG/ANTI-THEATER. Exceção só com SDP-stamp.
- ADR-007 permanece **Draft-frozen**; R2 permanece **adiado** até o dogfood provar utilidade interna.

---
*Handoff gerado pela sessão Cowork (Loops 1–4 · DEFER@n*) · 2026-06-29 · cole no Claude Code e execute T1→T8.*
