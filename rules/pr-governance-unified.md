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

# 1b. Crie o worktree A PARTIR da base decidida (não do HEAD corrente)
git fetch -q origin "$BASE_REF"
git worktree add .worktrees/{session-id}-{feature} -b {type}/{feature} "origin/$BASE_REF"
cd .worktrees/{session-id}-{feature}

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
if [ "$PRIMARY_OK" -eq 0 ]; then
  qodo review || echo "⚠️  Qodo também indisponível" >&2   # ou: qodo review <caminho>
fi

# Se AMBOS indisponíveis (rate-limit, timeout, repo não conectado): execute a passagem
# DIY de review e DIVULGUE no corpo do PR qual primário faltou e por quê — os bots do
# GitHub revisam no PR, e o passe DIY NUNCA substitui o veredito de um primário exigido.
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
gh pr create --title "{type}({scope}): {description}" --body "..."
```

NEVER merge directly. Always via PR.

## Step 7: Bot Review (OPTIONAL wait)

TTL: 30 minutes. Optional if local review was executed.

```bash
gh pr view <N> --json comments,reviews,statusCheckRollup
```

Reviewers: Copilot, Qodo, CodeRabbit (bots) | GitHub UI (human) | Claude agent (AI)

## Step 8: Analyze Review + Decide

| Classification | Action |
|----------------|--------|
| Approved | Merge (Step 9) |
| Valid correction | Fix in worktree, commit, push, loop Step 7-8 |
| Partially valid | Apply valid items, document rejected with justification, push, loop |
| Disagree (justified) | Merge + document justification via `gh pr comment` |
| Inconclusive | Escalate to human (do NOT merge) |

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

# (a) Rulesets que incidem sobre a BASE (não sobre o repo inteiro).
RULES=$(gh api "repos/{owner}/{repo}/rules/branches/$BASE_REF") || {
  echo "⛔ fail-closed: inspeção de rulesets falhou — não presuma ausência" >&2; exit 1; }
RLIN=$(printf '%s' "$RULES" | jq '[.[]|select(.type=="required_linear_history")]|length')

# (b) Branch protection CLÁSSICA. "Branch not protected" é ausência legítima (404);
#     qualquer outra falha é fail-closed.
if PROT=$(gh api "repos/{owner}/{repo}/branches/$BASE_REF/protection" 2>/dev/null); then
  PLIN=$(printf '%s' "$PROT" | jq -r '.required_linear_history.enabled // false')
elif printf '%s' "$PROT" | grep -q '"Branch not protected"'; then
  PLIN=false
else
  echo "⛔ fail-closed: inspeção de branch protection falhou em '$BASE_REF'" >&2; exit 1
fi

# Capacidade EFETIVA de merge commit.
MERGE_OK=$(printf '%s' "$CAP" | jq -r '.mergeCommitAllowed')
if [ "$RLIN" -gt 0 ] || [ "$PLIN" = true ]; then
  MERGE_OK=false
  echo "ℹ️  linear-history exigida em '$BASE_REF': merge commit indisponível" >&2
fi
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
2. Existe regra de escopo mais amplo que regule o caso (**global → específico**, **top → down**)?
   → ela decide; corrija as fontes divergentes para refletir o resultado.
3. A divergência é **claramente** drift (uma fonte ficou para trás) **e** você tem segurança
   para corrigir sozinho? → corrija **todos** os arquivos em conflito — inclusive outras regras
   auto-carregadas que complementem esta (ex. `rules/operational-workflow.md`) — e registre.
4. Caso contrário → **HITL**. Não mergeie sob conflito não resolvido.

```bash
# Um comando por método resolvido. Os TRÊS são suportados.
gh pr merge <N> --merge     # resolução produziu "merge"
gh pr merge <N> --squash    # resolução produziu "squash"
gh pr merge <N> --rebase    # resolução produziu "rebase"
```

## Step 10: Sync the base branch

⚠️ **Sincronize a branch em que o PR foi mergeado, não `main` por reflexo.** Mergear em
`develop` e depois puxar `main` deixa o estado local na branch errada.

⛔ **NUNCA use `git checkout`/`git switch` no repo principal** — o Step 1 proíbe, e esta regra
não se excetua. Sincronize **dentro do worktree** que já acompanha a base.

```bash
BASE=$(gh pr view <N> --json baseRefName -q .baseRefName)

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
elif [ -n "$(git -C "$WT" status --porcelain)" ]; then
  echo "⛔ fail-closed: worktree de $BASE está sujo — não sincronize por cima" >&2
  exit 1
