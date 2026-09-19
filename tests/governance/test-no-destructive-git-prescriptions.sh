#!/usr/bin/env bash
# Regressao de governanca: nenhuma superficie ATIVA pode prescrever um comando
# git destrutivo ou uma base/metodo fixos.
#
# Por que este teste existe
# -------------------------
# No PR #436 o mesmo procedimento de cleanup foi encontrado em QUATRO copias
# divergentes, e o merge incondicional em SEIS pontos. Quatro varreduras
# manuais sucessivas deixaram copias para tras -- cada rodada de revisao
# achava mais uma. Varredura manual nao e controle; este teste e.
#
# O que e proibido (em rules/ skills/ protocols/ agents/ commands/ docs/)
#   1. `rm -rf .worktrees/...`        -> ignora toda checagem do git; apaga WIP
#                                        nao commitado, inclusive de outra sessao
#   2. `git worktree remove --force`  -> idem, medido: remove arquivo nao
#                                        rastreado sem aviso
#   3. `git branch -d <x>`            -> RECUSA apos squash/rebase; a remocao
#                                        deve ser autorizada por PR MERGED
#   4. `git pull origin main`         -> base fixa; mergear em `develop` e puxar
#                                        `main` deixa o local na branch errada
#   5. `gh pr merge ... --merge`      -> metodo fixo; contraria repos que
#                                        declaram squash e e REJEITADO em
#                                        repos squash-only
#
# Isencoes (linhas com contexto legitimo) estao em ALLOWLIST, cada uma com
# justificativa verificavel. Uma isencao que deixe de casar tambem FALHA o
# teste, para que allowlist obsoleta nao vire buraco silencioso.

set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT" || exit 1

FAILED=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

SURFACES=(rules skills protocols agents commands docs)

# ── Isencoes: "<arquivo>:<trecho ancora>" + motivo ───────────────────────────
# Cada entrada precisa CASAR com uma linha real; isencao obsoleta e falha.
ALLOWLIST=(
  # `git merge --no-ff` local PRESERVA ancestralidade -- ali `-d` e o comando
  # certo e verifica a integracao de verdade. Trocar por `-D` enfraqueceria.
  "protocols/hierarchical-merge-protocol.md|git branch -d feature/task-A"
  # Puxa o `main` do PROPRIO framework, que e de fato sua branch default.
  "docs/framework-consumption.md|git pull origin main"
  # Tabela canonica do Step 9: mostra os TRES comandos lado a lado como
  # resultado possivel da resolucao, nao como default. Os tres sao isentos --
  # isentar so `--merge` reprovaria as outras duas linhas da MESMA tabela.
  "rules/pr-governance-unified.md|gh pr merge <N> --merge     # resolução produziu"
  "rules/pr-governance-unified.md|gh pr merge <N> --squash    # resolução produziu"
  "rules/pr-governance-unified.md|gh pr merge <N> --rebase    # resolução produziu"
)

is_allowed() {
  local file="$1" line="$2" entry af at
  for entry in "${ALLOWLIST[@]}"; do
    af="${entry%%|*}"; at="${entry#*|}"
    [ "$file" = "$af" ] || continue
    case "$line" in *"$at"*) return 0;; esac
  done
  return 1
}

# Uma linha so conta se o comando aparece em posicao EXECUTAVEL.
#
# Filtrar por vocabulario ("nunca", "apaga", "conforme a resolucao") era um
# buraco: bastava anexar um comentario para escapar --
#   `gh pr merge 1 --merge   # conforme a resolucao`  passava.
# O discriminador correto e ESTRUTURAL, nao lexical:
#   1. o que vem depois de ` #` e comentario -> nao executa;
#   2. o que esta entre crases e citacao em prosa -> nao executa.
# Removidas as duas camadas, se o padrao SOBREVIVE ele esta em posicao de
# comando. Nenhuma palavra isenta uma linha executavel.
strip_noncode() {
  printf '%s' "$1" \
    | sed -e 's/`[^`]*`/`` /g' \
          -e 's/^[[:space:]]*#.*$//' \
          -e 's/[[:space:]]#.*$//'
}

declare -a PATTERNS=(
  'rm -rf .worktrees'
  'worktree remove --force'
  'git branch -d '
  'git pull origin main'
)

