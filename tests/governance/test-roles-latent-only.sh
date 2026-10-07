#!/usr/bin/env bash
# Regressao de governanca: um contrato de papel organizacional so admite
# `status: latent`. Nenhuma superficie de contrato pode definir, permitir ou
# descrever uma transicao para `status: active`.
#
# Por que este teste existe
# -------------------------
# O PR #476 chegou a ter um gate de ratificacao em prosa (digest + registro do
# owner fora do arquivo). Nada o executava: o proprio texto dizia que o abuso
# seria "detectable after the fact, not prevented beforehand". A decisao foi
# tirar o gate do PR e deixar o papel so `latent` ate existir ferramenta
# (docs/adrs/ADR-019-role-activation-gate-deferred.md). Sem este teste, a
# invariante "nenhum caminho para active" volta a ser prosa e regride na
# primeira edicao.
#
# Escopo RESTRITO aos arquivos de contrato de papel. Um grep no repo inteiro
# por `status: active` daria falso positivo: varias SKILL.md usam
# `status: active` como estado de ciclo de vida da skill, que nao e papel.
#
# Contar a palavra "active" nao serve ("not-yet-active" e prosa legitima). O
# teste procura a FORMA de uma transicao: o valor citado (`active`), a chave
# `status: active`, ou um verbo de transicao seguido de active.

set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT" || exit 1

FAILED=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

CONTRACT_FILES=(
  agents/forge.md
  skills/agentic-tool-forge/SKILL.md
  skills/anima/kb/org-roles.md
)

# Fim de palavra portavel (BSD e GNU grep): active seguido de nao-[alnum_-].
END='([^[:alnum:]_-]|$)'
VERBS='to|become|becomes|becoming|make|makes|made|move|moves|moved|set|sets|ratify|ratifies|ratified|activate|activates'
TRANSITION_RE="(\`active\`|status:[[:space:]]*[\"']?active${END}|(${VERBS})[[:space:]]+((it|that contract|the contract)[[:space:]]+)?[\"'\`]?active${END})"

# Imprime as linhas (com numero) que descrevem uma transicao para active.
scan() { grep -n -i -E -- "$TRANSITION_RE" "$1" 2>/dev/null; }

# ── 0. O detector detecta (anti-vacuo) ───────────────────────────────────────
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '%s\n' \
  'it becomes `active` only by ratification' \
  'status: active' \
  'the owner ratifies it active through a record' \
  'moves it to "active"' > "$tmp/neg.md"
printf '%s\n' \
  'a not-yet-active role keeps its name' \
  'status: latent' \
  'the lifecycle field of a skill is unrelated' > "$tmp/pos.md"
neg_hits="$(scan "$tmp/neg.md" | wc -l | tr -d ' ')"
pos_hits="$(scan "$tmp/pos.md" | wc -l | tr -d ' ')"
if [ "$neg_hits" -eq 4 ] && [ "$pos_hits" -eq 0 ]; then
  pass "detector: 4/4 fixtures de transicao pegas, 0/3 falsos positivos"
else
  fail "detector furado: negativas=$neg_hits (esperado 4), positivas=$pos_hits (esperado 0)"
fi

# ── 1. Os arquivos de contrato existem (senao o teste passaria vazio) ────────
for f in "${CONTRACT_FILES[@]}"; do
  [ -f "$f" ] || fail "arquivo de contrato ausente: $f"
done
grep -q '^## Organizational Roles' agents/forge.md 2>/dev/null \
  || fail "secao '## Organizational Roles' ausente em agents/forge.md"

# ── 2. Nenhuma transicao para active nos arquivos de contrato ────────────────
for f in "${CONTRACT_FILES[@]}"; do
  [ -f "$f" ] || continue
  hits="$(scan "$f")"
  if [ -n "$hits" ]; then
    fail "$f descreve transicao para status active:"
    printf '%s\n' "$hits" | sed 's/^/      | /'
  else
    pass "$f: nenhuma transicao para active"
  fi
done

# ── 3. O template so admite `latent` e nao carrega campos de ativacao ────────
block="$(awk '/^Role contract fields/{f=1} f&&/^```yaml/{y=1;next} y&&/^```/{exit} y' agents/forge.md)"
if [ -z "$block" ]; then
  fail "template YAML do contrato nao encontrado em agents/forge.md"
else
  status_line="$(printf '%s\n' "$block" | grep -E '^status:' || true)"
  if printf '%s\n' "$status_line" | grep -qE '^status:[[:space:]]+latent([[:space:]]|$)'; then
    pass "template: status admite so latent"
  else
    fail "template: linha status invalida -> '${status_line:-<ausente>}'"
  fi
  live_keys="$(printf '%s\n' "$block" | grep -E '^(approval_ref|approved_by|approved_at|trigger|authority_digest):' || true)"
  if [ -n "$live_keys" ]; then
    fail "template ainda declara campos de ativacao como chaves vivas:"
    printf '%s\n' "$live_keys" | sed 's/^/      | /'
  else
    pass "template: sem approval_ref/approved_*/trigger/authority_digest vivos"
  fi
fi

# ── 4. A frase que nega autoridade ao status esta presente ───────────────────
if grep -qi 'status` never grants authority' agents/forge.md 2>/dev/null; then
  pass "forge.md declara que o status do arquivo nunca concede autoridade"
else
  fail "forge.md nao declara que o status do arquivo nunca concede autoridade"
fi

if [ "$FAILED" -eq 0 ]; then
  echo "  Status: PASSED"
else
  echo "  Status: FAILED"
fi
exit "$FAILED"
