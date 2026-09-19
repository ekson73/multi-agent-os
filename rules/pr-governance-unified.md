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
  9.MERGE -> 10.PULL MAIN -> 11.AUDIT+ARCHIVE EMAILS -> 12.CLEANUP WORKTREE
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

# 1º) arquivo persistido pelo Step 1c
BASE_REF=$(cat "$GITDIR/BASE_REF" 2>/dev/null)

# 2º) BASE_REF explícito do chamador (adoção manual de worktree legado)
[ -z "$BASE_REF" ] && BASE_REF="${BASE_REF_OVERRIDE:-}"

# 3º) base do PR, quando já existe PR para esta branch
[ -z "$BASE_REF" ] && BASE_REF=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null)

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
coderabbit review --base "$BASE_REF" --config CLAUDE.md

# FALLBACK: Qodo CLI — `qodo review [pathspec...]`
# ⚠️ `qodo --ci -y "<prompt>"` NÃO EXISTE MAIS (verificado 2026-09-17: "error: unknown
#    option '--ci'"). A CLI passou a expor o subcomando `review`.
# ⚠️ Exige o repo CONECTADO ao workspace Qodo; senão falha com `repo_not_connected`.
qodo review                      # ou: qodo review <caminho> para limitar o escopo

# Se AMBOS indisponíveis (rate-limit, timeout, repo não conectado): execute a passagem
# DIY de review e DIVULGUE no corpo do PR qual primário faltou e por quê — os bots do
# GitHub revisam no PR, e o passe DIY NUNCA substitui o veredito de um primário exigido.
```

**Após abrir o PR (Step 6+), afirme que a base revisada é a base real:**

```bash
PR_BASE=$(gh pr view <N> --json baseRefName -q .baseRefName)
[ "$PR_BASE" = "$BASE_REF" ] || {
  echo "⛔ revisão feita contra '$BASE_REF' mas o PR aponta '$PR_BASE' — re-revise"; exit 1; }
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

**Eixo 2 — capacidade habilitada** (o que o repo *permite*): `allow_merge_commit` /
`allow_squash_merge` + rulesets. Habilitar vários métodos é capacidade legítima, **não** é
declaração de política.

**Resolução:**

| Situação | Ação |
|---|---|
| Declaração explícita existe **e** o método está habilitado | use o método **declarado** |
| **Nenhuma** declaração | **default `--merge`** — preserva ancestralidade |
| Método declarado está **desabilitado** no repo | ⛔ fail-closed: não mergeie, escale |
| **Fontes divergem** entre si | protocolo de conflito abaixo |

**Protocolo de conflito entre fontes** (ratificado pelo operador; substitui hierarquia fixa):

1. **Recon + OODA**: compare **todas** as versões divergentes, citando arquivo e linha.
2. Existe regra de escopo mais amplo que regule o caso (**global → específico**, **top → down**)?
   → ela decide; corrija as fontes divergentes para refletir o resultado.
3. A divergência é **claramente** drift (uma fonte ficou para trás) **e** você tem segurança
   para corrigir sozinho? → corrija todos os arquivos em conflito e registre a correção.
4. Caso contrário → **HITL**. Não mergeie sob conflito não resolvido.

```bash
gh pr merge <N> --merge    # SOMENTE se a resolução produziu "merge"
gh pr merge <N> --squash   # SOMENTE se a resolução produziu "squash"
```

## Step 10: Sync the base branch

⚠️ **Sincronize a branch em que o PR foi mergeado, não `main` por reflexo.** Mergear em
`develop` e depois puxar `main` deixa o estado local na branch errada.

⛔ **NUNCA use `git checkout`/`git switch` no repo principal** — o Step 1 proíbe, e esta regra
não se excetua. Sincronize **dentro do worktree** que já acompanha a base.

```bash
BASE=$(gh pr view <N> --json baseRefName -q .baseRefName)

# Localize o worktree que já acompanha $BASE (nunca troque de branch na raiz)
WT=$(git worktree list --porcelain \
     | awk -v b="refs/heads/$BASE" '/^worktree /{p=$2} /^branch /{if($2==b) print p}')

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

```bash
# Remove worktree
git worktree remove .worktrees/{session-id}-{feature}
# Or: rm -rf .worktrees/{session-id}-{feature} && git worktree prune

# Delete local branch
git branch -d {type}/{feature}

# Delete remote branch
git push origin --delete {type}/{feature}
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

- **CodeRabbit**: Free plan ~1 review/25min, 150 files/PR limit
- **Qodo**: `self-review` requires `agent.toml` and opens web UI — use `qodo --ci -y "prompt"` for CLI
- **Qodo**: Avoid `-q` (silent) — suppresses review output. Use `--ci -y` for non-interactive
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
X  Using qodo self-review without agent.toml (use qodo --ci -y "prompt" instead)
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
