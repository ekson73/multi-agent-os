#!/usr/bin/env bash
# Regressao de governanca: um contrato de papel organizacional so admite
# `status: latent` (ADR-019). Este teste mede ESTRUTURA, por allowlist:
#
#   - em cada bloco de contrato, `status` aparece uma vez e vale exatamente
#     `latent`;
#   - `tier` so vale `null`;
#   - os campos reservados (approval_ref, approved_by, approved_at, trigger,
#     authority_digest) so existem vazios ou null, em qualquer nivel de
#     indentacao, e sem filhos;
#   - nenhuma chave booleana de ativacao (active, enabled, armed, effective,
#     activated) com valor diferente de null/false.
#
# Onde: o template YAML de agents/forge.md e todo arquivo sob `roles/`
# (o registro de papeis que forge.md propoe; hoje vazio).
#
# Alem disso, nos tres arquivos de orientacao, procura a FORMA `active` de
# uma transicao (`active` citado, `status: active`, verbo + active).
#
# LIMITE declarado: o teste NAO entende linguagem natural. Uma frase como
# "the role is activated by the owner" ou "the role goes live" em prosa nao
# e detectada. Ele guarda a forma dos contratos e a palavra `active`, nao o
# significado de qualquer texto.
#
# Escopo restrito de proposito: varias SKILL.md usam `status: active` como
# ciclo de vida da propria skill, que nao e papel; um grep no repo inteiro
# daria falso positivo.

set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT" || exit 1

FAILED=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

GUIDANCE_FILES=(
  agents/forge.md
  skills/agentic-tool-forge/SKILL.md
  skills/anima/kb/org-roles.md
)

# ── Verificador estrutural (allowlist) ───────────────────────────────────────
# Le arquivos e imprime uma violacao por linha. Modo `--block` le um bloco
# YAML puro da stdin (usado pelas fixtures).
CHECKER='
import re, sys

RESERVED = {"approval_ref", "approved_by", "approved_at", "trigger", "authority_digest"}
BOOL_KEYS = {"active", "enabled", "armed", "effective", "activated"}
EMPTY = {"", "null", "~", "[]", "{}", "\"\"", "'"''"'"}
KEY = re.compile(r"^(\s*)(-\s+)?([A-Za-z_][A-Za-z0-9_-]*)\s*:(.*)$")

def value(raw):
    v = raw.split(" #", 1)[0].strip()
    if v.startswith("#"):
        v = ""
    return v

def strip_quotes(v):
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'"'"'":
        return v[1:-1]
    return v

def check_block(lines, where):
    out = []
    rows = []
    for n, line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = KEY.match(line)
        rows.append((n, line, m))
    statuses = [(n, value(m.group(4))) for n, l, m in rows if m and m.group(3) == "status"]
    is_contract = statuses or any(m and m.group(3) in ({"role", "tier"} | RESERVED) for _, _, m in rows)
    if not is_contract:
        return out
    if len(statuses) != 1:
        out.append(f"{where}: `status` aparece {len(statuses)} vezes (esperado 1)")
    for n, v in statuses:
        if strip_quotes(v) != "latent":
            out.append(f"{where}:{n}: status = {v!r} (so `latent` e admitido)")
    for i, (n, line, m) in enumerate(rows):
        if not m:
            continue
        key, v = m.group(3), value(m.group(4))
        if key == "tier" and v not in EMPTY:
            out.append(f"{where}:{n}: tier = {v!r} (so null e admitido)")
        if key in BOOL_KEYS and strip_quotes(v).lower() not in EMPTY | {"false", "no", "off"}:
            out.append(f"{where}:{n}: chave de ativacao `{key}` = {v!r}")
        if key in RESERVED:
            if v not in EMPTY:
                out.append(f"{where}:{n}: campo reservado `{key}` = {v!r} (so vazio/null)")
            indent = len(m.group(1))
            if i + 1 < len(rows):
                nl = rows[i + 1][1]
                if len(nl) - len(nl.lstrip()) > indent:
                    out.append(f"{where}:{n}: campo reservado `{key}` tem filhos")
    return out

def blocks_of(path, text):
    lines = text.split("\n")
    if path.endswith((".yml", ".yaml")):
        yield [(i + 1, l) for i, l in enumerate(lines)]
        return
    i = 0
    if lines and lines[0].strip() == "---":
        j = 1
        while j < len(lines) and lines[j].strip() != "---":
            j += 1
        yield [(k + 1, lines[k]) for k in range(1, j)]
        i = j + 1
    cur = None
    for k in range(i, len(lines)):
        s = lines[k].strip()
        if cur is None and re.match(r"^```\s*ya?ml\b", s):
            cur = []
        elif cur is not None and s.startswith("```"):
            yield cur
            cur = None
        elif cur is not None:
            cur.append((k + 1, lines[k]))

if sys.argv[1] == "--block":
    text = sys.stdin.read()
    for v in check_block([(i + 1, l) for i, l in enumerate(text.split("\n"))], "fixture"):
        print(v)
    sys.exit(0)

for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    for b in blocks_of(path, text):
        for v in check_block(b, path):
            print(v)
'
# Erro do verificador vira violacao: um crash nunca pode passar como "ok".
structural() {
  local out rc
  out="$(python3 -c "$CHECKER" "$@" 2>&1)"; rc=$?
  [ -n "$out" ] && printf '%s\n' "$out"
  [ "$rc" -eq 0 ] || printf 'verificador estrutural falhou (rc=%s)\n' "$rc"
}

