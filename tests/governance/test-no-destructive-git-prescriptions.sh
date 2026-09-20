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
  # Fluxo LOCAL com `git merge` (nao PR): a ancestralidade E preservada, entao
  # `-d` e a verificacao CORRETA -- a recusa prova que a filha foi integrada.
  # Trocar por `-D` aqui enfraqueceria a seguranca.
  "docs/git-worktree-protocol.md|git branch -d feature/child-branch"
  # Tabela canonica do Step 9: mostra os TRES comandos lado a lado como
  # resultado possivel da resolucao, nao como default. Os tres sao isentos --
  # isentar so `--merge` reprovaria as outras duas linhas da MESMA tabela.
  # Os tres exemplos literais do Step 9 foram SUBSTITUIDOS por um unico
  # `gh pr merge <N> --"$MERGE_METHOD"` com enum-validacao, entao nao ha mais
  # metodo fixo a isentar aqui. As isencoes ficaram obsoletas e o proprio teste
  # as reprovou -- que e o comportamento projetado.
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
# Aplica-se ao FLUXO INTEIRO, uma vez -- nao por linha. Subshell por linha
# custava ~15s/2000 linhas (69k linhas x 5 scans ~ 44 min), o que FORCAVA um
# pre-`grep` cru ANTES da normalizacao -- e esse pre-filtro era o vetor de
# bypass circular: descartava a linha antes de normaliza-la. Com um unico
# passe sobre o fluxo ha UMA representacao, ja normalizada, e o filtro vem
# DEPOIS dela.
#
# CRASES: dentro de uma cerca ```bash/```sh a crase e SUBSTITUICAO DE COMANDO
# (executavel); fora dela e codigo inline do Markdown (prosa). A heuristica
# anterior -- preservar so quando precedida de `=` ou `(` -- deixava passar
# `echo \`git branch -D x\`` e a forma nua \`rm -rf .worktrees/x\`, ambas
# medidas escapando. O criterio correto e o ESTADO DE CERCA, entao o
# normalizador rastreia a abertura/fechamento e so apaga crases FORA de cerca
# executavel.
strip_stream() {
  awk -F: '
    function strip(t) {
      if (in_sh) {                       # dentro de cerca executavel:
        gsub(/`/, " ", t)                # crase e delimitador de substituicao
        return t                         # -- o conteudo E comando, preserva
      }
      # Acumula em `out` em vez de reescanear `t`: substituir por "`` " e
      # continuar o match sobre o texto JA substituido e laco infinito -- as
      # duas crases inseridas casam de novo, indefinidamente. Medido: 2028
      # linhas nao terminavam em 40s. `sed s///g` nao reescaneia; awk sim.
      out = ""
      while (match(t, /`[^`]*`/)) {
        out = out substr(t, 1, RSTART-1) "`` "
        t = substr(t, RSTART+RLENGTH)
      }
      return out t
    }
    {
      pre = $1 ":" $2 ":"
      body = substr($0, length(pre)+1)
      if (body ~ /^[[:space:]]*```/) {           # a propria linha de cerca
        if (in_fence) { in_fence=0; in_sh=0 }
        else { in_fence=1; in_sh = (body ~ /```[[:space:]]*(bash|sh|shell|zsh)/) }
        print pre body; next
      }
      body = strip(body)
      # Opcoes GLOBAIS do git entre `git` e o subcomando quebram todo padrao
      # que exige adjacencia. Medido: `git -C "$ROOT" branch -D feat/lost` numa
      # fixture ativa e o teste reportava PASSED. Normaliza-las aqui, na UNICA
      # representacao, conserta todos os scans de uma vez -- em vez de inchar
      # cada regex com uma alternancia propria.
      # Valores CITADOS podem conter espaco: `git -C "my path" branch -D x`.
      # Um `[^ ]+` pararia na primeira lacuna e a opcao global sobreviveria,
      # quebrando a adjacencia de novo. As alternativas de aspas vem ANTES da
      # forma sem aspas para casarem primeiro.
      while (match(body, /git +(-C +("[^"]*"|'"'"'[^'"'"']*'"'"'|[^ ]+)|-c +("[^"]*"|'"'"'[^'"'"']*'"'"'|[^ ]+)|--git-dir=("[^"]*"|[^ ]+)|--work-tree=("[^"]*"|[^ ]+)|--namespace=("[^"]*"|[^ ]+)|--exec-path=("[^"]*"|[^ ]+)|--no-pager|--paginate|-P|--bare|--literal-pathspecs) +/))
        body = substr(body,1,RSTART-1) "git " substr(body, RSTART+RLENGTH)
      sub(/^[[:space:]]*#.*$/, "", body)          # linha so de comentario
      sub(/[[:space:]]#.*$/, "", body)            # comentario ao final
      print pre body
    }'
}

# Padroes como REGEX: a forma literal `worktree remove --force` NAO casa a
# forma comum `git worktree remove "$W" --force` (caminho no meio). Medido: a
# fixture com essa forma nao era detectada. `--force` pode vir antes ou depois
# do caminho, entao ambas as ordens precisam casar.
# Aliases contam. Medido: `git worktree remove -f "$W"` e
# `git branch --delete --force feat/x` passavam -- `git worktree remove -h`
# define `-f` como sinonimo de `--force`, e `git branch -h` define
# `--delete --force` como equivalente a `-D`.
declare -a PATTERNS=(
  # `rm -h` define -r/-R/--recursive como equivalentes, e a ordem das flags e
  # livre: `rm -fr`, `rm -Rf`, `rm -f -r` sao o MESMO comando. Medido: so
  # `rm -rf` era detectado; as outras tres formas passavam.
  'rm +(-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*|--recursive +--force|--force +--recursive|-[rRf] +-[rRf]) +[^ ]*\.worktrees'
  'worktree remove ([^#]*(--force|-f)\b|(--force|-f)\b)'
  'git branch (-d|--delete)([^-]|$)'
  'git pull origin main'
)

# Junta continuacoes de shell (`\` no fim da linha) ANTES de qualquer varredura.
# Sem isto o scan e orientado a linha e `git worktree remove \` + `"$W" --force`
# passa batido -- bypass reproduzido: as tres formas destrutivas quebradas em duas
# linhas num arquivo ATIVO de rules/ e o teste retornava PASSED.
# Sem pre-filtro: filtrar arquivos pelo MESMO padrao seria circular -- o padrao
# nao casa nenhuma linha isolada justamente quando o comando esta quebrado, e o
# arquivo nunca seria selecionado. Medido: com pre-filtro, `git worktree remove \`
# + `"$W" --force` continuava passando. Varre tudo e deixa o filtro para depois.
join_continuations() {
  local f
  # -print0/read -d '': `for f in $(...)` quebra nomes com espaco. Medido:
  # `rules/zz espaco.md` com `rm -rf .worktrees/a` nao gerava violacao.
  while IFS= read -r -d '' f; do
    awk -v F="$f" '
      { line = $0
        if (buf == "") { start = FNR; joined = 0 }
        else { sub(/^[[:space:]]+/, " ", line); joined = 1 }
        sub(/\\[[:space:]]*$/, "", line)
        buf = buf line
        if ($0 ~ /\\[[:space:]]*$/) { next }
        # Normaliza TODA linha, nao so a juntada. O pre-filtro `grep` roda
        # ANTES da normalizacao, entao normalizar so depois chega tarde:
        # `rm  -rf<TAB>.worktrees/b` era descartado pelo filtro e nunca
        # alcancava a normalizacao -- medido. Verificado que nenhuma ancora da
        # ALLOWLIST usa espaco multiplo ou tab, entao colapsar aqui e seguro.
        gsub(/[[:space:]]+/, " ", buf)
        sub(/^ /, "", buf)
        print F ":" start ":" buf
        buf = "" }
      END { if (buf != "") { gsub(/[[:space:]]+/, " ", buf); sub(/^ /, "", buf); print F ":" start ":" buf } }' "$f"
    # `find -print0`, nao `grep -rlZ ''`: com padrao VAZIO o grep fica
    # aguardando stdin dentro de process substitution -- medido, travou.
  done < <(find "${SURFACES[@]}" -type f -print0 2>/dev/null)
}

echo "Governance regression: destructive git prescriptions"

for pat in "${PATTERNS[@]}"; do
  hits=0
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    file="${hit%%:*}"; rest="${hit#*:}"; line="${rest#*:}"
    # Fora de comentario e fora de crases o padrao sobrevive? Senao, e prosa.
    code="$line"   # ja normalizado por strip_stream
    printf '%s' "$code" | grep -qE -- "$pat" || continue
    is_allowed "$file" "$line" && continue
    fail "prescricao destrutiva: $file -> $(printf '%s' "$line" | cut -c1-72)"
    hits=$((hits + 1))
  done < <(join_continuations | strip_stream | grep -E -- ":[0-9]+:.*$pat")
  [ "$hits" -eq 0 ] && pass "nenhuma prescricao de '$pat'"
done

# `gh pr merge` com metodo LITERAL (o metodo precisa vir da resolucao Step 9).
hits=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file="${hit%%:*}"; rest="${hit#*:}"; line="${rest#*:}"
  code="$line"   # ja normalizado por strip_stream
  printf '%s' "$code" | grep -qE 'gh pr merge[^|]*--(merge|squash|rebase)\b' || continue
  is_allowed "$file" "$line" && continue
  fail "metodo de merge fixo: $file -> $(printf '%s' "$line" | cut -c1-72)"
  hits=$((hits + 1))
done < <(join_continuations | strip_stream | grep -E -- ':[0-9]+:.*gh pr merge[^|]*--(merge|squash|rebase)\b')
[ "$hits" -eq 0 ] && pass "nenhum 'gh pr merge' com metodo fixo"

# `git branch -D` executavel FORA do contexto guardado. O canonico usa
# `update-ref -d <ref> <expected-OID>`, que e ATOMICO: entre as guardas e a
# remocao outra sessao pode avancar a ref, e um `-D` solto descarta esse
# commit. Uma linha so escapa se ela mesma carregar o expected-OID.
hits=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file="${hit%%:*}"; rest="${hit#*:}"; line="${rest#*:}"
  code="$line"   # ja normalizado por strip_stream
  printf '%s' "$code" | grep -qE 'git branch -D' || continue
  # NAO ha isencao por conteudo da linha: `git branch -D` nao aceita
  # expected-OID, entao NENHUMA forma same-line dele e atomica. Mencionar
  # `MERGED_OID` num comentario ao lado nao torna o comando condicional --
  # isentar por isso seria recriar o buraco. A forma correta e outra COMANDO:
  # `git update-ref -d <ref> <expected>`.
  is_allowed "$file" "$line" && continue
  fail "branch -D sem expected-OID: $file -> $(printf '%s' "$line" | cut -c1-72)"
  hits=$((hits + 1))
done < <(join_continuations | strip_stream | grep -E -- ':[0-9]+:.*git branch -D')
[ "$hits" -eq 0 ] && pass "nenhum 'git branch -D' fora do contexto atomico"

# Um comando shell pode quebrar em varias linhas com `\`. Um scan por LINHA
# veria `gh api ... /merge \` sem o `-f merge_method=` que vem na seguinte, e
# acusaria falso positivo (medido no proprio arquivo canonico). Junte as
# continuacoes ANTES de casar, preservando o numero da primeira linha.

# Merge via REST SEM `merge_method`: o endpoint cai em merge commit por default,
# contradizendo em silencio todo repo que declara squash. O vetor REST nao era
# coberto pelas regras acima -- `gh pr merge` era, `gh api .../merge` nao.
hits=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file="${hit%%:*}"; rest="${hit#*:}"; line="${rest#*:}"
  code="$line"   # ja normalizado por strip_stream
  printf '%s' "$code" | grep -qE 'pulls/[^ ]*/merge' || continue
  printf '%s' "$code" | grep -q 'merge_method' && continue
  is_allowed "$file" "$line" && continue
  fail "merge REST sem merge_method: $file -> $(printf '%s' "$line" | cut -c1-72)"
  hits=$((hits + 1))
done < <(join_continuations | strip_stream | grep -E -- ':[0-9]+:.*pulls/[^ ]*/merge')
[ "$hits" -eq 0 ] && pass "nenhum merge REST sem merge_method"

# Delecao de ref via REST: o endpoint delete-ref NAO tem parametro de
# expected-OID, entao NAO PODE ser atomico. A forma segura e o lease no push.
hits=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file="${hit%%:*}"; rest="${hit#*:}"; line="${rest#*:}"
  code="$line"   # ja normalizado por strip_stream
  printf '%s' "$code" | grep -qE '\-X DELETE.*git/refs/heads' || continue
  is_allowed "$file" "$line" && continue
  fail "delete-ref via REST (nao atomizavel): $file -> $(printf '%s' "$line" | cut -c1-72)"
  hits=$((hits + 1))
done < <(join_continuations | strip_stream | grep -E -- ':[0-9]+:.*\-X DELETE.*git/refs/heads')
[ "$hits" -eq 0 ] && pass "nenhum delete-ref via REST"

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
git branch -D feat/solta   # sem expected-OID: descarta commit concorrente
git branch -D "$B"   # MERGED_OID no comentario NAO torna o -D atomico
git update-ref -d "refs/heads/$BRANCH" "$MERGED_OID"   # atomico: NAO deve contar
gh api -X PUT /repos/o/r/pulls/1/merge   # sem merge_method: cai em merge commit
gh api -X DELETE /repos/o/r/git/refs/heads/feat   # delete-ref nao e atomizavel
gh api -X PUT /repos/o/r/pulls/1/merge -f merge_method="$M"   # correto: NAO conta
```

Formas QUEBRADAS por continuacao de shell. Sem normalizar o `\` final, o scan
orientado a linha nao ve nenhum comando completo e reporta PASSED -- bypass
puramente sintatico, reproduzido antes da correcao.

```bash
git worktree remove \
  "$W" --force
rm -rf \
  .worktrees/y
gh pr merge 2 \
  --squash
git branch -D \
  feat/quebrada
gh api -X PUT \
  /repos/o/r/pulls/2/merge
gh api -X DELETE \
  /repos/o/r/git/refs/heads/outra
git update-ref -d \
  "refs/heads/$B" "$MERGED_OID"
```

Formas ALIAS, espaco alternativo e substituicao de comando. Todas executaveis,
todas passavam antes: `-f` e sinonimo de `--force`; `--delete --force` equivale
a `-D`; tab/espaco-duplo sao validos em shell; e crase pode ser substituicao de
comando, nao prosa Markdown.

```bash
git worktree remove -f "$W"
git branch --delete --force feat/alias
rm  -rf	.worktrees/tab
```

Substituicao de comando DENTRO de cerca executavel -- as tres formas. Fora de
cerca, crase e codigo inline do Markdown (prosa) e deve continuar isenta; a
distincao e o ESTADO DE CERCA, nao um caractere vizinho.

```bash
result=`git branch -D feat/subst`
echo `git branch -D feat/eco`
`rm -rf .worktrees/nua`
```

Prosa com crase FORA de cerca, que NAO deve contar: `rm -rf .worktrees/x` e
`git branch -D feat/prosa`.

Opcoes GLOBAIS do git entre `git` e o subcomando -- quebram qualquer padrao que
exija adjacencia literal.

```bash
git -C "$ROOT" branch -D feat/globalopt
git --no-pager -C /x worktree remove -f "$W"
git -C "my path" branch -D feat/citado
rm -fr .worktrees/variante-fr
rm -Rf .worktrees/variante-Rf
rm -f -r .worktrees/variante-separada
```

Prosa citando `rm -rf .worktrees/x` e `gh pr merge 1 --merge` nao e prescricao.
# comentario puro sobre rm -rf .worktrees/x
FIX
  # ⚠️ Conte APENAS linhas de achado. `grep -c FAIL` contaria tambem o
  #    `Status: FAILED` do sumario -- foi assim que 2 achados + 1 status
  #    bateram os "3" esperados e mascararam um padrao que nao casava.
  out=$(DGP_NESTED=1 bash "$0" "$FIXT" 2>&1)
  neg=$(printf '%s\n' "$out" \
    | grep -cE 'prescricao destrutiva|metodo de merge fixo|branch -D sem expected-OID|merge REST sem|delete-ref via REST')
  # 13 achados: 7 em linha unica + 6 quebrados por continuacao. NAO devem contar:
  # a prosa entre crases, o comentario puro, e as DUAS formas de `update-ref`
  # atomico (em linha e quebrada) -- que sao a forma CERTA.
  # As fixtures quebradas sao PERSISTENTES de proposito: verificar so com fixture
  # temporaria prova a correcao uma vez, nao impede a regressao.
  if [ "${neg:-0}" -eq 25 ]; then
    pass "fixtures negativas: 25 (linha + continuacao + alias/ws + cerca + git-opts + rm-variantes)"
  else
    fail "fixtures negativas: esperado 25 achados, obtido ${neg:-0} — filtro furado"
    printf '%s\n' "$out" | sed 's/^/      | /'
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
