#!/usr/bin/env bash
# /**
#  * reap-sessions.sh — safely prune STALE/ORPHAN git worktrees + merged orphan branches.
#  * @context  work-compass DETECTS stale/orphan; nothing REAPS. This closes the anti-theater loop.
#  * @reason   abandoned worktrees/branches accumulate in shared repos; manual cleanup never happens.
#  * @impact   dry-run DEFAULT · NEVER --force · NEVER -D · NEVER touches WIP or the main worktree ·
#  *           idempotent · good-neighbor (defers on index.lock) · session transcripts out of scope.
#  * @usage    reap-sessions.sh [--repo-dir DIR] [--stale-days N] [--apply] [--json]
#  * Stdlib + git only. AAIF cross-vendor. Layer-pure (no akasha/Vek deps). bash 3.2 safe. LF.
#  */
set -euo pipefail

REPO_DIR="$PWD"; STALE_DAYS=7; APPLY=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-dir)   [ $# -ge 2 ] || { echo "reap-sessions: --repo-dir requires a value" >&2; exit 2; }; REPO_DIR="$2"; shift 2;;
    --stale-days) [ $# -ge 2 ] || { echo "reap-sessions: --stale-days requires a value" >&2; exit 2; }; STALE_DAYS="$2"; shift 2;;
    --apply)      APPLY=1; shift;;
    --json)       JSON=1; shift;;
    -h|--help)    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "reap-sessions: unknown arg: $1" >&2; exit 2;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "reap-sessions: git not available" >&2; exit 1; }
git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "reap-sessions: not a git repo: $REPO_DIR" >&2; exit 1; }

# ── good-neighbor: defer if a peer holds the index lock (never fight a concurrent writer) ──
COMMON="$(cd "$REPO_DIR" 2>/dev/null && git rev-parse --git-common-dir)" \
  || { echo "reap-sessions: cannot access repo dir: $REPO_DIR" >&2; exit 1; }
