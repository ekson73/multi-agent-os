#!/usr/bin/env bash
# Regressao de governanca: um contrato de papel organizacional so admite
# `status: latent` (ADR-019). Este teste mede FORMA, e recusa na duvida.
#
# Onde mede:
#   - o template YAML de agents/forge.md (frontmatter e fences ```yaml);
#   - o registro `roles/` (recursivo), onde a forma aceita e estrita.
#
# Sob `roles/`, so passa um arquivo regular com nome terminado em `.md`
# (minusculo), cuja linha 1 e `---`, com um unico frontmatter fechado por `---`,
# e cujo corpo nao tem fence (``` ou ~~~, com ou sem tag), nem separador de
# documento (`---` ou `...` sozinho na linha), nem chave de contrato seguida de
# `:` (role, status, tier, campos reservados, chaves de ativacao). Qualquer
# outra forma e violacao: link simbolico, outra extensao (inclusive .yml, .YML,
# .Md), frontmatter ausente ou nao fechado, arquivo que nao decodifica como
# UTF-8 (o verificador cai, e a queda conta como falha).
#
# Dentro do contrato (frontmatter em roles/, template, sondas):
#   - cada linha e `chave: valor`, `- item` ou comentario; outra linha e
#     violacao (flow mapping solto, merge key `<<`, chave entre aspas);
#   - nenhum valor usa flow mapping `{...}`, bloco literal `|`/`>`, ancora,
#     alias ou tag; campo de contrato nao usa flow sequence `[...]`;
#   - `status` aparece uma vez e vale `latent`;
#   - `tier` vale exatamente `null`;
#   - campos reservados (approval_ref, approved_by, approved_at, trigger,
#     authority_digest) e chaves de ativacao (active, enabled, armed,
#     effective, activated) em qualquer indentacao: vazios, `null` ou `~`
#     (ativacao tambem aceita false/no/off) e sem filhos na linha seguinte.
#
# Padrao: recusar na duvida. Formas YAML validas que um leitor humano acharia
# inofensivas tambem falham (ex.: `notes: |`, `tier: NULL`, `tier: ~`, prosa no
# corpo com "role:"). Um caso legitimo se declara reescrevendo na forma aceita
# (block style, `tier: null`, prosa sem `chave:`), nunca afrouxando o teste.
#
# Nos tres arquivos de orientacao, procura a FORMA `active` de uma transicao
# (`active` citado, `status: active`, verbo + active).
#
# LIMITES declarados:
#   - o teste NAO entende linguagem natural: "the role is activated by the
#     owner" ou "the role goes live" em prosa nao e detectado;
#   - chave nao listada (ex.: `is_active: true`) passa, se a forma for valida;
#   - so `roles/` e o template sao lidos: um registro que o host designe fora
#     de `roles/` nao e verificado;
#   - nenhum workflow de CI roda este teste hoje; ele roda por
#     tests/governance/run-all.sh ou a mao.
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

# ── Verificador estrutural ───────────────────────────────────────────────────
# Modos: --block (bloco YAML pela stdin), --template ARQ.md, --registry ARQ...
# Imprime uma violacao por linha.
CHECKER="$(cat <<'PY'
import os, re, sys

RESERVED = {"approval_ref", "approved_by", "approved_at", "trigger", "authority_digest"}
BOOL_KEYS = {"active", "enabled", "armed", "effective", "activated"}
CONTRACT_KEYS = {"role", "status", "tier"} | RESERVED | BOOL_KEYS
EMPTY = {"", "null", "~"}
KEY = re.compile(r"^(\s*)(-\s+)?([A-Za-z_][A-Za-z0-9_-]*)\s*:(.*)$")
ITEM = re.compile(r"^\s*-(\s.*)?$")
BODY_KEY = re.compile(r"(^|[\s{,\[])(" + "|".join(sorted(CONTRACT_KEYS)) + r")\s*:")
FENCE = re.compile(r"^\s*(```|~~~)")
DOC_SEP = re.compile(r"^(---|\.\.\.)\s*$")

