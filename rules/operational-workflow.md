---
description: Workflow operacional — PR governance + git worktrees + email cleanup
---

# Operational Workflow — PR Governance + Git Worktrees + Email Cleanup

<!-- Auto-loaded rule | Version: 1.0.0 | 2026-03-07 -->
<!-- Scope: User-scope (all projects) -->
<!-- Complements: pr-governance-unified.md (C07+C12), git-worktree-protocol.md (C04) -->

## Quick Reference: Complete PR Lifecycle

```
WORKTREE → CODE → LOCAL REVIEW → FIX LOOP → PUSH → PR → [BOT REVIEW] → MERGE → SYNC BASE → AUDIT → ARCHIVE EMAILS → CLEANUP
```

## 1. Worktree Creation (MANDATORY)

```bash
# A base NUNCA é `main` por reflexo: resolva e PERSISTA para os steps seguintes.
BASE_REF="${BASE_REF_OVERRIDE:-$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)}"
git ls-remote --exit-code --heads origin "$BASE_REF" >/dev/null || {
  echo "fail-closed: base '$BASE_REF' nao existe em origin" >&2; exit 1; }
git fetch -q origin "$BASE_REF"

git worktree add .worktrees/{feature} -b {type}/{feature} "origin/$BASE_REF"
cd .worktrees/{feature}

# Persista: variaveis de shell NAO sobrevivem entre steps. Sem isto o Step 3 falha.
printf '%s\n' "$BASE_REF" > "$(git rev-parse --git-dir)/BASE_REF"
```

Types: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`

Exceptions: See pr-governance-unified.md Step 1.
NEVER interpret a task instruction ("fix X", "resolve Y") as authorization to skip worktree.

## 2. Code + Commit

```bash
git add <files>
git commit -m "{type}({scope}): {description}"
```

## 3. Local Review (MANDATORY before push)

```bash
# Base NUNCA fixa: mesma precedencia do pr-governance-unified Step 3.
# Sob `set -e` a atribuicao herda o status do comando: guarde CADA etapa com `|| ...`.
BASE_REF=$(cat "$(git rev-parse --git-dir)/BASE_REF" 2>/dev/null) || BASE_REF=""
[ -n "$BASE_REF" ] || BASE_REF="${BASE_REF_OVERRIDE:-}"
[ -n "$BASE_REF" ] || BASE_REF=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null) || BASE_REF=""
[ -n "$BASE_REF" ] || { echo "fail-closed: base indeterminada" >&2; exit 1; }

# PRIMARY: CodeRabbit CLI (`--plain` foi REMOVIDO na 0.7.8; texto plano e o default)
if cr review --base "$BASE_REF" --config CLAUDE.md; then
  PRIMARY_OK=1
else
  PRIMARY_OK=0
fi

# FALLBACK: so quando o primario falha (`qodo --ci -y` NAO EXISTE MAIS; use `review`).
# Rodar incondicionalmente derruba um review bom com `repo_not_connected`.
REVIEW_OK=$PRIMARY_OK
if [ "$PRIMARY_OK" -eq 0 ]; then
  # --base tambem aqui: sem ele o Qodo usa a default do repo.
  if qodo review --base "$BASE_REF"; then REVIEW_OK=1; else REVIEW_OK=0; fi
fi

# AMBOS indisponiveis e ESTADO BLOQUEANTE, nao aviso: so a passagem DIY
# EXECUTADA e DIVULGADA no corpo do PR (qual primario faltou e por que)
# libera o push. Registrar o erro e seguir seria o fail-open que a politica
# DIY-review existe para impedir.
if [ "$REVIEW_OK" -eq 0 ]; then
  [ "${DIY_REVIEW_DONE:-0}" -eq 1 ] || {
    echo "fail-closed: sem reviewer local e sem passagem DIY executada/divulgada" >&2
    echo "  execute a revisao DIY e exporte DIY_REVIEW_DONE=1" >&2
    exit 1; }
fi
```

### CodeRabbit CLI aliases
- `cr` or `coderabbit` — same binary
- `cr review --base "$BASE_REF"` — compara contra a base RESOLVIDA (nunca `main` fixo)
- Rate limit: ~1 review/25min on free plan, 150 files/PR max

### Qodo CLI notes
- `qodo review [pathspec...]` — subcomando atual (⚠️ `qodo --ci -y "prompt"` foi REMOVIDO:
  retorna `error: unknown option '--ci'`). Exige o repo conectado ao workspace Qodo.
- AVOID `qodo self-review` without agent.toml (opens browser)
- AVOID `-q` flag (suppresses output)

## 4. Fix Loop

```bash
# Fix P0/P1/P2 issues from review
git add <fixed-files>
git commit -m "fix: address review findings"
# Re-run review (step 3) until clean
```

## 5. Push + PR

```bash
git push -u origin {branch-name}
# --base OBRIGATORIO: sem ele o gh assume a branch DEFAULT do repo, e um PR
# empilhado seria aberto contra a base errada.
gh pr create --base "$BASE_REF" \
  --title "{type}({scope}): {description}" --body "$(cat <<'EOF'
## Summary
- ...