echo "Governance regression: destructive git prescriptions"

for pat in "${PATTERNS[@]}"; do
  hits=0
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    file="${hit%%:*}"; rest="${hit#*:}"; line="${rest#*:}"
    # Fora de comentario e fora de crases o padrao sobrevive? Senao, e prosa.
    code=$(strip_noncode "$line")
    case "$code" in *"$pat"*) ;; *) continue;; esac
    is_allowed "$file" "$line" && continue
    fail "prescricao destrutiva: $file -> $(printf '%s' "$line" | cut -c1-72)"
    hits=$((hits + 1))
  done < <(grep -rn -- "$pat" "${SURFACES[@]}" 2>/dev/null)
  [ "$hits" -eq 0 ] && pass "nenhuma prescricao de '$pat'"
done

# `gh pr merge` com metodo LITERAL (o metodo precisa vir da resolucao Step 9).
hits=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file="${hit%%:*}"; rest="${hit#*:}"; line="${rest#*:}"
  code=$(strip_noncode "$line")
  printf '%s' "$code" | grep -qE 'gh pr merge[^|]*--(merge|squash|rebase)\b' || continue
  is_allowed "$file" "$line" && continue
  fail "metodo de merge fixo: $file -> $(printf '%s' "$line" | cut -c1-72)"
  hits=$((hits + 1))
done < <(grep -rnE 'gh pr merge[^|]*--(merge|squash|rebase)\b' "${SURFACES[@]}" 2>/dev/null)
[ "$hits" -eq 0 ] && pass "nenhum 'gh pr merge' com metodo fixo"

# ── Fixtures NEGATIVAS: o teste precisa REPROVAR comando mau comentado.
#    Sem isto, um filtro furado passa despercebido -- foi exatamente o buraco
#    da versao anterior (`... --merge   # conforme a resolucao` escapava).
#    A execucao aninhada precisa da guarda DGP_NESTED: sem ela ela rodaria as
#    proprias fixtures e o teste recursaria sem fim.
if [ "${DGP_NESTED:-0}" != "1" ]; then
  FIXT=$(mktemp -d); trap 'rm -rf "$FIXT"' EXIT
  mkdir -p "$FIXT/rules"
  cat > "$FIXT/rules/fixture.md" <<'FIX'
```bash
gh pr merge 1 --merge   # conforme a resolucao
rm -rf .worktrees/x   # apaga WIP
git worktree remove "$W" --force   # nunca faca isso
```
Prosa citando `rm -rf .worktrees/x` e `gh pr merge 1 --merge` nao e prescricao.
# comentario puro sobre rm -rf .worktrees/x
FIX
  neg=$(DGP_NESTED=1 bash "$0" "$FIXT" 2>&1 | grep -c 'FAIL')
  # 3 comandos executaveis com comentario anexado devem ser reprovados;
  # a prosa entre crases e o comentario puro NAO devem contar.
  if [ "${neg:-0}" -eq 3 ]; then
    pass "fixtures negativas: 3 reprovadas, prosa/comentario isentos"
  else
    fail "fixtures negativas: esperado 3 reprovacoes, obtido ${neg:-0} — filtro furado"
  fi
fi

# Allowlist obsoleta e buraco silencioso: exija que cada isencao ainda case.
# No run ANINHADO (fixtures) o root e um tmpdir: os arquivos reais nao existem
# la, e checar isencoes inflaria a contagem de FAIL que a fixture mede.
if [ "${DGP_NESTED:-0}" != "1" ]; then
  for entry in "${ALLOWLIST[@]}"; do
    af="${entry%%|*}"; at="${entry#*|}"
    if [ ! -f "$af" ]; then
      fail "isencao aponta arquivo inexistente: $af"
    elif ! grep -qF -- "$at" "$af" 2>/dev/null; then
      fail "isencao obsoleta (nao casa mais): $af -> $at"
    fi
  done
  [ "$FAILED" -eq 0 ] && pass "todas as isencoes ainda casam"
fi

if [ "$FAILED" -eq 0 ]; then
  echo "  Status: PASSED"
else
  echo "  Status: FAILED"
fi
exit "$FAILED"
