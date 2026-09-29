---
description: PR governance unificado [C07+C12] — workflow de PRs e revisão
---

# PR Governance — Unified Workflow [C07+C12]

<!-- Auto-loaded rule | Version: 1.2.0 | 2026-07-01 -->
<!-- Replaces: pr-review-protocol.md (C07 v3.0), pr-email-review-loop.md (C12 v3.0) -->
<!-- References: ~/.claude/docs/git-worktree-protocol.md (C04 — full spec) -->

## Fundamental Rule

```
MANDATORY: Worktree -> Code -> LOCAL REVIEW -> Push -> PR -> Bot Review -> Merge -> Cleanup
FORBIDDEN: Merge without review | Push without local review | git checkout in main repo
SCOPE: All agents, all sessions, all repos
```

## Complete Lifecycle (12 steps)

```
PRE-PUSH:
  1.WORKTREE -> 2.CODE+COMMIT -> 3.LOCAL REVIEW -> 4.FIX+COMMIT (loop 3-4 until clean)

PUSH+PR:
  5.PUSH -> 6.PR CREATE -> 7.BOT REVIEW (optional 30min wait)

DECISION:
  8.ANALYZE -> MERGE | FIX+PUSH (loop 7-8) | PARTIAL+PUSH | ESCALATE

POST-MERGE:
  9.MERGE (método resolvido) -> 10.SYNC BASE BRANCH -> 11.AUDIT+ARCHIVE EMAILS -> 12.CLEANUP WORKTREE
```

---

## Step 1: Worktree (MANDATORY)

NEVER modify files without worktree sandbox. NEVER `git checkout`/`switch` in main repo.

```bash
# 1a. DECIDA A BASE ANTES DE CRIAR O WORKTREE.
#     Default do repo, OU uma base empilhada/não-default quando for a intenção.
#     `main` NUNCA é assumido: no inventário de 2026-09-17, `develop` é o default
#     em vários repos.
BASE_REF="${BASE_REF:-$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)}"
git ls-remote --exit-code --heads origin "$BASE_REF" >/dev/null || {
  echo "⛔ fail-closed: base '$BASE_REF' não existe em origin" >&2; exit 1; }

# 1b. Crie o worktree A PARTIR da base decidida (não do HEAD corrente).
#     ⚠️ O fetch é fail-closed. Se o remoto cair ou a base for apagada DEPOIS do
#     `ls-remote` acima, um fetch desprotegido falha mas o shell sem `errexit`
#     segue; havendo um `origin/$BASE_REF` ANTIGO em cache, o `worktree add`
#     sucede a partir do commit obsoleto e a revisão local obrigatória inspeciona
#     o diff errado. Aborte ANTES de criar o worktree.
git fetch -q origin "$BASE_REF" || {
  echo "⛔ fail-closed: fetch de '$BASE_REF' falhou; origin/$BASE_REF pode estar obsoleto" >&2
  exit 1; }
# ⚠️ Encadeie com `&&`. Se o `worktree add` falhar, o `cd` tambem falha e o
#    `git rev-parse --git-dir` abaixo resolve para o REPO PRINCIPAL — gravando
#    a base ali. Medido: `.git/BASE_REF` criado na raiz com valor errado,
#    contaminando toda sessao subsequente que leia a base persistida.
git worktree add .worktrees/{session-id}-{feature} -b {type}/{feature} "origin/$BASE_REF" \
  || { echo "⛔ fail-closed: worktree add falhou" >&2; exit 1; }
cd .worktrees/{session-id}-{feature} \
  || { echo "⛔ fail-closed: cd para o worktree falhou" >&2; exit 1; }

# 1c. PERSISTA a base no worktree — variável de shell NÃO sobrevive entre steps,
#     sessões ou agentes. Em worktree `.git` é ARQUIVO, não diretório: resolva o
#     git-dir real. O arquivo é local ao worktree e não versionado.
printf '%s\n' "$BASE_REF" > "$(git rev-parse --git-dir)/BASE_REF"
```

Steps posteriores releem a base assim — nunca reassumem `main`:

```bash
BASE_REF=$(cat "$(git rev-parse --git-dir)/BASE_REF" 2>/dev/null) || {
  echo "⛔ fail-closed: BASE_REF não persistida — recrie o worktree pelo Step 1" >&2; exit 1; }
```

Exceptions (ALL require documentation in commit/PR body):
  1. Read-only analysis (no file writes)
  2. Append-only to coordination files (MEMORY.md, plan files)
  3. EXPLICIT user bypass: the user LITERALLY says "skip worktree", "edit directly",
     "don't use worktree", or equivalent DIRECT instruction to bypass the protocol.

WHAT IS NOT AN EXCEPTION:
  - "Fix this" / "Resolve the gaps" / "Implement X" → these are TASK instructions,
    not PROTOCOL bypasses. The task goes through the worktree. Always.
  - Convenience ("it's faster without worktree") → not a valid reason.
  - Scope ("it's just docs") → not a valid reason.
  - Volume ("it's only 3 files") → not a valid reason.

DECISION CHECKPOINT (mandatory before any file Edit/Write):
  "Am I in a worktree?"
    → YES: proceed
    → NO: "Did the user LITERALLY say to skip worktree?"
      → YES (with exact quote): proceed + document exception
      → NO: STOP. Create worktree first. Do NOT rationalize.

## Step 2: Code + Commit

```bash
# Work, then commit
git add <files>
git commit -m "{type}({scope}): {description}"
```

## Step 3: Local CLI Review (MANDATORY before push)

⚠️ **A base NUNCA é fixa.** `main` não é o default de todo repo — no inventário de 2026-09-17,
`develop` é o default em vários.

⚠️ **Este step roda ANTES do push/PR**, então `gh pr view` ainda **não tem PR para consultar**.
A base é um **parâmetro do worktree**, estabelecido no Step 1 e validado aqui — nunca deduzido
de um PR inexistente.

