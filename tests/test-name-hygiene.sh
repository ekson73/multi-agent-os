#!/usr/bin/env bash
# tests/test-name-hygiene.sh — unit tests for scripts/check-name-hygiene.py.
# Uses a synthetic denylist (fictional tokens) in a throwaway git repo, so the test itself
# never spells a real denylisted name. Stdlib + git only.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/scripts/check-name-hygiene.py"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL $1"; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$T" && git init -q . && mkdir -p .github/name-hygiene docs fixtures

SALT="test-salt"
h() { printf '%s' "$SALT$1" | sha256sum | cut -d' ' -f1; }
{
  echo "salt $SALT"
  echo "d1 x $(h zorblax)"
  echo "d2 p $(h quuxname)"
} > .github/name-hygiene/denylist.txt
cat > .github/name-hygiene/allow.json <<'JSON'
{"allow": [
  {"id": "slug", "paths": ["*"], "detectors": ["d2"], "context": "{T}/public-repo", "reason": "canonical slug"},
  {"id": "fixtures", "paths": ["fixtures/*"], "reason": "synthetic fixtures"}
]}
JSON

printf 'clean text only\n' > docs/clean.md
git add -A
out="$(python3 "$CHECK" --root "$T" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "clean tree exits 0" || bad "clean tree exits 0 (rc=$rc: $out)"

printf 'Talk to Zorblax today\n' > docs/a.md                       # exact token, case-insensitive
printf 'see quuxname42 and QuuxNameTeam\n' > docs/b.md           # prefix mode + camelCase
printf "pattern '\\\\bzorblax\\\\b' in a regex\n" > docs/c.md       # regex escape glued to the name
printf 'mail %s@%s now\n' real.person corp-mail.com.br > docs/d.md   # real-looking e-mail (assembled at runtime)
printf 'cpf %s.%s.%s-%s valid\n' 529 982 247 25 > docs/e.md      # checksum-valid CPF (assembled at runtime)
printf 'path /Users/someone/Projects/x and git@github.com-myalias:o/r.git\n' > docs/f.md
printf 'ok: user@example.com, 111.111.111-11, /Users/USER/x, git@github.com-personal:o/r\n' > docs/g.md
printf 'url github.com/quuxname7/public-repo is allowed\n' > docs/h.md
printf 'Zorblax in a fixture\n' > fixtures/x.md
git add -A

out="$(python3 "$CHECK" --root "$T" --json 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && ok "findings exit 1" || bad "findings exit 1 (rc=$rc)"
n() { printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(1 for f in d['findings'] if f['file']=='$1' and f['detector']=='$2'))"; }
[ "$(n docs/a.md d1)" = 1 ] && ok "exact token (case-insensitive)" || bad "exact token"
[ "$(n docs/b.md d2)" = 2 ] && ok "prefix token + camelCase part" || bad "prefix/camelCase ($(n docs/b.md d2))"
[ "$(n docs/c.md d1)" = 1 ] && ok "regex escape does not hide the name" || bad "regex escape"
[ "$(n docs/d.md email)" = 1 ] && ok "real-looking e-mail" || bad "e-mail"
[ "$(n docs/e.md cpf)" = 1 ] && ok "checksum-valid CPF" || bad "CPF"
[ "$(n docs/f.md home-path)" = 1 ] && [ "$(n docs/f.md ssh-alias)" = 1 ] && ok "home path + SSH alias" || bad "home path / ssh alias"
g="$(printf '%s' "$out" | grep -c '"docs/g.md"')"
[ "$g" = 0 ] && ok "placeholders ignored (example mail, invalid CPF, USER, generic alias)" || bad "placeholders flagged ($g)"
[ "$(printf '%s' "$out" | grep -c '"docs/h.md"')" = 0 ] && ok "context allow rule" || bad "context allow rule"
[ "$(printf '%s' "$out" | grep -c '"fixtures/x.md"')" = 0 ] && ok "path allow rule" || bad "path allow rule"
text_out="$(python3 "$CHECK" --root "$T" 2>/dev/null || true)"
leak=0
printf '%s\n%s\n' "$out" "$text_out" | grep -qi 'zorblax\|quuxname\|real\.person\|529\.982' && leak=1
# The previous formatter revealed the first letter plus asterisks.
printf '%s\n%s\n' "$out" "$text_out" | grep -Eq 'Z\*+|Q\*+|r\*+@|[0-9]\*+\.' && leak=1
python3 -c '
import json, sys, hashlib
d = json.loads(sys.argv[1])
salt = "test-salt"
def short(tok):
    return hashlib.sha256((salt + tok.lower()).encode()).hexdigest()[:12]
for f in d["findings"]:
    if "token" in f or not isinstance(f.get("hash"), str) or len(f["hash"]) != 12:
        sys.exit(1)
    if any(c not in "0123456789abcdef" for c in f["hash"]):
        sys.exit(1)
got = [f["hash"] for f in d["findings"] if f["file"] == "docs/a.md" and f["detector"] == "d1"]
if got != [short("zorblax")]:
    sys.exit(2)
' "$out" || leak=1
[ "$leak" = 0 ] && ok "output is file, rule id and short hash" || bad "output leaks a plain value"

python3 "$CHECK" --root "$T" --report-only >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "--report-only exits 0 with findings" || bad "--report-only (rc=$rc)"
python3 "$CHECK" --root "$T" --paths docs/clean.md >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "--paths limits the scan" || bad "--paths (rc=$rc)"

printf '{"allow":[{"id":"x","paths":["*"]}]}\n' > .github/name-hygiene/allow.json
python3 "$CHECK" --root "$T" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "allow rule without reason is a config error" || bad "missing reason (rc=$rc)"

printf '%s\n' '{"allow":[{"id":"old","paths":["*"],"reason":"temporary placeholder","expires":"2000-01-01","tracking":"TRACKING-PLACEHOLDER"}]}' > .github/name-hygiene/allow.json
warn="$(python3 "$CHECK" --root "$T" --report-only --paths docs/clean.md 2>/dev/null || true)"
if printf '%s' "$warn" | grep -q 'allow rule old expired on 2000-01-01' \
   && printf '%s' "$warn" | grep -q 'TRACKING-PLACEHOLDER' \
   && [ "$(printf '%s' "$warn" | grep -c 'expired on')" = 1 ]; then
  ok "expired allow rule warns once"
else
  bad "expired allow rule warning"
fi
printf '%s\n' '{"allow":[{"id":"future","paths":["*"],"reason":"temporary placeholder","expires":"2099-01-01","tracking":"TRACKING-PLACEHOLDER"}]}' > .github/name-hygiene/allow.json
quiet="$(python3 "$CHECK" --root "$T" --report-only --paths docs/clean.md 2>/dev/null || true)"
[ "$(printf '%s' "$quiet" | grep -c 'expired on')" = 0 ] && ok "unexpired allow rule is silent" || bad "unexpired rule warned"

echo "test-name-hygiene: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