else
  git -C "$WT" pull --ff-only origin "$BASE"
fi
```

## Step 11: Audit Reviews + Archive Emails

### 11a. Audit PR reviews (PRIMARY: gh api)

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
WT="$ROOT/.worktrees/{session-id}-{feature}"
BRANCH={type}/{feature}

# ── GUARDA 1: o PR precisa estar MERGED. Ancestralidade não serve para squash/rebase.
STATE=$(gh pr view <N> --json state -q .state) || exit 1
[ "$STATE" = "MERGED" ] || {
  echo "⛔ fail-closed: PR não está MERGED (state=$STATE) — não remova nada" >&2; exit 1; }

# ── GUARDA 2: o worktree precisa EXISTIR e estar REGISTRADO neste repo. Sem ela,
#    `git -C` num caminho inexistente sai 128 com stdout VAZIO (medido) e a guarda
#    de WIP abaixo passaria — fail-open que autoriza remover o alvo errado.
#    ⚠️ Compare caminhos FÍSICOS: o git registra o path resolvido, e em macOS
#    `/tmp` → `/private/tmp`. Comparação literal reprova um worktree válido
#    (medido) — seguro, porém inutilizável.
WT_REAL=$(cd "$WT" 2>/dev/null && pwd -P) || {
  echo "⛔ fail-closed: '$WT' não existe" >&2; exit 1; }
git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' \
  | grep -qxF "$WT_REAL" || {
    echo "⛔ fail-closed: '$WT_REAL' não é um worktree registrado deste repo" >&2; exit 1; }

# ── GUARDA 3: WIP não commitado (seu ou de outra sessão) bloqueia a remoção.
#    Sem `2>/dev/null`: um erro real precisa aparecer, não ser silenciado.
DIRTY=$(git -C "$WT_REAL" status --porcelain) || {
  echo "⛔ fail-closed: não consegui inspecionar '$WT_REAL'" >&2; exit 1; }
[ -z "$DIRTY" ] || {
  echo "⛔ fail-closed: '$WT_REAL' tem mudanças não commitadas — preserve e escale" >&2
  exit 1; }

# ── Só agora destrói.
cd "$ROOT" || exit 1                    # sai do worktree ANTES de removê-lo
git worktree remove "$WT_REAL"          # sem --force: as guardas acima são o critério
git branch -D "$BRANCH"                 # -D: a ponta não é ancestral após squash/rebase

# ── Remota: `ls-remote` distingue os casos pelo exit code (medido):
#    0 = existe · 2 = não há match (removida no merge) · 128 = erro real (auth/rede).
#    Tratar 128 como "já removida" mascararia falha de infraestrutura.
# ⚠️ Sob `set -e`, `cmd; LS=$?` ABORTA no status 2 e o `case` nunca roda (medido:
#    o caminho legítimo "branch já removida" morria aqui). A OR-list preserva o status.
LS=0; git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1 || LS=$?
case "$LS" in
  0) git push origin --delete "$BRANCH" || {
       echo "⛔ a branch remota existe mas o delete falhou" >&2; exit 1; } ;;
  2) echo "ℹ️  branch remota já removida no merge (delete_branch_on_merge)" ;;
  *) echo "⛔ fail-closed: ls-remote falhou (exit=$LS) — estado remoto indeterminado" >&2
     exit 1 ;;
esac
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