```bash
# Resolva a base SEM reassumir `main` e SEM confiar em variável de shell (ela não
# sobrevive entre steps, sessões ou agentes).
#
# ⚠️ ADOÇÃO EM WORKTREE PRÉ-EXISTENTE: worktrees criados antes desta regra não têm o
#    arquivo do Step 1c. NUNCA force recriar um worktree com WIP — adote-o pela ordem
#    abaixo e persista a base depois de validada.
GITDIR=$(git rev-parse --git-dir)

# ⚠️ Sob `set -e`, uma atribuição por substituição de comando herda o status do comando:
#    `V=$(cat inexistente)` ABORTA o script e torna os fallbacks inalcançáveis
#    (verificado: exit=1, o eco seguinte nunca executa). Guarde TODA etapa com `|| …`.

# 1º) arquivo persistido pelo Step 1c
BASE_REF=$(cat "$GITDIR/BASE_REF" 2>/dev/null) || BASE_REF=""

# 2º) BASE_REF explícito do chamador (adoção manual de worktree legado)
[ -n "$BASE_REF" ] || BASE_REF="${BASE_REF_OVERRIDE:-}"

# 3º) base do PR, quando já existe PR para esta branch
[ -n "$BASE_REF" ] || BASE_REF=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null) || BASE_REF=""

# 4º) nenhuma fonte → fail-closed. NÃO caia no default: um PR empilhado seria
#     revisado contra a base errada em silêncio.
[ -n "$BASE_REF" ] || {
  echo "⛔ fail-closed: base indeterminada. Passe BASE_REF_OVERRIDE=<branch> ou abra o PR" >&2
  exit 1; }

# Valide contra o remoto e persista para os próximos steps
git ls-remote --exit-code --heads origin "$BASE_REF" >/dev/null || {
  echo "⛔ fail-closed: base '$BASE_REF' não existe em origin" >&2; exit 1; }
printf '%s\n' "$BASE_REF" > "$GITDIR/BASE_REF"

# PRIMARY: CodeRabbit CLI (~30s-5min; rate-limited ~1/25min free plan)
# ⚠️ `--plain` FOI REMOVIDO (verificado 2026-09-17 na 0.7.8; a CLI auto-atualiza em
#    background, então a flag pode sumir sem aviso). Texto plano já é o modo default.
#    Para saída estruturada consumível por agente use `--agent`.
if coderabbit review --base "$BASE_REF" --config CLAUDE.md; then
  PRIMARY_OK=1
else
  PRIMARY_OK=0; echo "⚠️  CodeRabbit falhou — caindo para o fallback" >&2
fi

# FALLBACK: Qodo CLI — SÓ quando o primário falha. Rodá-lo em sequência incondicional
# faz um review bem-sucedido do CodeRabbit ser derrubado por `repo_not_connected`.
# ⚠️ `qodo --ci -y "<prompt>"` NÃO EXISTE MAIS (verificado 2026-09-17: "error: unknown
#    option '--ci'"). A CLI passou a expor o subcomando `review`.
# ⚠️ Exige o repo CONECTADO ao workspace Qodo; senão falha com `repo_not_connected`.
REVIEW_OK=$PRIMARY_OK
if [ "$PRIMARY_OK" -eq 0 ]; then
  # --base tambem aqui: sem ele o Qodo compara contra a default do repo,
  # e um PR empilhado seria revisado contra a base errada.
  if qodo review --base "$BASE_REF"; then REVIEW_OK=1; else REVIEW_OK=0; fi
fi

# ⛔ AMBOS indisponíveis não é "siga em frente": é ESTADO BLOQUEANTE. Registrar o
# erro e prosseguir é o fail-open que a política DIY-review existe para impedir.
# Só `DIY_REVIEW_DONE=1` — passagem DIY EXECUTADA **e** divulgada no corpo do PR
# (qual primário faltou e por quê) — libera os steps seguintes.
if [ "$REVIEW_OK" -eq 0 ]; then
  [ "${DIY_REVIEW_DONE:-0}" -eq 1 ] || {
    echo "⛔ fail-closed: nenhum reviewer local disponível e a passagem DIY não foi" >&2
    echo "   executada/divulgada. Execute-a e exporte DIY_REVIEW_DONE=1." >&2
    exit 1; }
  echo "ℹ️  prosseguindo sob revisão DIY — divulgação obrigatória no corpo do PR" >&2
fi
# O passe DIY NUNCA substitui o veredito de um primário exigido pelo repo.
```

**Após abrir o PR (Step 6+), afirme que a base revisada é a base real:**

```bash
# ⚠️ Step 6+ costuma rodar em shell NOVO: `BASE_REF` não sobrevive entre steps (Step 3).
# Recarregue da persistência ANTES de comparar, senão a asserção rejeita todo PR válido.
GITDIR=$(git rev-parse --git-dir)
BASE_REF=$(cat "$GITDIR/BASE_REF" 2>/dev/null) || BASE_REF=""
[ -n "$BASE_REF" ] || {
  echo "⛔ fail-closed: BASE_REF não persistida — recrie o worktree pelo Step 1" >&2; exit 1; }

PR_BASE=$(gh pr view <N> --json baseRefName -q .baseRefName)
[ "$PR_BASE" = "$BASE_REF" ] || {
  echo "⛔ revisão feita contra '$BASE_REF' mas o PR aponta '$PR_BASE' — re-revise" >&2; exit 1; }
```

### Review Classification

| Category | Priority | Action |
|----------|----------|--------|
| Security | P0 | Fix immediately |
| Bug/Correctness | P1 | Fix |
| Reliability | P1 | Fix |
| Cosmetic/Doc | P2 | Fix if trivial |
| False positive | Skip | Document justification |
| Informational | Skip | Ignore |

## Step 4: Fix + Commit (loop with Step 3)

```bash
# Fix P0/P1/P2 issues found in review
git add <fixed-files>
git commit -m "fix: address local review findings"
# Repeat Step 3 until clean
```

## Step 5: Push Branch

```bash
git push -u origin {branch-name}
```

## Step 6: Create PR

```bash
# ⚠️ Recarregue ANTES de usar: o Step 6 costuma rodar em shell NOVO, onde
#    `$BASE_REF` esta vazio. Passar vazio faz `--base ""` — ou, pior, o gh
#    cai na branch default e o PR nasce contra a base errada.
GITDIR=$(git rev-parse --git-dir)
BASE_REF=$(cat "$GITDIR/BASE_REF" 2>/dev/null) || BASE_REF=""
[ -n "$BASE_REF" ] || {
  echo "⛔ fail-closed: BASE_REF não persistida — recrie o worktree pelo Step 1" >&2
  exit 1; }

# --base OBRIGATORIO: sem ele o gh usa a branch DEFAULT do repo, e um PR
# empilhado (base != default) seria aberto contra a base errada, invalidando
# a revisao do Step 3 que usou $BASE_REF.
gh pr create --base "$BASE_REF" \
  --title "{type}({scope}): {description}" --body "..."
```

NEVER merge directly. Always via PR.

## Step 7: Bot Review (OPTIONAL wait)

TTL: 30 minutes. Optional if local review was executed.