## Review
- Local review: CodeRabbit/Qodo CLI (pre-push)
EOF
)"
```

## 6. Merge + Pull

⛔ **PRE-CONDICAO: auditar o CORPO de toda revisao, nao so as threads.** Um achado
*outside diff range* NAO cria thread inline, entao "0 threads" convive com achados
validos nao endereçados (medido: um veredito anunciava 2 acionaveis, threads = 0, e a
auditoria dos corpos revelou 4 -- um deles perda de dados em codigo executavel).

```bash
# Corpo completo de TODA revisao, inclusive vereditos OBSOLETOS.
# O endpoint pagina em 30: sem `--paginate --slurp` as revisoes da 2a pagina
# somem em silencio. `--slurp` nao convive com `--jq`: agregue em pipe separado.
REVIEWS=$(gh api "repos/{owner}/{repo}/pulls/{N}/reviews" --paginate --slurp) || {
  echo "fail-closed: nao consegui ler as revisoes" >&2; exit 1; }
printf '%s' "$REVIEWS" | jq -r 'add[]|"\n=== \(.state) @\(.user.login) \(.commit_id[0:8])\n\(.body)"'
# Quantos acionaveis o corpo declara? Bate com o que voce dispos?
# `|| true`: sem match o grep sai 1 e abortaria o passo sob `set -e`.
printf '%s' "$REVIEWS" | jq -r 'add[].body' \
  | grep -iE 'actionable comments|outside diff' || true
```

Achado do corpo sem disposicao ⇒ NAO mergeie. A secao 7 audita de novo, mas DEPOIS do
merge -- confiar so nela deixa o defeito entrar.

```bash
# Metodo resolvido por autoridade local do repo -- ver pr-governance-unified Step 9
# MERGE_METHOD vem da resolucao do Step 9 (autoridade local + capacidade
# efetiva da base). Um literal aqui seria o default que este PR remove.
gh pr merge <N> --"$MERGE_METHOD"
# Sincronize a BASE do PR, dentro do worktree que a acompanha -- ver Step 10
# (NUNCA `git checkout` no repo principal: o Step 1 proibe)
```

## 7. Audit Reviews (gh api)

```bash
gh api repos/{owner}/{repo}/pulls/{N}/comments --jq '.[].body'
gh api repos/{owner}/{repo}/pulls/{N}/reviews --jq '.[] | "\(.state): \(.body)"'
```

## 8. Archive Emails (gog CLI)

```bash
# Search both accounts
gog gmail search '{repo} PR #{N}' -a your-personal-email@example.com -j \
  | python3 -c "import json,sys; [print(t['id']) for t in json.loads(sys.stdin.read()).get('threads',[])]" \
  | xargs -I{} gog gmail thread modify {} --remove INBOX -a your-personal-email@example.com -y

# Check acme-corp account
gog gmail search '{repo}' -a user@acme-corp.example.com -p
```

## 9. Cleanup Worktree

⛔ **A remocao ingenua (`worktree remove` + `branch -d`) foi REMOVIDA daqui.**
`git branch -d` RECUSA apos squash/rebase ("not fully merged") -- e este workflow
agora permite os tres metodos. E `worktree remove` sem guardas destroi WIP nao
commitado de outra sessao. So execute sob TODAS as guardas do procedimento canonico (Step 12).

```bash
# REFERENCIA: pr-governance-unified.md Step 12 (procedimento completo e guardado).
# Resumo das guardas, nesta ordem, ANTES de qualquer remocao:
#   1. PR state == MERGED  (ancestralidade nao serve para squash/rebase)
#   2. worktree resolvido pelo REGISTRO a partir de headRefName (nunca template)
#   3. `status --porcelain -uall --ignored` vazio (o `--porcelain` puro OMITE
#      arquivos ignorados, e o remove apagaria um `.env` de outra sessao)
#   4. ponta atual == headRefOid do PR (detecta commit feito APOS o merge)
# So entao: cd <raiz>; git worktree remove <path>
# 5. A delecao da branch e ATOMICA (expected-OID), nunca `branch -D` solto:
#    entre as guardas e a remocao outra sessao pode avancar a ref, e o `-D`
#    incondicional descartaria esse commit.
#      git update-ref -d "refs/heads/$BRANCH" "$MERGED_OID"  # recusa se avancou
# Remota: `ls-remote` distingue 0=existe · 2=ja removida · 128=erro (fail-closed)
```

## Tool Availability Matrix

| Tool | Binary | Purpose | Rate Limits |
|------|--------|---------|-------------|
| CodeRabbit CLI | `cr` / `coderabbit` | Local code review (primary) | ~1/25min free |
| Qodo CLI | `qodo` | Local code review (fallback) | Server-side limits |
| GitHub CLI | `gh` | PR ops, review audit | None |
| gog CLI | `gog` | Email search + archive | None |
| Gmail MCP | MCP server | Email read (fallback) | @gmail.com only |

## Anti-Patterns

```
X  git checkout/switch in main repo (use worktree)
X  Push without local CLI review
X  Merge without any review
X  qodo self-review without agent.toml
X  qodo -q (suppresses output)
X  gog gmail threads (use singular: thread)
X  Archiving emails BEFORE auditing reviews
X  Using Gmail MCP for @acme-corp.example.com (not connected)
```

---

*v1.1.0 | 2026-03-11 | Add worktree exception cross-reference + task-vs-bypass clarification*
*v1.0.0 | 2026-03-07 | Consolidated from pr-governance-unified.md + git-worktree-protocol.md + operational learnings*