def value(raw):
    v = raw.split(" #", 1)[0].strip()
    if v.startswith("#"):
        v = ""
    return v

def strip_quotes(v):
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    return v

def check_block(lines, where, require_contract):
    out, rows = [], []
    for n, line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        rows.append((n, line, KEY.match(line)))
    statuses = [(n, value(m.group(4))) for n, l, m in rows if m and m.group(3) == "status"]
    if not (require_contract or statuses or any(m and m.group(3) in CONTRACT_KEYS for _, _, m in rows)):
        return out
    if len(statuses) != 1:
        out.append(f"{where}: `status` aparece {len(statuses)} vezes (esperado 1)")
    for n, v in statuses:
        if strip_quotes(v) != "latent":
            out.append(f"{where}:{n}: status = {v!r} (so `latent` e admitido)")
    for i, (n, line, m) in enumerate(rows):
        if not m:
            if ITEM.match(line):
                if "{" in line:
                    out.append(f"{where}:{n}: flow mapping em item de lista")
                continue
            out.append(f"{where}:{n}: linha nao reconhecida (so `chave: valor`, `- item` ou comentario): {line.strip()[:60]!r}")
            continue
        key, v = m.group(3), value(m.group(4))
        if v[:1] in ("|", ">"):
            out.append(f"{where}:{n}: bloco literal em `{key}` (recusado na duvida)")
        if v[:1] in ("&", "*", "!"):
            out.append(f"{where}:{n}: ancora/alias/tag em `{key}`")
        if "{" in v:
            out.append(f"{where}:{n}: flow mapping em `{key}`")
        if key in CONTRACT_KEYS and v.startswith("["):
            out.append(f"{where}:{n}: flow sequence no campo de contrato `{key}`")
        if key == "tier" and v != "null":
            out.append(f"{where}:{n}: tier = {v!r} (so `null` literal e admitido)")
        if key in BOOL_KEYS and strip_quotes(v).lower() not in EMPTY | {"false", "no", "off"}:
            out.append(f"{where}:{n}: chave de ativacao `{key}` = {v!r}")
        if key in RESERVED and v not in EMPTY:
            out.append(f"{where}:{n}: campo reservado `{key}` = {v!r} (so vazio/null)")
        if key in RESERVED | BOOL_KEYS and i + 1 < len(rows):
            nl = rows[i + 1][1]
            if len(nl) - len(nl.lstrip()) > len(m.group(1)):
                out.append(f"{where}:{n}: `{key}` tem filhos")
    return out

def template_blocks(text):
    # frontmatter + fences ```yaml de um arquivo de orientacao (template)
    lines = text.split("\n")
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

def registry(path):
    if os.path.islink(path):
        return [f"{path}: link simbolico sob roles/ (so arquivo regular)"]
    if not os.path.isfile(path):
        return [f"{path}: nao e arquivo regular"]
    if not os.path.basename(path).endswith(".md"):
        return [f"{path}: extensao recusada (so `.md` minusculo; .yml, .YML, .Md e outras falham)"]
    with open(path, "rb") as fh:
        text = fh.read().decode("utf-8")  # sem tratamento: arquivo ilegivel derruba o verificador
    lines = text.split("\n")
    if lines[0] != "---":
        return [f"{path}:1: linha 1 deve ser `---` (frontmatter)"]
    j = 1
    while j < len(lines) and lines[j].rstrip() != "---":
        j += 1
    if j >= len(lines):
        return [f"{path}: frontmatter nao fechado"]
    out = check_block([(k + 1, lines[k]) for k in range(1, j)], path, True)
    for k in range(j + 1, len(lines)):
        s = lines[k]
        if FENCE.match(s):
            out.append(f"{path}:{k + 1}: fence no corpo (recusada sob roles/)")
        elif DOC_SEP.match(s):
            out.append(f"{path}:{k + 1}: separador de documento no corpo")
        elif BODY_KEY.search(s):
            out.append(f"{path}:{k + 1}: chave de contrato fora do frontmatter")
    return out