⛔ **Contar threads NÃO é auditar a revisão.** Um achado *outside diff range* — quando o
reviewer aponta um arquivo/linha fora do diff — **não cria thread inline**. `0 threads
abertas` é então perfeitamente compatível com achados válidos e não endereçados.
Medido neste repositório: um veredito anunciava *"Actionable comments posted: 2"* e a
contagem de threads era zero; auditando os corpos apareceram **4** achados reais, entre
eles uma perda de dados silenciosa em código executável.

```bash
# (a0) CAPTURE o head ANTES de ler qualquer coisa. Tudo abaixo audita ESTE
#      commit; persistir depois da leitura gravaria um head que chegou DURANTE
#      a auditoria e nunca foi olhado.
HEAD_AT_START=$(gh pr view <N> --json headRefOid --jq .headRefOid) || {
  echo "⛔ fail-closed: não consegui ler o head" >&2; exit 1; }

# (a) Threads inline — necessário, NÃO suficiente.
gh pr view <N> --json comments,reviews,statusCheckRollup

# (b) CORPO COMPLETO de TODA revisão — inclusive vereditos OBSOLETOS, cujos
#     achados continuam válidos até serem endereçados ou refutados.
#     ⚠️ O endpoint pagina em 30: sem `--paginate --slurp` + `add`, as revisões
#     da 2ª página somem em silêncio — justamente num PR longo, onde mais importa.
#     `--slurp` não convive com `--jq`, então agregue num pipe separado.
REVIEWS=$(gh api "repos/{owner}/{repo}/pulls/<N>/reviews" --paginate --slurp) || {
  echo "⛔ fail-closed: não consegui ler as revisões" >&2; exit 1; }
printf '%s' "$REVIEWS" | jq -r '(add // [])[]|"\n=== \(.state) @\(.user.login) \(.commit_id[0:8])\n\(.body)"'

# (c) COMENTÁRIOS INLINE — endpoint SEPARADO. `/reviews` devolve os registros de
#     revisão; um achado postado inline SEM repetição no corpo não aparece ali.
#     Este mesmo workflow já usava `/pulls/{N}/comments`, mas só no Step 11, DEPOIS
#     do merge. Medido nesta própria sessão: a auditoria de corpos reportou os
#     achados do CodeRabbit e a contagem dizia ZERO threads, enquanto havia 12
#     threads inline abertas de outro revisor — 9 achados únicos, 6 deles P1.
COMMENTS=$(gh api "repos/{owner}/{repo}/pulls/<N>/comments" --paginate --slurp) || {
  echo "⛔ fail-closed: não consegui ler os comentários inline" >&2; exit 1; }
printf '%s' "$COMMENTS" | jq -r '(add // [])[]|"\n--- \(.path):\(.line // .original_line) @\(.user.login)\n\(.body)"'

# (d) Conferência: o corpo declara quantos achados acionáveis? Bate com o que
#     você dispôs? Divergência = auditoria incompleta, não ruído.
#     ⚠️ `|| true`: sem match o grep sai 1 e, sob `set -e`, abortaria o passo
#     num conjunto de revisões LIMPO — o caso bom viraria falha.
printf '%s' "$REVIEWS" | jq -r '(add // [])[].body' \
  | grep -iE 'actionable comments|outside diff' || true

# (e) RECONFIRA e só então persista. Se o head mudou entre (a0) e aqui, houve
#     push DURANTE a auditoria: o que você leu não descreve o commit atual, e o
#     commit atual não foi auditado. Não há pin correto a gravar — volte ao 7.
HEAD_NOW=$(gh pr view <N> --json headRefOid --jq .headRefOid) || {
  echo "⛔ fail-closed: não consegui reconferir o head" >&2; exit 1; }
[ "$HEAD_NOW" = "$HEAD_AT_START" ] || {
  echo "⛔ head mudou durante a auditoria ($HEAD_AT_START -> $HEAD_NOW): refaça o Step 7" >&2
  exit 1; }
printf '%s\n' "$HEAD_AT_START" > "$(git rev-parse --git-dir)/REVIEWED_OID"
```

Reviewers: Copilot, Qodo, CodeRabbit (bots) | GitHub UI (human) | Claude agent (AI)

## Step 8: Analyze Review + Decide

**Entrada obrigatória: 7(b) corpos E 7(c) inline — os dois endpoints.** Dispor de cada achado do
corpo é pré-condição do merge — o Step 11 audita de novo, mas **depois** do merge; confiar
só nele deixa o defeito entrar.

| Classification | Action |
|----------------|--------|
| Approved | Merge (Step 9) |
| Valid correction | Fix in worktree, commit, push, loop Step 7-8 |
| Partially valid | Apply valid items, document rejected with justification, push, loop |
| Disagree (justified) | Merge + document justification via `gh pr comment` |
| Inconclusive | Escalate to human (do NOT merge) |
| **Achado de corpo (7b) ou inline (7c) não disposto** | ⛔ **NÃO mergeie** — audite os dois endpoints antes de qualquer decisão |

> **Per-finding arbitration (bot findings)**: when the review feedback is a reviewer-BOT finding
> (Copilot / Qodo / CodeRabbit / Amazon Q / gitleaks / Snyk / Semgrep / Trivy), route EACH finding to
> `skills/bot-finding-arbiter` (*Praetor*) — the default handler that elevates this 5-way menu to a
> per-finding 7-way disposition (+ the teach-the-bot edict when the bot is verifiably wrong).
> See § Bot-Config Correction Discipline below for the binding policy.

## Step 9: Merge

⚠️ **NUNCA use `--merge` incondicionalmente.** O método é **resolvido a partir da autoridade
local do repositório**. Ratificado pelo operador em 2026-09-17, após inventário read-only dos
46 repositórios ativos (`vek-im` + `ekson73`).

**Eixo 1 — política declarada** (o que o repo *diz*). Procure cláusula normativa em
`docs/adrs/*`, `CONTRIBUTING.md`, `AGENTS.md`, `CLAUDE.md`.

- ⛔ **Leia a cláusula, não conte a palavra.** `squash` aparece tanto em *"use squash-merge"*
  quanto em *"por que merge commit, **não** squash"*. Contagem de ocorrências classifica ao
  contrário — defeito real, medido em `vks-jss-sales-api`.
- No inventário, **5 de 46** repos tinham declaração explícita e **41 não tinham nenhuma**.
  Snapshot é ponto de partida, **não** substituto da verificação: **sempre reconfira o repo
  em que você está operando.**

**Eixo 2 — capacidade habilitada** (o que o repo *permite*): `allow_merge_commit`,
`allow_squash_merge` **e `allow_rebase_merge`** + rulesets. Habilitar vários métodos é
capacidade legítima, **não** é declaração de política. `rules/agent-scm.md` modela os
**três** métodos — a resolução aqui cobre os três, não dois.