# Forma `active` de transicao (prosa ou chave), so nos arquivos de orientacao.
END='([^[:alnum:]_-]|$)'
VERBS='to|become|becomes|becoming|make|makes|made|move|moves|moved|set|sets|ratify|ratifies|ratified|activate|activates|promote|promotes|promoted'
TRANSITION_RE="(\`active\`|status:[[:space:]]*[\"']?active${END}|(${VERBS})[[:space:]]+((it|that contract|the contract|the role)[[:space:]]+)?(to[[:space:]]+)?[\"'\`]?active${END})"
transition() { grep -n -i -E -- "$TRANSITION_RE" "$1" 2>/dev/null; }

command -v python3 >/dev/null 2>&1 || { fail "python3 ausente: verificador estrutural nao roda"; echo "  Status: FAILED"; exit 1; }

# ── 0. Os detectores detectam (anti-vacuo) ───────────────────────────────────
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Cada sonda estrutural precisa gerar pelo menos uma violacao.
probe() { # <nome> <bloco>
  local out hits; out="$(printf '%s\n' "$2" | structural --block)"
  case "$out" in *"verificador estrutural falhou"*) fail "sonda quebrou o verificador: $1"; return;; esac
  hits="$(printf '%s' "$out" | grep -c . )"
  if [ "$hits" -ge 1 ]; then pass "sonda estrutural pega: $1"; else fail "sonda estrutural escapou: $1"; fi
}
probe "status: active"          $'role: x\nstatus: active'
probe "status: effective"       $'role: x\nstatus: effective'
probe "status: enabled"         $'role: x\nstatus: "enabled"'
probe "status duplicado"        $'role: x\nstatus: latent\nstatus: enabled'
probe "status ausente"          $'role: x\ntier: null'
probe "tier nao nulo"           $'role: x\nstatus: latent\ntier: z1-local-write'
probe "approval_ref preenchido" $'role: x\nstatus: latent\napproval_ref: https://example.invalid/1'
probe "approval_ref aninhado"   $'role: x\nstatus: latent\nroles_meta:\n  approval_ref: rec-1'
probe "approval_ref com filhos" $'role: x\nstatus: latent\napproval_ref:\n  url: rec-1'
probe "trigger preenchido"      $'role: x\nstatus: latent\ntrigger: "queue > 10"'
probe "active: true"            $'role: x\nstatus: latent\nactive: true'
probe "enabled: yes aninhado"   $'role: x\nstatus: latent\nflags:\n  enabled: yes'

ok_hits="$(printf '%s\n' $'role: x\nstatus: latent # comment\ntier: null\napproval_ref: null\napproved_by: ~\ntrigger:\nproposal_cap: null' | structural --block | wc -l | tr -d ' ')"
if [ "$ok_hits" -eq 0 ]; then pass "contrato valido nao gera violacao"; else fail "falso positivo no contrato valido ($ok_hits)"; fi

printf '%s\n' 'it becomes `active` only by ratification' 'status: active' \
  'the owner ratifies it active through a record' 'promote the role to active status' > "$tmp/neg.md"
printf '%s\n' 'a not-yet-active role keeps its name' 'status: latent' > "$tmp/pos.md"
n="$(transition "$tmp/neg.md" | wc -l | tr -d ' ')"; p="$(transition "$tmp/pos.md" | wc -l | tr -d ' ')"
if [ "$n" -eq 4 ] && [ "$p" -eq 0 ]; then pass "detector da forma active: 4/4 pegas, 0/2 falsos positivos"
else fail "detector da forma active furado: negativas=$n/4 positivas=$p/0"; fi

# ── 1. Os arquivos de orientacao existem (senao o teste passaria vazio) ──────
for f in "${GUIDANCE_FILES[@]}"; do [ -f "$f" ] || fail "arquivo de orientacao ausente: $f"; done
grep -q '^## Organizational Roles' agents/forge.md 2>/dev/null \
  || fail "secao '## Organizational Roles' ausente em agents/forge.md"

# ── 2. Forma `active` nos arquivos de orientacao ─────────────────────────────
for f in "${GUIDANCE_FILES[@]}"; do
  [ -f "$f" ] || continue
  hits="$(transition "$f")"
  if [ -n "$hits" ]; then fail "$f descreve transicao para active:"; printf '%s\n' "$hits" | cut -c1-200 | sed 's/^/      | /'
  else pass "$f: nenhuma transicao na forma active"; fi
done

# ── 3. Allowlist estrutural: template + registro roles/** ────────────────────
targets=(agents/forge.md)
if [ -d roles ]; then
  while IFS= read -r f; do targets+=("$f"); done < <(find roles -type f \( -name '*.md' -o -name '*.yml' -o -name '*.yaml' \) | sort)
fi
viol="$(structural "${targets[@]}")"
if [ -n "$viol" ]; then fail "contratos fora da allowlist:"; printf '%s\n' "$viol" | sed 's/^/      | /'
else pass "allowlist ok em ${#targets[@]} arquivo(s) (template + roles/**)"; fi

# O template precisa existir e ser um contrato, senao o passo 3 mede nada.
block="$(awk '/^Role contract fields/{f=1} f&&/^```yaml/{y=1;next} y&&/^```/{exit} y' agents/forge.md)"
if printf '%s\n' "$block" | grep -qE '^status:[[:space:]]+latent([[:space:]]|$)'; then pass "template presente com status latent"
else fail "template YAML do contrato ausente ou sem 'status: latent'"; fi

# ── 4. A frase que nega autoridade ao status ─────────────────────────────────
if grep -qi 'status` never grants authority' agents/forge.md 2>/dev/null; then
  pass "forge.md declara que o status do arquivo nunca concede autoridade"
else
  fail "forge.md nao declara que o status do arquivo nunca concede autoridade"
fi

if [ "$FAILED" -eq 0 ]; then echo "  Status: PASSED"; else echo "  Status: FAILED"; fi
exit "$FAILED"
