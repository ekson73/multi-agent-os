#!/usr/bin/env bash
# /**
#  * test-reap-sessions.sh — TDD contract for bin/reap-sessions.sh
#  * @context  The reaper is destructive-capable; its safety invariants MUST be pinned by tests.
#  * @reason   work-compass DETECTS stale/orphan but nothing REAPS — this closes the loop safely.
#  * @impact   Guarantees: never --force, never -D, never touch WIP, never touch main, idempotent.
#  */
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAPER="$HERE/../bin/reap-sessions.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  ✗ %s\n' "$1"; }
chk()  { if eval "$2"; then ok "$1"; else bad "$1 — [$2]"; fi; }

# ── fixture: a throwaway repo with 3 linked worktrees + 1 merged orphan branch ──
SBX="$(mktemp -d)"; trap 'rm -rf "$SBX"' EXIT
R="$SBX/repo"
git init -q -b main "$R"
git -C "$R" config user.email t@t.t; git -C "$R" config user.name t
echo base > "$R/f"; git -C "$R" add f; git -C "$R" commit -qm init
OLD='2020-01-01T00:00:00'   # backdated → "stale" past any reasonable --stale-days

mkwt() { # name  date  -> worktree at $R/.worktrees/<name> on branch wt/<name>
  git -C "$R" worktree add -q "$R/.worktrees/$1" -b "wt/$1" >/dev/null
  echo "$1" > "$R/.worktrees/$1/x"
  git -C "$R/.worktrees/$1" add -A
  GIT_AUTHOR_DATE="$2" GIT_COMMITTER_DATE="$2" git -C "$R/.worktrees/$1" commit -qm "$1"
}
# Stub de `gh`: a via por IDADE agora exige prova de PR MERGEADO para aquela
# branch -- idade e sinal de abandono, nao prova. O stub responde com um numero
# de PR SO para `wt/stale-clean`; qualquer outra branch devolve vazio, que e o
# caminho "held" (relatado, nunca removido).
mkwt stale-clean  "$OLD"                 # old + clean + PR MERGEADO   → REAP
mkwt stale-wip    "$OLD"                 # old + dirty                 → SKIP (WIP)
mkwt stale-nopr   "$OLD"                 # old + clean SEM PR mergeado → HELD
# Branch REUSADA: existe PR mergeado, mas a ponta AVANCOU depois dele. O PR
# historico nao prova que o trabalho atual acabou -> HELD, nunca reap.
mkwt stale-reused "$OLD"
REUSED_OLD_OID="$(git -C "$R/.worktrees/stale-reused" rev-parse HEAD)"
GIT_AUTHOR_DATE="$OLD" GIT_COMMITTER_DATE="$OLD" \
  git -C "$R/.worktrees/stale-reused" commit -q --allow-empty -m "commit APOS o merge"

STUB="$(mktemp -d)"
cat > "$STUB/gh" <<GH
#!/usr/bin/env bash
# Implementa o minimo que o reaper consulta:
#   pr list --head <branch> --state merged   -> numero do PR
#   pr view <n> --json headRefOid            -> OID da ponta daquele PR
# O PR mergeado precisa casar a PONTA ATUAL; devolvemos o HEAD real de
# wt/stale-clean para que o caminho de remocao seja de fato exercitado.
sub="\$1\$2"
head=""; prev=""
for a in "\$@"; do [ "\$prev" = "--head" ] && head="\$a"; prev="\$a"; done
case "\$sub" in
  prlist) case "\$head" in
            wt/stale-clean)  echo 4242 ;;
            wt/stale-reused) echo 7777 ;;
            *) : ;;
          esac ;;
  prview) case "\$3" in
            4242) git -C "$R/.worktrees/stale-clean" rev-parse HEAD ;;
            7777) echo "$REUSED_OLD_OID" ;;   # OID ANTIGO: a ponta ja avancou
          esac ;;
esac
GH
chmod +x "$STUB/gh"
PATH="$STUB:$PATH"; export PATH

echo dirty > "$R/.worktrees/stale-wip/wip-uncommitted"   # make it dirty
mkwt fresh-clean  "$(date +%Y-%m-%dT%H:%M:%S)"           # recent + clean → UNTOUCHED (age guard)

# eligible (old) + "clean" por `--porcelain` puro, MAS com um arquivo IGNORADO.
# Medido: `worktree remove` NAO recusa por ignorados -- ele teria SUCESSO e
# destruiria o `.env`. A guarda precisa de `-uall --ignored` para ver isso.
mkwt stale-ignored "$OLD"
printf 'secret.env\n' > "$R/.worktrees/stale-ignored/.gitignore"
git -C "$R/.worktrees/stale-ignored" add .gitignore
GIT_AUTHOR_DATE="$OLD" GIT_COMMITTER_DATE="$OLD" \
  git -C "$R/.worktrees/stale-ignored" commit -qm ignore-rule
printf 'TOKEN=nao-perder\n' > "$R/.worktrees/stale-ignored/secret.env"