⚠️ **Flag do repo não basta: a proteção da branch-alvo pode invalidá-la.** Com
`required_linear_history` na base, o GitHub **rejeita merge commit** ainda que
`allow_merge_commit=true`. E há **dois sistemas coexistentes** — *rulesets* e *branch
protection clássica*: inspecionar só um deixa o outro passar. Capacidade efetiva =
flag do repo **∧** ausência de linear-history em **ambos**.

⛔ **Falha de inspeção é fail-closed, nunca "não há restrição".** Mapear erro de
auth/rede/endpoint para zero recria o fail-open que este gate existe para eliminar.
Medido: ambos endpoints devolvem **exit=1** e escrevem o **JSON de erro em stdout**.

```bash
# Base FRESCA: o Step 9 pode rodar em shell novo, onde $BASE_REF não existe.
BASE_REF=$(gh pr view <N> --json baseRefName -q .baseRefName) || {
  echo "⛔ fail-closed: não consegui resolver a base do PR" >&2; exit 1; }

CAP=$(gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed) || {
  echo "⛔ fail-closed: não consegui ler as capacidades do repo" >&2; exit 1; }

# ⚠️ Codifique a base como UM parâmetro de path. Uma base com barra
#    (`release/1.0`) interpolada crua vira `/branches/release/1.0` e a API
#    devolve `[]` com exit 0 — medido. Isso é FALHA ABERTA: "nenhuma regra"
#    autorizaria `--merge`. Não é fail-closed; é o pior caso.
BR_ENC=$(printf '%s' "$BASE_REF" | jq -sRr @uri)

# (a) Rulesets que incidem sobre a BASE (não sobre o repo inteiro).
#     ⚠️ O endpoint pagina em 30. `--paginate` sozinho emite UM array POR PÁGINA,
#     incompatível com o `jq` escalar abaixo; `--slurp` não convive com `--jq`
#     ("not supported", medido) — então agregue com `add` num pipe separado.
#     Sem isso, um `required_linear_history` na 2ª página passa despercebido.
RULES=$(gh api "repos/{owner}/{repo}/rules/branches/$BR_ENC" --paginate --slurp) || {
  echo "⛔ fail-closed: inspeção de rulesets falhou — não presuma ausência" >&2; exit 1; }
RLIN=$(printf '%s' "$RULES" | jq '[add[]?|select(.type=="required_linear_history")]|length') || {
  echo "⛔ fail-closed: agregação das páginas de rulesets falhou" >&2; exit 1; }

# (b) Branch protection CLÁSSICA. "Branch not protected" é ausência legítima (404);
#     qualquer outra falha é fail-closed.
if PROT=$(gh api "repos/{owner}/{repo}/branches/$BR_ENC/protection" 2>/dev/null); then
  PLIN=$(printf '%s' "$PROT" | jq -r '.required_linear_history.enabled // false')
elif printf '%s' "$PROT" | grep -q '"Branch not protected"'; then
  PLIN=false
else
  echo "⛔ fail-closed: inspeção de branch protection falhou em '$BASE_REF'" >&2; exit 1
fi

# (c) Rulesets `pull_request` podem RESTRINGIR os metodos permitidos na base via
#     `allowed_merge_methods`, independentemente das flags do repo.
#     ⚠️ Varias regras podem incidir ao mesmo tempo. A permissao efetiva e a
#     INTERSECAO de todas as listas: `add` (uniao) deixaria um metodo passar
#     porque ALGUM ruleset o permite, mesmo que outro o proiba. Ausencia de
#     lista = sem restricao; entao parta de "tudo" e va intersectando.
ALLOWED=$(printf '%s' "$RULES" | jq -r '
  ( [ add[]? | select(.type=="pull_request")
      | .parameters.allowed_merge_methods // empty ] ) as $lists
  | if ($lists|length) == 0 then "merge,squash,rebase"
    else ( $lists | map(map(ascii_downcase))
           | reduce .[] as $l (["merge","squash","rebase"]; . - (. - $l)) )
         | join(",")
    end') || {
  echo "⛔ fail-closed: leitura de allowed_merge_methods falhou" >&2; exit 1; }

# Capacidade EFETIVA por metodo = flag do repo ∧ lista branca efetiva
#                                 (∧ ausencia de linear-history, so p/ merge).
allowed_has() { printf '%s' ",$ALLOWED," | grep -q ",$1,"; }
MERGE_OK=$(printf '%s' "$CAP"  | jq -r '.mergeCommitAllowed')
SQUASH_OK=$(printf '%s' "$CAP" | jq -r '.squashMergeAllowed')
REBASE_OK=$(printf '%s' "$CAP" | jq -r '.rebaseMergeAllowed')

if [ "$RLIN" -gt 0 ] || [ "$PLIN" = true ]; then
  MERGE_OK=false
  echo "ℹ️  linear-history exigida em '$BASE_REF': merge commit indisponível" >&2
fi
allowed_has merge  || MERGE_OK=false
allowed_has squash || SQUASH_OK=false
allowed_has rebase || REBASE_OK=false
echo "ℹ️  capacidade efetiva em '$BASE_REF': merge=$MERGE_OK squash=$SQUASH_OK rebase=$REBASE_OK" >&2

# A tabela de resolucao abaixo consulta a flag EFETIVA do metodo escolhido
# (MERGE_OK/SQUASH_OK/REBASE_OK), nunca a flag crua do repo.
```

**Resolução:**

| Situação | Ação |
|---|---|
| Declaração explícita existe **e** o método está habilitado | use o método **declarado** |
| Método declarado está **desabilitado** no repo | ⛔ fail-closed: não mergeie, escale |
| **Nenhuma** declaração **e** `merge` habilitado | `--merge` (preserva ancestralidade) |
| **Nenhuma** declaração **e** `merge` **desabilitado** | ⛔ **fail-closed** — NÃO caia em outro método por conta própria: a ausência de política não autoriza escolher squash/rebase. Escale |
| **Fontes divergem** entre si | protocolo de conflito abaixo |

⚠️ O default **nunca** dispensa a verificação de capacidade. Um repo squash-only rejeitaria
`--merge`, e prescrever um comando que falha é pior que escalar.

**Protocolo de conflito entre fontes** (ratificado pelo operador; substitui hierarquia fixa):

