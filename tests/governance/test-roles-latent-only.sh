#!/usr/bin/env bash
# Regressao de governanca: um contrato de papel organizacional so admite
# `status: latent` (ADR-019). Este teste mede FORMA, e recusa na duvida.
#
# Onde mede:
#   - o template YAML de agents/forge.md (frontmatter e fences ```yaml);
#   - o registro `roles/` (recursivo), onde a forma aceita e estrita.
#
# Sob `roles/`, so passa um arquivo regular com nome terminado em `.md`
# (minusculo), em UTF-8 sem BOM, sem CR/NEL/LS/PS, cuja linha 1 e `---`, com um
# unico frontmatter fechado por `---`, e cujo corpo nao tem fence (``` ou ~~~,
# com ou sem tag), nem separador de documento (`---` ou `...` sozinho na linha),
# nem chave de contrato seguida de `:` (role, status, tier, campos reservados,
# chaves de ativacao). Qualquer outra forma e violacao: link simbolico, outra
# extensao (.yml, .YML, .Md, .gitkeep), frontmatter ausente ou nao fechado,
# arquivo que nao decodifica como UTF-8 (o verificador cai, e a queda conta
# como falha).
#
# O frontmatter (e o template, e as sondas) e lido com yaml.safe_load, com
# chave duplicada recusada; YAML que nao carrega e violacao. Sobre o valor
# carregado:
#   - a raiz e um mapa; `status` vale a string `latent`; `tier`, se existir,
#     e null;
#   - `role`, `status` e `tier` so aparecem na raiz;
#   - em qualquer profundidade, dentro de mapas e de listas: campos reservados
#     (approval_ref, approved_by, approved_at, trigger, authority_digest) valem
#     null; chaves de ativacao (active, enabled, armed, effective, activated)
#     valem null ou false.
# Sem python3 com PyYAML o teste falha; nunca cai para uma checagem mais fraca.
# No template de agents/forge.md, um bloco que nao carrega como YAML so conta
# como violacao se citar chave de contrato (a outra fence e um modelo de agente).
#
# Padrao: recusar na duvida. Falsos positivos aceitos: arquivo com CRLF ou BOM,
# `roles/.gitkeep`, prosa no corpo com "role:", `active: "false"` (string, nao
# booleano). Um caso legitimo se reescreve na forma aceita; o teste nao afrouxa.
#
# Nos tres arquivos de orientacao, procura a FORMA `active` de uma transicao
# (`active` citado, `status: active`, verbo + active).
#
# LIMITES declarados:
#   - o teste NAO entende linguagem natural: "the role is activated by the
#     owner" ou "the role goes live" em prosa nao e detectado;
#   - chave nao listada passa (ex.: `is_active: true`, `Active: true`), assim
#     como chave nao-string que o YAML 1.1 produz (ex.: `yes:` vira booleano);
#   - o teste mede o valor que yaml.safe_load (PyYAML, YAML 1.1) produz; um
#     consumidor com outro parser pode ler o mesmo texto de outro jeito;
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
import yaml

RESERVED = {"approval_ref", "approved_by", "approved_at", "trigger", "authority_digest"}
BOOL_KEYS = {"active", "enabled", "armed", "effective", "activated"}
ROOT_ONLY = {"role", "status", "tier"}
CONTRACT_KEYS = ROOT_ONLY | RESERVED | BOOL_KEYS
BODY_KEY = re.compile(r"(^|[\s{,\[])(" + "|".join(sorted(CONTRACT_KEYS)) + r")\s*:")
FENCE = re.compile(r"^\s*(```|~~~)")
DOC_SEP = re.compile(r"^(---|\.\.\.)\s*$")
# Quebras de linha que o YAML reconhece alem de \n, e o BOM: recusados.
RAW = {"\r": "CR", "\x85": "NEL", " ": "LS", " ": "PS", "﻿": "BOM"}

class Loader(yaml.SafeLoader):
    pass

def no_duplicates(loader, node, deep=False):
    seen = set()
    for knode, _ in node.value:
        k = loader.construct_object(knode, deep=deep)
        if k in seen:
            raise yaml.constructor.ConstructorError(None, None, f"chave duplicada {k!r}", knode.start_mark)
        seen.add(k)
    return loader.construct_mapping(node, deep)

Loader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, no_duplicates)

def walk(o, path, out, where):
    if isinstance(o, dict):
        for k, v in o.items():
            p = f"{path}.{k}" if path else str(k)
            if k in RESERVED and v is not None:
                out.append(f"{where}: campo reservado `{p}` = {v!r} (so null)")
            if k in BOOL_KEYS and not (v is None or v is False):
                out.append(f"{where}: chave de ativacao `{p}` = {v!r} (so null ou false)")
            if k in ROOT_ONLY and path:
                out.append(f"{where}: `{p}` fora da raiz do contrato")
            walk(v, p, out, where)
    elif isinstance(o, list):
        for i, x in enumerate(o):
            walk(x, f"{path}[{i}]", out, where)

def check_yaml(text, where, require_contract):
    out = [f"{where}: caractere {name} recusado" for ch, name in RAW.items() if ch in text]
    if out:
        return out
    try:
        data = yaml.load(text, Loader=Loader)
    except yaml.YAMLError as e:
        # No template, um bloco que nao e YAML so conta se cita chave de contrato.
        if not require_contract and not BODY_KEY.search(text):
            return []
        return [f"{where}: YAML invalido ({str(e).splitlines()[0]})"]
    is_contract = require_contract or (isinstance(data, dict) and any(k in data for k in ROOT_ONLY))
    if not is_contract:
        walk(data, "", out, where)
        return out
    if not isinstance(data, dict):
        return [f"{where}: contrato nao e um mapa YAML"]
    if data.get("status") != "latent" or not isinstance(data.get("status"), str):
        out.append(f"{where}: status = {data.get('status')!r} (so `latent` e admitido)")
    if "tier" in data and data["tier"] is not None:
        out.append(f"{where}: tier = {data['tier']!r} (so null e admitido)")
    walk(data, "", out, where)
    return out