mode, args = sys.argv[1], sys.argv[2:]
if mode == "--block":
    text = sys.stdin.read()
    out = check_block([(i + 1, l) for i, l in enumerate(text.split("\n"))], "fixture", True)
elif mode == "--template":
    out = []
    for path in args:
        with open(path, encoding="utf-8") as fh:
            for b in template_blocks(fh.read()):
                out += check_block(b, path, False)
elif mode == "--registry":
    out = [v for path in args for v in registry(path)]
else:
    sys.exit(f"modo desconhecido: {mode}")
for v in out:
    print(v)
PY
)"
# Erro do verificador vira violacao: um crash nunca pode passar como "ok".
structural() {
  local out rc
  out="$(python3 -c "$CHECKER" "$@" 2>&1)"; rc=$?
  [ -n "$out" ] && printf '%s\n' "$out"
  [ "$rc" -eq 0 ] || printf 'verificador estrutural falhou (rc=%s)\n' "$rc"
}

# Descoberta do registro: todo item sob <raiz>/roles que nao seja diretorio
# (arquivo, link, qualquer extensao) vai para o verificador.
REG_COUNT=0
registry_scan() { # <raiz>
  local root="$1" files=() f
  REG_COUNT=0
  if [ -e "$root/roles" ] || [ -L "$root/roles" ]; then
    while IFS= read -r -d '' f; do files+=("$f"); done < <(find "$root/roles" ! -type d -print0)
  fi
  REG_COUNT="${#files[@]}"
  [ "$REG_COUNT" -eq 0 ] || structural --registry "${files[@]}"
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
probe "tier: []"                $'role: x\nstatus: latent\ntier: []'
probe "tier: {}"                $'role: x\nstatus: latent\ntier: {}'
probe 'tier: ""'                $'role: x\nstatus: latent\ntier: ""'
probe "approval_ref preenchido" $'role: x\nstatus: latent\napproval_ref: https://example.invalid/1'
probe "approval_ref aninhado"   $'role: x\nstatus: latent\nroles_meta:\n  approval_ref: rec-1'
probe "approval_ref com filhos" $'role: x\nstatus: latent\napproval_ref:\n  url: rec-1'
probe "trigger preenchido"      $'role: x\nstatus: latent\ntrigger: "queue > 10"'
probe "active: true"            $'role: x\nstatus: latent\nactive: true'
probe "enabled: yes aninhado"   $'role: x\nstatus: latent\nflags:\n  enabled: yes'
probe "flow mapping solto"      $'{role: x, status: active}'
probe "flow mapping aninhado"   $'role: x\nstatus: latent\nmeta: {approved_by: board}'
probe "flow com ativacao"       $'role: x\nstatus: latent\nflags: {enabled: true}'
probe "merge key"               $'role: x\nstatus: latent\n<<: *base'
probe "bloco literal"           $'role: x\nstatus: latent\nnotes: |\n  enabled: true'

ok_hits="$(printf '%s\n' $'role: x\nstatus: latent # comment\ntier: null\napproval_ref: null\napproved_by: ~\ntrigger:\nproposal_cap: null\nbinding: [ "agent-a" ]\nnotes:\n  - plain item' | structural --block | wc -l | tr -d ' ')"
if [ "$ok_hits" -eq 0 ]; then pass "contrato valido nao gera violacao"; else fail "falso positivo no contrato valido ($ok_hits)"; fi

# Sonda do verificador que cai: arquivo que nao decodifica como UTF-8.
mkdir -p "$tmp/crash/roles"; printf '\377\376status: active\n' > "$tmp/crash/roles/x.md"
case "$(registry_scan "$tmp/crash")" in
  *"verificador estrutural falhou"*) pass "queda do verificador conta como falha";;
  *) fail "queda do verificador nao virou falha";;