# a merged orphan branch (no worktree) → safe -d ; and an UNMERGED branch → must survive
git -C "$R" branch merged-orphan main
git -C "$R" branch -q unmerged-keep main
git -C "$R" worktree add -q "$R/.worktrees/a-unmerged" unmerged-keep >/dev/null
echo z > "$R/.worktrees/a-unmerged/z"; git -C "$R/.worktrees/a-unmerged" add z; git -C "$R/.worktrees/a-unmerged" commit -qm um
git -C "$R" worktree remove "$R/.worktrees/a-unmerged"   # branch unmerged-keep now has unmerged commit, no worktree

[ -x "$REAPER" ] || { echo "RED: $REAPER not executable yet (expected pre-impl)"; exit 1; }

# ── 1. DRY-RUN (default): reports, mutates nothing ──────────────────────────────
DRY="$("$REAPER" --repo-dir "$R" --stale-days 7 --json)"
chk "dry-run: stale-clean is a reap candidate"      "echo '$DRY' | grep -q stale-clean"
chk "dry-run: stale-wip flagged as WIP-skip"        "echo '$DRY' | grep -q stale-wip"
chk "dry-run: dry_run=true"                          "echo '$DRY' | grep -q '\"dry_run\"[: ]*true'"
chk "dry-run: NOTHING removed (stale-clean still on disk)" "[ -e '$R/.worktrees/stale-clean/x' ]"
chk "dry-run: fresh-clean NOT a candidate (age guard)"     "! echo '$DRY' | grep -q '\"reap\".*fresh-clean'"

# ── 2. APPLY: removes only the eligible+clean; preserves WIP + fresh ────────────
APP="$("$REAPER" --repo-dir "$R" --stale-days 7 --apply --json)"
chk "apply: stale-clean worktree removed"           "[ ! -e '$R/.worktrees/stale-clean' ]"
chk "apply: stale-wip PRESERVED (WIP never reaped)" "[ -e '$R/.worktrees/stale-wip/wip-uncommitted' ]"
chk "apply: fresh-clean PRESERVED (age guard)"      "[ -e '$R/.worktrees/fresh-clean/x' ]"
chk "apply: stale-ignored PRESERVADO (ignorado conta como WIP)" \
  "[ -e '$R/.worktrees/stale-ignored/secret.env' ]"
chk "apply: conteudo do ignorado intacto" \
  "grep -q nao-perder '$R/.worktrees/stale-ignored/secret.env'"
chk "apply: merged-orphan branch deleted"           "! git -C '$R' branch --list merged-orphan | grep -q ."
chk "apply: unmerged-keep branch SURVIVES"          "git -C '$R' branch --list unmerged-keep | grep -q ."
chk "apply: main worktree untouched"                "[ -e '$R/f' ]"
chk "held: stale SEM PR mergeado nao e removido"     "[ -e '$R/.worktrees/stale-nopr/x' ]"
chk "held: branch REUSADA (PR antigo) nao e removida" "[ -e '$R/.worktrees/stale-reused/x' ]"
chk "held: JSON expoe held_stale com o motivo"       "echo '$APP' | grep -q '\"held_stale\"[^]]*stale-reused'"
chk "held: aparece na lista held, nao em reaped"     "echo '$APP' | grep -qv '\"reaped_worktrees\"[^]]*stale-nopr'"
chk "apply: JSON reports dry_run=false"             "echo '$APP' | grep -q '\"dry_run\"[: ]*false'"
chk "apply: JSON reaped_worktrees lists stale-clean" "echo '$APP' | grep -q '\"reaped_worktrees\"[^]]*stale-clean'"

# ── 3. IDEMPOTENT: re-apply is a no-op (nothing left eligible+clean) ────────────
RE="$("$REAPER" --repo-dir "$R" --stale-days 7 --apply --json)"
chk "idempotent: 2nd apply reaps 0 worktrees"       "echo '$RE' | grep -qE '\"reaped_worktrees\"[: ]*\[[[:space:]]*\]'"

# ── 4. good-neighbor: defers if index.lock present (peer mutating) ──────────────
: > "$R/.git/index.lock"
LK="$("$REAPER" --repo-dir "$R" --stale-days 7 --apply --json || true)"
chk "good-neighbor: defers on index.lock"            "echo '$LK' | grep -qiE 'defer|busy|index.lock'"
rm -f "$R/.git/index.lock"

# ── 5. main-worktree guard anchors to the TRUE main even when --repo-dir points at a
#       LINKED worktree (qodo#161): MAIN_TOP = `worktree list` head, NOT --repo-dir's own
#       toplevel. Pre-fix, --repo-dir=<linked-wt> made `repo` the linked wt (and the real
#       main could surface as a candidate); post-fix `repo` is always the true main. ──────
MAIN_REAL="$(git -C "$R" worktree list --porcelain | sed -n '1s/^worktree //p')"
MP="$("$REAPER" --repo-dir "$R/.worktrees/fresh-clean" --stale-days 7 --json)"
chk "mis-point: reaper anchors to TRUE main (repo == main, not the linked worktree)" \
    "echo '$MP' | grep -qF '\"repo\":\"$MAIN_REAL\"'"
chk "mis-point: main worktree file still intact"     "[ -e '$R/f' ]"

echo "── reaper: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