case "$COMMON" in /*) ;; *) COMMON="$REPO_DIR/$COMMON";; esac
if [ -e "$COMMON/index.lock" ]; then
  if [ "$JSON" -eq 1 ]; then
    printf '{"deferred":true,"busy":true,"reason":"index.lock present — peer mutating; reaper yields"}\n'
  else
    echo "reap-sessions: defer — $COMMON/index.lock present (peer mutating); yielding (good-neighbor)"
  fi
  exit 0
fi

# MAIN_TOP = the TRUE main worktree (always the 1st `worktree list` entry), NOT --repo-dir's
# own toplevel — so pointing --repo-dir at a LINKED worktree still protects the real main
# checkout (qodo#161). Same string-form as the iteration source below → exact compare, and
# dodges macOS /private-var vs /var-folders canonicalization mismatch. Fallback for old git.
MAIN_TOP="$(git -C "$REPO_DIR" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
[ -n "$MAIN_TOP" ] || MAIN_TOP="$(git -C "$REPO_DIR" rev-parse --show-toplevel)"
NOW="$(date +%s)"
DEFAULT_BRANCH="$(git -C "$REPO_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
if [ -z "$DEFAULT_BRANCH" ]; then   # no origin/HEAD → prefer a REAL default; NEVER silently the current branch
  for _cand in main master; do      #   (else `branch --merged` would delete branches merged into a feature branch)
    if git -C "$REPO_DIR" show-ref --verify --quiet "refs/heads/$_cand"; then DEFAULT_BRANCH="$_cand"; break; fi
  done
fi
[ -n "$DEFAULT_BRANCH" ] || DEFAULT_BRANCH="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)"   # last resort

reaped_wt=(); skipped_wip=(); would_wt=(); reaped_br=(); would_br=(); held_stale=()

# Slug para consultar PRs. Falha silenciosa e aceitavel: sem slug, `gh` nao
# confirma merge e a via por idade cai no ramo "apenas relatado" -- fail-closed.
# `|| true` OBRIGATORIO: sob `set -euo pipefail` um repo SEM `origin` faz o
# `remote get-url` falhar, o pipefail propaga, e o script inteiro ABORTA.
# Medido: `tests/test-reap-sessions.sh` saia 2 sem imprimir uma linha sequer.
# (E meu teste manual "passou" porque li `$?` DEPOIS de um pipe -- o exit era
#  o do `sed`, nao o do subshell. Mesma armadilha que ja registrei antes.)
REPO_SLUG="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null \
  | sed -E 's#(git@|https://)[^:/]+[:/]##; s#\.git$##')" || true
[ -n "${REPO_SLUG:-}" ] || REPO_SLUG=""

# ── worktrees: eligible = (detached/orphan) OR (last-commit age > stale-days); reaped only if CLEAN ──
emit_wt() {
  local p="$1" b="$2" det="$3"
  [ -n "$p" ] || return 0
  [ "$p" = "$MAIN_TOP" ] && return 0          # NEVER the main worktree
  [ -d "$p" ] || return 0                      # admin-stale entry → handled by `worktree prune`
  local ts age elig=0 reason="" wt_state=""
  ts="$(git -C "$p" log -1 --format=%ct 2>/dev/null || echo 0)"
  age=$(( (NOW - ts) / 86400 ))
  [ "$age" -ge 0 ] || age=0          # clamp future-dated commits → never a spurious "stale" sign-flip
  # WIP guard PRIMEIRO. Sujo e o sinal mais forte e mais especifico: um
  # worktree com trabalho nao commitado e WIP, nao "stale sem prova". Deixar
  # a prova-de-termino antes disto classificaria um WIP sujo como `held`,
  # escondendo a informacao que o operador realmente precisa ver.
  # `--porcelain` sozinho OMITE ignorados: um worktree so com um `.env`
  # ignorado le como limpo, e o `worktree remove` entao TEM SUCESSO e o apaga
  # (medido -- o remove NAO recusa por ignorados). `-uall --ignored` fecha
  # isso. Falha de inspecao e fail-closed: pula, nunca remove as cegas.
  wt_state="$(git -C "$p" status --porcelain --untracked-files=all --ignored 2>/dev/null)" \
    || { skipped_wip+=("$p"); return 0; }
  if [ -n "$wt_state" ]; then
    skipped_wip+=("$p"); return 0
  fi

  # Detached NAO significa abandonado, e o registro do worktree E a fronteira
  # de ownership multi-sessao. Pior: um HEAD detached pode conter commits
  # alcancaveis SO por ele. Medido em repo descartavel -- `worktree remove`
  # apagou sem reclamar um detached com commit fora de toda branch; o objeto
  # sobrevive apenas ate o `gc`. So e seguro remover se NADA se perde, isto e,
  # se o HEAD ja esta contido em alguma branch.
  if [ "$det" -eq 1 ] || [ -z "$b" ]; then
    local head_oid contained=""
    head_oid="$(git -C "$p" rev-parse HEAD 2>/dev/null || true)"
    [ -n "$head_oid" ] && contained="$(git -C "$REPO_DIR" branch -a --contains "$head_oid" 2>/dev/null | head -1)"
    if [ -n "$contained" ]; then
      elig=1; reason="orphan-detached(head ja em branch)"
    else
      held_stale+=("$p (detached com commit FORA de toda branch — remover perderia trabalho)")
      return 0
    fi
  fi
  # Idade SOZINHA nao autoriza remocao. Um worktree limpo e ATIVO -- alguem
  # explorando, com tudo commitado, parado alguns dias -- some so por ser
  # antigo, e o `--apply` executa sem checar PR mergeado nem dono. Idade e
  # sinal de ABANDONO, nao prova dele: a prova e o PR da branch ter sido
  # mergeado. Sem `gh`, ou sem PR mergeado, o item e apenas RELATADO.
  if [ "$age" -gt "$STALE_DAYS" ] && [ -n "$b" ]; then
    local merged=""
    if command -v gh >/dev/null 2>&1; then
      merged="$(gh pr list -R "$REPO_SLUG" --head "$b" --state merged \
                  --limit 1 --json number --jq '.[0].number' 2>/dev/null || true)"
    fi
    # O PR mergeado precisa corresponder a PONTA ATUAL. Uma branch reusada, ou
    # que recebeu commits DEPOIS do merge, ainda casa o PR historico -- e isso
    # seria lido como prova de abandono de um trabalho que esta em curso.
    local pr_oid="" tip_oid=""
    if [ -n "$merged" ]; then
      pr_oid="$(gh pr view "$merged" -R "$REPO_SLUG" --json headRefOid \
                  --jq .headRefOid 2>/dev/null || true)"
      tip_oid="$(git -C "$p" rev-parse HEAD 2>/dev/null || true)"
      [ -n "$pr_oid" ] && [ "$pr_oid" = "$tip_oid" ] || {
        held_stale+=("$p (pr#${merged} mergeado, mas a ponta AVANCOU desde entao)")
        return 0; }
    fi
    if [ -n "$merged" ]; then
      elig=1; reason="${reason:+$reason,}stale-${age}d+pr#${merged}-merged"
    else
      # Relatado, NUNCA removido: nao ha evidencia de que o trabalho acabou.
      held_stale+=("$p (stale-${age}d, sem PR mergeado)")
      return 0
    fi
  fi
  [ "$elig" -eq 1 ] || return 0
  if [ "$APPLY" -eq 0 ]; then would_wt+=("$p ($reason)"); return 0; fi
  if git -C "$REPO_DIR" worktree remove "$p" >/dev/null 2>&1; then   # NO --force (belt-and-suspenders)
    reaped_wt+=("$p")
  else
    skipped_wip+=("$p")   # remove refused (e.g. became dirty mid-run) → keep, never force
  fi
}
_wp=""; _wb=""; _wd=0
while IFS= read -r line; do
  case "$line" in
    "worktree "*) [ -n "$_wp" ] && emit_wt "$_wp" "$_wb" "$_wd"; _wp="${line#worktree }"; _wb=""; _wd=0;;
    "branch "*)   _wb="${line#branch }"; _wb="${_wb#refs/heads/}";;
    "detached")   _wd=1;;
  esac
done < <(git -C "$REPO_DIR" worktree list --porcelain)
[ -n "$_wp" ] && emit_wt "$_wp" "$_wb" "$_wd"

[ "$APPLY" -eq 1 ] && git -C "$REPO_DIR" worktree prune >/dev/null 2>&1 || true

# ── branches: merged into default, not protected, not checked-out anywhere → safe `-d` ──
used_branches="$(git -C "$REPO_DIR" worktree list --porcelain | sed -n 's#^branch refs/heads/##p')"
while IFS= read -r b; do
  [ -n "$b" ] || continue
  case "$b" in main|master|develop) continue;; esac
  printf '%s\n' "$used_branches" | grep -qxF "$b" && continue
  if [ "$APPLY" -eq 0 ]; then would_br+=("$b"); continue; fi
  git -C "$REPO_DIR" branch -d "$b" >/dev/null 2>&1 && reaped_br+=("$b") || true   # -d refuses unmerged
done < <(git -C "$REPO_DIR" branch --merged "$DEFAULT_BRANCH" --format='%(refname:short)')

# ── output ──
jarr() {  # bash-3.2-safe JSON array from "$@" (escapes \ then " → valid JSON for downstream parsers)
  [ "$#" -eq 0 ] && { printf '[]'; return; }
  local out="" x e
  for x in "$@"; do
    e="${x//\\/\\\\}"; e="${e//\"/\\\"}"    # backslash FIRST, then double-quote
    out="$out\"$e\","
  done
  printf '[%s]' "${out%,}"
}
if [ "$JSON" -eq 1 ]; then
  printf '{"dry_run":%s,"repo":"%s","stale_days":%s,"reaped_worktrees":%s,"skipped_wip":%s,"would_reap_worktrees":%s,"reaped_branches":%s,"would_reap_branches":%s}\n' \
    "$([ "$APPLY" -eq 0 ] && echo true || echo false)" "$MAIN_TOP" "$STALE_DAYS" \
    "$(jarr "${reaped_wt[@]+"${reaped_wt[@]}"}")" \
    "$(jarr "${skipped_wip[@]+"${skipped_wip[@]}"}")" \
    "$(jarr "${would_wt[@]+"${would_wt[@]}"}")" \
    "$(jarr "${reaped_br[@]+"${reaped_br[@]}"}")" \
    "$(jarr "${would_br[@]+"${would_br[@]}"}")"
else
  echo "reap-sessions ($([ "$APPLY" -eq 0 ] && echo DRY-RUN || echo APPLY)) repo=$MAIN_TOP stale>${STALE_DAYS}d"
  if [ "$APPLY" -eq 0 ]; then
    printf '  would reap worktrees: %s\n' "${would_wt[*]:-(none)}"
    printf '  held (stale, unproven): %s\n' "${held_stale[*]:-(none)}"
    printf '  would reap branches : %s\n' "${would_br[*]:-(none)}"
    printf '  skip (WIP)          : %s\n' "${skipped_wip[*]:-(none)}"
    echo   "  → re-run with --apply to execute (WIP + main always preserved)"
  else
    printf '  reaped worktrees: %s\n' "${reaped_wt[*]:-(none)}"
    printf '  reaped branches : %s\n' "${reaped_br[*]:-(none)}"
    printf '  skip (WIP)      : %s\n' "${skipped_wip[*]:-(none)}"
  fi
fi