1. **Recon + OODA**: compare **todas** as versões divergentes, citando arquivo e linha.
2. **Para o alvo atual**, vale a política **mais específica aplicável** (`AGENTS.md`
   aninhado / ADR de diretório → repo → global). Ela governa **este** merge e nada mais.
   ⛔ **Não corrija nenhuma outra fonte por conta disso.** Uma política global geral e
   uma exceção de subdiretório **não são divergência** — são escopos diferentes, ambos
   corretos, e reescrever qualquer um dos lados apaga a intenção. Só há o que corrigir
   quando duas fontes **do mesmo escopo** discordam (passo 3, drift real). Caso
   contrário, preserve as duas.
   ⚠️ A formulação anterior ("o escopo mais amplo decide") **invertia** a precedência de
   instrução escopada: um `AGENTS.md` de subdiretório exigindo `squash` seria sobrescrito
   por um default global permissivo, e a fonte específica ainda seria reescrita. Empate
   **no mesmo escopo** não se resolve por amplitude → HITL (passo 4).
3. A divergência é **claramente** drift (uma fonte ficou para trás) **e** você tem segurança
   para corrigir sozinho? → corrija **todos** os arquivos em conflito — inclusive outras regras
   auto-carregadas que complementem esta (ex. `rules/operational-workflow.md`) — e registre.
4. Caso contrário → **HITL**. Não mergeie sob conflito não resolvido.

### Step 9a — Resolver: materialize e PERSISTA o método (não mergeia)

Este sub-passo é a **fonte única** da resolução. Todo caller que precisa mergear por
conta própria (`skills/sync-to-git`, `docs/pr-review-protocol-spec`, provider-matrix
via REST) executa **9a** e depois carrega o resultado — nunca "roda o Step 9 inteiro
e exporta", porque exportar não atravessa shell e o Step 9 completo já mergearia,
produzindo um **segundo** merge.

```bash
# A tabela acima RESOLVE o método; materialize a resolução numa variável — um
# exemplo que só mostra três comandos não atribui nada, e quem referenciar
# `$MERGE_METHOD` depois aborta sob `set -u` (medido).
# ⚠️ NÃO escreva um valor executável aqui. `MERGE_METHOD=merge` seria exatamente o
#    default incondicional que este passo existe para remover: quem copiasse o bloco
#    mergearia com `merge` mesmo onde a resolução produziu squash/rebase.
#    O placeholder abaixo é REJEITADO pela enum — preencha com a resolução da tabela.
MERGE_METHOD="<merge|squash|rebase conforme a tabela de resolução acima>"

# Enum-valide ANTES de usar. `gh pr merge` aceita exatamente estes três flags de
# estratégia; um valor vazio vira `gh pr merge <N> --`, que apenas encerra o
# parsing de opções e NÃO seleciona estratégia alguma (medido).
case "$MERGE_METHOD" in
  merge|squash|rebase) ;;
  *) echo "fail-closed: MERGE_METHOD invalido: '${MERGE_METHOD:-<vazio>}'" >&2; exit 1 ;;
esac

# PERSISTA: variável de shell não sobrevive entre passos, sessões ou agentes.
printf '%s\n' "$MERGE_METHOD" > "$(git rev-parse --git-dir)/MERGE_METHOD"
```

**Contrato de leitura** — todo caller usa exatamente esta forma:

```bash
MERGE_METHOD=$(cat "$(git rev-parse --git-dir)/MERGE_METHOD" 2>/dev/null) || MERGE_METHOD=""
case "$MERGE_METHOD" in
  merge|squash|rebase) ;;
  *) echo "fail-closed: metodo nao resolvido -- rode o Step 9a antes" >&2; exit 1 ;;
esac
```

### Step 9b — Merge

```bash
# PIN do head auditado. Se outra sessao empurrar entre o Step 7 e aqui, este
# comando mergearia um commit que NUNCA foi revisado. `gh pr merge --help`
# define `--match-head-commit SHA` como "Commit SHA that the pull request head
# must match to allow merge" -- o merge FALHA em vez de aceitar o head novo.
# CARREGUE o metodo resolvido: o Step 9b pode rodar em shell NOVO, e o 9a
# apenas PERSISTIU -- nao exportou (export nao atravessa shell).
MERGE_METHOD=$(cat "$(git rev-parse --git-dir)/MERGE_METHOD" 2>/dev/null) || MERGE_METHOD=""
case "$MERGE_METHOD" in
  merge|squash|rebase) ;;
  *) echo "fail-closed: metodo nao resolvido -- rode o Step 9a antes" >&2; exit 1 ;;
esac

# CARREGUE o OID auditado -- nao consulte de novo. Um `gh pr view` AQUI leria o
# head ATUAL, que e exatamente o que o pin deveria rejeitar: se outra sessao
# empurrou, o comando passaria a "prender" o commit novo e o pin viraria enfeite.
REVIEWED_OID=$(cat "$(git rev-parse --git-dir)/REVIEWED_OID" 2>/dev/null) || REVIEWED_OID=""
case "$REVIEWED_OID" in
  [0-9a-f][0-9a-f]*) ;;
  *) echo "fail-closed: OID auditado ausente -- rode o Step 7 antes" >&2; exit 1 ;;
esac
gh pr merge <N> --"$MERGE_METHOD" --match-head-commit "$REVIEWED_OID"
```

## Step 10: Sync the base branch

⚠️ **Sincronize a branch em que o PR foi mergeado, não `main` por reflexo.** Mergear em
`develop` e depois puxar `main` deixa o estado local na branch errada.

⛔ **NUNCA use `git checkout`/`git switch` no repo principal** — o Step 1 proíbe, e esta regra
não se excetua. Sincronize **dentro do worktree** que já acompanha a base.

```bash
# ⚠️ O Step 10 é PÓS-merge: sincronizar a base de um PR aberto (ou fechado sem
#    merge) puxa commits que o PR ainda não contribuiu e deixa o fluxo seguir
#    para auditoria/cleanup com semântica de mergeado. Leia estado e base
#    JUNTOS e falhe fechado.
META=$(gh pr view <N> --json state,baseRefName -q '[.state,.baseRefName]|@tsv') || {
  echo "⛔ fail-closed: não consegui ler os metadados do PR" >&2; exit 1; }
IFS=$'\t' read -r STATE BASE <<<"$META"
[ "$STATE" = "MERGED" ] || {
  echo "⛔ fail-closed: PR não está MERGED (state=$STATE) — não sincronize" >&2; exit 1; }
[ -n "$BASE" ] || { echo "⛔ fail-closed: base vazia" >&2; exit 1; }

# Localize o worktree que acompanha $BASE (nunca troque de branch na raiz).
# `$2` truncaria caminho com espaço: `git worktree list --porcelain` emite o
# caminho INTEIRO após "worktree ". Use substr, não campo.
WT=$(git worktree list --porcelain \
     | awk -v b="refs/heads/$BASE" '
         /^worktree /{p=substr($0,10)}
         /^branch /{if(substr($0,8)==b) print p}')

if [ -z "$WT" ]; then
  echo "⛔ fail-closed: nenhum worktree acompanha $BASE — crie um antes de sincronizar" >&2
  exit 1
fi

# ⚠️ `--porcelain` sozinho OMITE ignorados. Se um commit que chega passar a
#    rastrear um caminho hoje ignorado, o `pull --ff-only` SOBRESCREVE a versão
#    local sem aviso — e a árvore parecia limpa.
DIRTY=$(git -C "$WT" status --porcelain --untracked-files=all --ignored) || {
  echo "⛔ fail-closed: não consegui inspecionar o worktree de $BASE" >&2; exit 1; }
[ -z "$DIRTY" ] || {
  echo "⛔ fail-closed: worktree de $BASE tem conteúdo não commitado/ignorado" >&2
  echo "   preserve-o antes de sincronizar por cima" >&2
  exit 1; }

# Fail-closed: `--ff-only` RECUSA quando a base divergiu, e num shell sem
# `errexit` o fluxo seguiria como se tivesse sincronizado -- os passos
# seguintes operariam sobre uma base desatualizada.
git -C "$WT" pull --ff-only origin "$BASE" || {
  echo "⛔ fail-closed: sincronizacao de '$BASE' falhou (divergencia?)" >&2
  exit 1; }
```