esac

# Fixtures ponta a ponta: cada uma monta uma arvore com roles/ e passa pela
# mesma descoberta (registry_scan) usada no passo 3.
VALID_FM=$'---\nrole: cto\nstatus: latent\ntier: null\nowner: board\ndecide: [ "architecture" ]\nbinding: [ "architect" ]\nholder: agent\napproval_ref: null\n---'
mkfx() { # <nome> <arquivo relativo a roles/> <conteudo>
  mkdir -p "$(dirname "$tmp/fx/$1/roles/$2")"; printf '%s\n' "$3" > "$tmp/fx/$1/roles/$2"
}
mkfx valido          cto.md         "$VALID_FM"$'\n\nThe board receives every decision of this lane.'
mkfx valido          sub/cfo.md     "$VALID_FM"
mkfx yml-flow        cto.yml        '{role: cto, status: active}'
mkfx md-flow-solto   cto.md         $'---\n{role: cto, status: active}\n---'
mkfx md-flow-aninh   cto.md         "${VALID_FM%---}"$'meta: {approved_by: board}\n---'
mkfx multidoc        cto.md         "$VALID_FM"$'\n---\nstatus: active'
mkfx corpo-solto     cto.md         "$VALID_FM"$'\nstatus: active'
mkfx fence-sem-tag   cto.md         "$VALID_FM"$'\n```\nstatus: active\n```'
mkfx fence-YAML      cto.md         "$VALID_FM"$'\n```YAML\nstatus: active\n```'
mkfx fence-til       cto.md         "$VALID_FM"$'\n~~~yaml\nstatus: active\n~~~'
mkfx fence-aberta    cto.md         "$VALID_FM"$'\n```yaml\nstatus: active'
mkfx ext-YML         cto.YML        "$VALID_FM"
mkfx ext-Md          cto.Md         "$VALID_FM"
mkfx sem-frontmatter cto.md         'role cto, latent.'
mkfx fm-aberto       cto.md         $'---\nrole: cto\nstatus: latent'
mkfx tier-lista      cto.md         "${VALID_FM/tier: null/tier: []}"
mkfx tier-mapa       cto.md         "${VALID_FM/tier: null/tier: \{\}}"
mkfx tier-vazio      cto.md         "${VALID_FM/tier: null/tier: \"\"}"
mkdir -p "$tmp/fx/symlink/roles"; printf '%s\n' "$VALID_FM" > "$tmp/fx/symlink/alvo.md"
ln -s ../alvo.md "$tmp/fx/symlink/roles/cto.md"

registry_scan "$tmp/fx/valido" > "$tmp/out"; out="$(cat "$tmp/out")"
if [ -z "$out" ] && [ "$REG_COUNT" -eq 2 ]; then pass "fixture valida: 2 arquivos lidos, 0 violacoes"
else fail "fixture valida: lidos=$REG_COUNT violacoes=[$out]"; fi
for d in "$tmp"/fx/*/; do
  name="$(basename "$d")"; [ "$name" = valido ] && continue
  registry_scan "$tmp/fx/$name" > "$tmp/out"; out="$(cat "$tmp/out")"
  [ -n "${FX_DEBUG:-}" ] && printf '      [%s] %s\n' "$name" "$out"
  case "$out" in
    *"verificador estrutural falhou"*) fail "fixture $name derrubou o verificador";;
    "") fail "fixture $name escapou (lidos=$REG_COUNT)";;
    *) pass "fixture $name recusada";;
  esac
done

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

# ── 3. Template + registro roles/ deste repositorio ──────────────────────────
{ structural --template agents/forge.md; registry_scan .; } > "$tmp/out"; viol="$(cat "$tmp/out")"
if [ -n "$viol" ]; then fail "contratos fora da forma aceita:"; printf '%s\n' "$viol" | sed 's/^/      | /'
else pass "template ok; roles/: $REG_COUNT arquivo(s) lido(s), 0 violacoes"; fi

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