def template_blocks(text):
    lines = text.split("\n")
    i = 0
    if lines and lines[0].strip() == "---":
        j = 1
        while j < len(lines) and lines[j].strip() != "---":
            j += 1
        yield "\n".join(lines[1:j])
        i = j + 1
    cur = None
    for k in range(i, len(lines)):
        s = lines[k].strip()
        if cur is None and re.match(r"^```\s*ya?ml\b", s):
            cur = []
        elif cur is not None and s.startswith("```"):
            yield "\n".join(cur)
            cur = None
        elif cur is not None:
            cur.append(lines[k])

def registry(path):
    if os.path.islink(path):
        return [f"{path}: link simbolico sob roles/ (so arquivo regular)"]
    if not os.path.isfile(path):
        return [f"{path}: nao e arquivo regular"]
    if not os.path.basename(path).endswith(".md"):
        return [f"{path}: extensao recusada (so `.md` minusculo; .yml, .YML, .Md, .gitkeep e outras falham)"]
    with open(path, "rb") as fh:
        text = fh.read().decode("utf-8")  # sem tratamento: arquivo ilegivel derruba o verificador
    bad = [f"{path}: caractere {name} recusado" for ch, name in RAW.items() if ch in text]
    if bad:
        return bad
    lines = text.split("\n")
    if lines[0] != "---":
        return [f"{path}:1: linha 1 deve ser `---` (frontmatter)"]
    j = 1
    while j < len(lines) and lines[j].rstrip() != "---":
        j += 1
    if j >= len(lines):
        return [f"{path}: frontmatter nao fechado"]
    out = check_yaml("\n".join(lines[1:j]), path, True)
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
    out = check_yaml(sys.stdin.read(), "fixture", True)
elif mode == "--template":
    out = []
    for path in args:
        with open(path, encoding="utf-8") as fh:
            for b in template_blocks(fh.read()):
                out += check_yaml(b, path, False)
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
  out="$(python3 -I -c "$CHECKER" "$@" 2>&1)"; rc=$?
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

# Sem python3 ou sem PyYAML o teste falha (fail-closed); nunca contorna.
python3 -I -c 'import yaml' >/dev/null 2>&1 || { fail "python3 com PyYAML ausente: verificador estrutural nao roda"; echo "  Status: FAILED"; exit 1; }

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
probe "status com continuacao"   $'role: x\nstatus: latent\n  - active'
probe "reservado lista sem indent" $'role: x\nstatus: latent\napproval_ref:\n- granted'
probe "CR em comentario"        $'role: x\nstatus: latent # c\ractive: true'
probe "flow seq com par"        $'role: x\nstatus: latent\nflags: [active: true]'
probe "lista aninhada"          $'role: x\nstatus: latent\nx:\n  - - approval_ref: rec-1'
probe "item flow seq"           $'role: x\nstatus: latent\nmeta:\n- [enabled: true]'
probe "item chave entre aspas"  $'role: x\nstatus: latent\nmeta:\n- "active": true'
probe 'active: "false"'         $'role: x\nstatus: latent\nactive: "false"'
probe "active: nUlL"            $'role: x\nstatus: latent\nactive: nUlL'
probe "status duplicado, ultimo latent" $'role: x\nstatus: active\nstatus: latent'
probe "CR recusado mesmo inofensivo" $'role: x\nstatus: latent # c\ractive: false'
probe "status aninhado"         $'role: x\nstatus: latent\nmeta:\n  status: active'

ok_hits="$(printf '%s\n' $'role: x\nstatus: latent # comment\ntier: null\napproval_ref: null\napproved_by: ~\ntrigger:\nactive: false\nenabled: NULL\nproposal_cap: null\nbinding: [ "agent-a" ]\nnotes: |\n  free text\nitems:\n  - plain item' | structural --block | wc -l | tr -d ' ')"
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
FM_HEAD=$'---\nrole: cto\ntier: null\nowner: board'
mkfx status-continua cto.md         "$FM_HEAD"$'\nstatus: latent\n  - active\n---'
mkfx reserv-lista    cto.md         "${VALID_FM%---}"$'trigger:\n- granted\n---'
mkfx cr-comentario   cto.md         "$FM_HEAD"$'\nstatus: latent # c\ractive: true\n---'
mkfx nel-comentario  cto.md         "$FM_HEAD"$'\nstatus: latent # c\xc2\x85active: true\n---'
mkfx flow-seq-par    cto.md         "${VALID_FM%---}"$'flags: [active: true]\n---'
mkfx lista-aninhada  cto.md         "${VALID_FM%---}"$'x:\n  - - approval_ref: rec-1\n---'
mkfx item-flow-seq   cto.md         "${VALID_FM%---}"$'meta:\n- [enabled: true]\n---'
mkfx item-aspas      cto.md         "${VALID_FM%---}"$'meta:\n- "active": true\n---'
mkfx active-string   cto.md         "${VALID_FM%---}"$'active: "false"\n---'
mkfx active-nulL     cto.md         "${VALID_FM%---}"$'active: nUlL\n---'
mkfx crlf            cto.md         "${VALID_FM//$'\n'/$'\r\n'}"
mkfx bom             cto.md         $'\xef\xbb\xbf'"$VALID_FM"
mkfx gitkeep         .gitkeep       ''
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