## Step 11: Audit Reviews + Archive Emails

### 11a. SEGUNDA auditoria das revisões (a primeira é o Step 7b, PRÉ-merge)

⚠️ Esta passagem é **rede de segurança, não a primeira leitura**. Se um achado do corpo
aparecer aqui pela primeira vez, o Step 7b falhou e o defeito já entrou no `main` —
registre o escape e corrija o processo, não só o achado.

```bash
# Read inline comments
gh api repos/{owner}/{repo}/pulls/{N}/comments --jq '.[].body'

# Read reviews
gh api repos/{owner}/{repo}/pulls/{N}/reviews --jq '.[] | "\(.state): \(.body)"'
```

If fix-needed issues found post-merge: new Worktree -> Fix -> PR -> Review -> Merge (C07 loop).

### 11b. Search + archive emails (gog CLI)

```bash
# Search both accounts
gog gmail search '{repo} PR #{N}' -a your-personal-email@example.com -p
gog gmail search '{repo}' -a user@acme-corp.example.com -p

# Get thread IDs for scripting
gog gmail search '{repo} PR #{N}' -a your-personal-email@example.com -j \
  | python3 -c "import json,sys; [print(t['id'],t['subject']) for t in json.loads(sys.stdin.read()).get('threads',[])]"

# Archive (remove from INBOX) — AFTER audit
gog gmail thread modify {threadId} --remove INBOX -a your-personal-email@example.com -y
```

### Email accounts

| Account | gog Profile | Content |
|---------|-------------|---------|
| `your-personal-email@example.com` | default | GitHub notifications |
| `user@acme-corp.example.com` | org | Jira, Confluence, Bitbucket |

### Email classification

| Source | Action |
|--------|--------|
| GitHub bots (Copilot, Qodo, CodeRabbit) | Archive after gh api audit |
| GitHub workflow failures | Archive (info only) |
| Jira automation | Archive (document if revert) |

## Step 12: Cleanup Worktree

⚠️ **Saia do worktree antes de removê-lo.** O Step 1 entra no worktree da feature e o Step 10
usa `git -C` (que **não** muda o diretório do chamador). Remover o worktree que contém o `cwd`
falha, e os comandos seguintes herdam um `cwd` inválido.

⚠️ **Remova o worktree ANTES de apagar a branch.** Com o worktree ainda registrado, `git branch`
falha com *"cannot delete branch used by worktree"* — erro que **mascara** o problema real
abaixo.

⚠️ **`git branch -d` recusa após squash/rebase.** Esses métodos reescrevem os commits, então a
ponta da feature **não** é ancestral da base — o git a considera *"not fully merged"*. A remoção
só é segura porque o PR **está mergeado**: confirme isso pela API, não pela ancestralidade.

⛔ **NUNCA use `git worktree remove --force`.** Ele apaga WIP não commitado **sem aviso**
(verificado: um arquivo não rastreado foi destruído silenciosamente). Num ambiente multi-agente
isso descarta trabalho de outra sessão. Worktree sujo é **fail-closed**, não obstáculo a forçar.

⚠️ **Todas as guardas ANTES de qualquer remoção.** Um worktree limpo porém **não mergeado** é
trabalho válido: se a remoção vier antes da checagem de merge, ele é destruído e só a branch
é poupada. Verifique primeiro, destrua depois.

```bash
# `--show-toplevel` devolveria a raiz do PRÓPRIO worktree. A primeira entrada de
# `worktree list --porcelain` é sempre o worktree PRINCIPAL. `substr` preserva espaços.
ROOT=$(git worktree list --porcelain | awk 'NR==1{print substr($0,10)}')
# ── GUARDA 1: o PR precisa estar MERGED, e a branch vem do PRÓPRIO PR.
#    Um template `{type}/{feature}` reproduz aqui o defeito que a guarda 2
#    corrigiu no path: as três convenções deste repo não casariam.
#    ⚠️ Separe a busca do `read`: em `read … <<<"$(cmd)"` o `||` mede o READ, não
#    o comando — um `gh` que falha ainda entrega here-string vazia e o `read`
#    "passa" com campos vazios (medido). Capture antes, valide depois.
META=$(gh pr view <N> --json state,headRefName,baseRefName,headRefOid \
  -q '[.state,.headRefName,.baseRefName,.headRefOid]|@tsv') || {
    echo "⛔ fail-closed: não consegui ler os metadados do PR" >&2; exit 1; }
IFS=$'\t' read -r STATE BRANCH BASE_REF MERGED_OID <<<"$META"
for v in STATE BRANCH BASE_REF MERGED_OID; do
  [ -n "${!v}" ] || { echo "⛔ fail-closed: metadado '$v' vazio" >&2; exit 1; }
done
[ "$STATE" = "MERGED" ] || {
  echo "⛔ fail-closed: PR não está MERGED (state=$STATE) — não remova nada" >&2; exit 1; }

# ── GUARDA 2: resolva o worktree pelo REGISTRO, nunca reconstruindo o path por
#    template. As regras deste repo usam TRÊS convenções — `{feature_name}`
#    (agent-scm), `{feature}` (operational-workflow) e `{session-id}-{feature}`
#    (aqui): fixar uma reprova os worktrees criados pelas outras duas.
#    O registro também devolve o caminho FÍSICO já resolvido, o que dispensa
#    normalizar `/tmp` → `/private/tmp` (macOS) na comparação.
WT_REAL=$(git worktree list --porcelain | awk -v b="refs/heads/$BRANCH" '
/^worktree /{p=substr($0,10)}
/^branch /{if(substr($0,8)==b) print p}')
[ -n "$WT_REAL" ] || {
  echo "⛔ fail-closed: nenhum worktree registrado acompanha '$BRANCH'" >&2; exit 1; }

# ── GUARDA 3: WIP não commitado bloqueia a remoção.
#    ⚠️ `--porcelain` sozinho OMITE arquivos ignorados: um `.env` de outra sessão
#    fica invisível (medido: vazio vs `!! segredo.env`) e o `worktree remove`,
#    que usa a mesma checagem, o apagaria sem pedir `--force`.
DIRTY=$(git -C "$WT_REAL" status --porcelain --untracked-files=all --ignored) || {
  echo "⛔ fail-closed: não consegui inspecionar '$WT_REAL'" >&2; exit 1; }
[ -z "$DIRTY" ] || {
  echo "⛔ fail-closed: '$WT_REAL' tem conteúdo não commitado/ignorado — preserve" >&2
  exit 1; }

# ── GUARDA 4: commits que chegaram DEPOIS do merge. `status` está limpo, mas
#    outra sessão pode ter commitado na branch no intervalo; `branch -D` os
#    descartaria em silêncio.
#    ⚠️ NÃO use ancestralidade (`origin/$BASE_REF..$BRANCH`): após squash ela
#    conta TODOS os commits originais do PR (medido: 2) e reprovaria todo
#    cleanup legítimo — é o mesmo critério que a guarda 1 rejeita.
#    Compare a ponta atual com o `headRefOid` que o PR registrou ao mergear:
#    igual ⇒ nada novo; diferente ⇒ alguém commitou depois (medido nos 2 casos).
CUR_OID=$(git -C "$WT_REAL" rev-parse "$BRANCH") || {
  echo "⛔ fail-closed: não consegui ler a ponta de '$BRANCH'" >&2; exit 1; }
[ "$CUR_OID" = "$MERGED_OID" ] || {
  echo "⛔ fail-closed: '$BRANCH' avançou após o merge" >&2
  echo "   mergeado=${MERGED_OID:0:8} atual=${CUR_OID:0:8} — revise antes de apagar" >&2
  exit 1; }

# ── GUARDA 5: inspecione o REMOTO **antes** de destruir qualquer coisa local.
#    A guarda 4 só olhou a ponta LOCAL; a remota pode ter avançado por push de
#    outra sessão. Inspecionar só depois produz CLEANUP PARCIAL: worktree e ref
#    local já destruídos, e então o remoto reprova — estado pior que o inicial.
#    `ls-remote` distingue pelo exit code (medido):
#    0 = existe · 2 = não há match (removida no merge) · 128 = erro real.
# ⚠️ Sob `set -e`, `cmd; LS=$?` ABORTA no status 2 e o `case` nunca roda (medido:
#    o caminho legítimo "branch já removida" morria aqui). A OR-list preserva o status.
LS=0
REMOTE_LINE=$(git ls-remote --exit-code --heads origin "$BRANCH" 2>/dev/null) || LS=$?
case "$LS" in
  0) REMOTE_OID=${REMOTE_LINE%%[[:space:]]*}
     [ "$REMOTE_OID" = "$MERGED_OID" ] || {
       echo "⛔ fail-closed: a ponta REMOTA de '$BRANCH' difere do que foi mergeado" >&2
       echo "   mergeado=${MERGED_OID:0:8} remoto=${REMOTE_OID:0:8} — nada foi removido" >&2
       exit 1; } ;;
  2) ;;   # já removida no merge — segue; nada a apagar no remoto
  *) echo "⛔ fail-closed: ls-remote falhou (exit=$LS) — estado remoto indeterminado" >&2
     echo "   nada foi removido; resolva o acesso e repita" >&2
     exit 1 ;;
esac

# ── Todas as 5 guardas passaram. Só agora destrói, na ordem: worktree → ref
#    local → ref remota. Cada passo é atômico ou fail-closed.
cd "$ROOT" || exit 1                    # sai do worktree ANTES de removê-lo
# Fail-closed: se outra sessao sujar ou travar o worktree DEPOIS da guarda 3,
# este comando retorna != 0 — e num shell sem `errexit` a execucao seguiria
# para as delecoes de ref abaixo, destruindo a branch de um worktree que
# continua existindo e sujo.
git worktree remove "$WT_REAL" || {   # sem --force: as guardas acima são o critério
  echo "⛔ fail-closed: worktree remove falhou — NAO prossiga para as refs" >&2
  exit 1; }

# ⚠️ TOCTOU local: entre a guarda 4 e a remoção, outra sessão pode commitar na
#    branch. `git branch -D` apaga incondicionalmente e descartaria esse commit.
#    `update-ref -d <ref> <old>` é ATÔMICO: só remove se a ref ainda valer o
#    esperado. Verificado — OID correto ⇒ removida; OID vencido ⇒
#    "cannot lock ref … is at X but expected Y" e a branch PERMANECE.
git update-ref -d "refs/heads/$BRANCH" "$MERGED_OID" || {
  echo "⛔ fail-closed: a branch local avançou durante a limpeza — preservada" >&2
  exit 1; }

# ── Remota, quando ainda existe. ⚠️ TOCTOU: entre a guarda 5 e o delete outra
#    sessão pode ter feito push. Um `--delete` simples apagaria esse commit; o
#    lease torna a remoção ATÔMICA — o servidor só aceita se a ponta ainda for
#    a esperada. Verificado (git 2.50.1): OID correto ⇒ `[deleted]`;
#    OID vencido ⇒ `! [rejected] (delete) … (stale info)` e a branch PERMANECE.
if [ "$LS" -eq 0 ]; then
  git push --force-with-lease="refs/heads/$BRANCH:$MERGED_OID" \
           origin --delete "$BRANCH" || {
    echo "⛔ lease recusado — a branch remota avançou durante a limpeza." >&2
    echo "   O worktree e a ref local já foram removidos; a remota PERMANECE." >&2
    echo "   Não force: revise o que chegou nela antes de apagar." >&2
    exit 1; }
else
  echo "ℹ️  branch remota já removida no merge (delete_branch_on_merge)"
fi
```

---

## Tools Reference

| Tool | Binary | Purpose | Scope |
|------|--------|---------|-------|
| CodeRabbit CLI | `coderabbit` / `cr` | Local code review (primary) | Local diff |
| Qodo CLI | `qodo` | Local code review (fallback) | Local diff |
| GitHub CLI | `gh` | PR ops, review data (primary) | GitHub API |
| gog CLI | `gog` | Email search + archive | Both gmail accounts |
| Gmail MCP | MCP server | Email read (fallback) | @gmail.com only |

### CLI Gotchas

- **CodeRabbit**: plano free ~1 review/25min, limite de 150 arquivos/PR. `--plain` foi
  **REMOVIDO** na 0.7.x — **não** existe flag substituta: *"Plain text is the default
  review mode"* (`coderabbit review --help`, 0.7.8). Basta **omitir** a flag. Para saída
  estruturada consumível por agente use `--agent`. Em 0.5.2 houve timeout a 180 s.
- **Qodo**: `qodo --ci -y "prompt"` **NÃO EXISTE MAIS** (`error: unknown option '--ci'`,
  verificado 2026-09-17). O subcomando atual é `qodo review [pathspec...]`.
- **Qodo**: `review` exige o repo conectado à plataforma; sem isso falha com
  `repo_not_connected`. Por isso é **fallback** — execute-o só quando o CodeRabbit falhar,
  nunca em sequência incondicional.
- **gog**: Uses `thread` (singular), not `threads` for subcommand
- **Gmail MCP**: Only @gmail.com (OAuth). Cannot access @acme-corp.example.com

### Known False Positives (acme-solution repo)

- Portuguese accents: CodeRabbit flags "Versao" -> "Versao". Convention is ASCII-safe. **Dismiss.**
- Read-only violations: Qodo flags `docs/` modifications. `docs/` IS the project's purpose. **Dismiss.**

---

## Bot-Config Correction Discipline

> Generalizes the two dismissals above + the `.pr_agent.toml` precedent (whose header exists to *"prevent
> recurring false-positive"* findings) into a governed loop: instead of dismissing the same false-positive
> forever, **teach the bot via its own repo config** so it stops emitting it. Executed by the
> `bot-finding-arbiter` skill (*Praetor*); this section is the policy.

**When a reviewer/scanner bot flags a finding**, classify it into exactly one bucket:

| Bucket | Action |
|---|---|
| **valid-actionable** | fix/adapt the code (dispositions accept/fix/improve/expand per Step 8) |
| **bot-wrong** (false-positive · governance-misalignment · style-only) | reject + **teach the bot via its config file** (below) — but ONLY after independent verify |
| **ambiguous** | DEFER + comment; **never** guess a config edit |

**Rules for a teach-the-bot config edit (the "edict"):**
1. ⛔ **NEVER suppress a valid security or logic finding.** A config edit that would silence a real
   secret / injection / auth flaw / CVE / correctness bug is forbidden (gaming the scanner = Goodhart).
   Security-class "bot-wrong" verdicts are **HITL-gated**; the default is *fix/upgrade*, not suppress.
2. **Verifier > generator.** The "bot is wrong" verdict must be **independently verified** (a deterministic
   oracle where one exists — the flagged pattern is our documented convention / re-run the scanner — OR a
   second-lens review via `convergence-engine`/`perspective-trio`) BEFORE any file is touched.
3. **Repo-fixable only.** Some bot errors are account/dashboard-side (quota, rate-limit, import,
   entitlement — e.g. a Snyk "test limit reached") and NO committed file fixes them → HITL playbook,
   **no config edit**. See `skills/bot-finding-arbiter/bot-config-registry.md` (`repo-fixable?` column).
4. **Narrowest teaching form.** Prefer a path-scoped instruction / documented-convention note over a broad
   ignore (over-suppression hides future real findings).
5. **Reviewed PR, never silent.** A config edit lands via worktree → review → merge like any change, with a
   rationale, and is recorded on the Bot Scorecard as a `config-taught` disposition (accuracy tracking).

The bot → config-file map (`.pr_agent.toml` · `.coderabbit.yaml` · `.github/copilot-instructions.md` ·
`.amazonq/rules/` · `.gitleaks.toml` · `.trivyignore`) enumerates **candidate teaching surfaces
(recon-before-assume)** — verify the file actually exists before an edict; some (notably `.amazonq/rules/`)
are documented-but-frequently-absent → confirm-first / HITL when missing. The SSOT map (with the
`repo-fixable?` + confirm-first columns) is `skills/bot-finding-arbiter/bot-config-registry.md`.

---

## Anti-Patterns

```
X  git checkout/switch in main repo (use worktree)
X  Push without local CLI review
X  Merge without any review
X  Archiving emails before auditing reviews (audit FIRST)
X  Using email to extract review content (use gh api)
X  Using Gmail MCP for @acme-corp.example.com (not connected)
X  Using `qodo --ci -y "prompt"` (REMOVIDO da CLI — use `qodo review [pathspec...]`)
X  Running Qodo unconditionally after CodeRabbit (é FALLBACK: só quando o primário falha)
X  Hard-coding `main` as merge base or sync target (resolva a base; veja Steps 3 e 10)
X  `git worktree remove --force` (destrói WIP não commitado de outras sessões, sem aviso)
X  Rationalizing protocol bypass: "user said 'resolve gaps' so I can edit in main repo"
   → Task instructions ("fix", "resolve", "implement") are NOT protocol overrides.
   → Only EXPLICIT bypass language counts ("skip worktree", "edit directly").
   → If you catch yourself justifying a bypass, you're already wrong.
```

## Exceptions (Require Justification)

Merge without review ONLY if:
1. **Critical hotfix**: Production down (document urgency)
2. **Explicit bypass**: User authorizes explicitly
3. **Isolated infrastructure**: Config repo with no impact

ALWAYS document exception in the PR.

---

*v1.2.1 | 2026-07-01 | Step-8 fire-point: route reviewer-BOT findings per-finding to `skills/bot-finding-arbiter` (*Praetor*) as the default handler (elevates the 5-way menu to 7-way + teach-the-bot). Effectivation of the existing § Bot-Config Correction Discipline — policy unchanged, now actively triggered from the lifecycle step.*
*v1.2.0 | 2026-07-01 | Add Bot-Config Correction Discipline: classify {valid \| bot-wrong \| ambiguous} + teach-the-bot-via-its-config edicts, gated by ⛔never-suppress-valid-security + verifier>generator + repo-fixable-only + narrowest-form + reviewed-PR. Executed by `skills/bot-finding-arbiter` (Praetor); SSOT map in `bot-config-registry.md`.*
*v1.1.0 | 2026-03-11 | Tighten worktree exception clause: "explicit user request" → literal bypass language only + decision checkpoint + rationalization anti-pattern*
*v1.0.0 | 2026-03-06 | Unified from C07 v3.0 + C12 v3.0 + C04 essentials + CLI review tools*
