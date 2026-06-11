#!/usr/bin/env bash
# Tests for bin/locus.sh — the locus recap renderer.
# Bash 3.2-safe, self-contained, read-only. Run: bash bin/tests/locus.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
GS="$DIR/../locus.sh"

pass=0 ; fail=0
ok() { pass=$((pass + 1)); printf '  \xe2\x9c\x93 %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \xe2\x9c\x97 %s\n      got: [%s]\n' "$1" "$2"; }
has()  { case "$2" in *"$1"*) ok "$3" ;; *) no "$3" "$2" ;; esac; }   # has NEEDLE HAYSTACK MSG
hasnt(){ case "$2" in *"$1"*) no "$3" "$2" ;; *) ok "$3" ;; esac; }
eq()   { [ "$1" = "$2" ] && ok "$3" || no "$3" "got=[$2] want=[$1]"; }

printf 'locus.test.sh\n'

# D1 name: status+slug, no #seq, no compass clutter
o="$("$GS" --density name --status '🟢' --slug add-oauth)"
has 'add-oauth' "$o" 'D1 renders slug'
has '🟢'        "$o" 'D1 renders status'
hasnt ' · #'    "$o" 'D1 omits #seq token (· #N) when --seq absent (anchor like PR#N is not a seq)'
hasnt '↑'       "$o" 'D1 name stays clean (no auto-compass)'

# D1 #seq present when supplied
o="$("$GS" --density name --status '🟡' --slug x --seq 4)"
has '#4' "$o" 'D1 renders #seq when supplied'

# D1 explicit blocker enrich
o="$("$GS" --density name --status '🟠' --slug capture-rls --enrich '⛔reauth')"
has '⛔reauth' "$o" 'D1 renders explicit enrich (blocker)'

# no dangling/double separator
o="$("$GS" --density name --status '🟢' --slug z)"
hasnt ' ·  · ' "$o" 'no double separator (optional fields collapse cleanly)'

# D2 status: project:branch + compass field
# pin --base HEAD → deterministic ↑0↓0 (HEAD...HEAD), no dependency on origin/remote layout
o="$("$GS" --density status --status '🟡' --slug s --base HEAD)"
has ':'     "$o" 'D2 renders project:branch'
has '↑0↓0'  "$o" 'D2 compass deterministic with --base HEAD'

# D2 pulse token
o="$("$GS" --density status --status '🟡' --slug s --pulse 3/4)"
has '3/4🟢' "$o" 'D2 renders pulse token'

# D3 ntree: stdin items formatted into a tree (├─ … └─)
o="$(printf 'aa\nbb\ncc\n' | "$GS" --density ntree --status '🟡' --slug t --seq 2)"
has '#2'    "$o" 'D3 header carries #seq'
has '├─ aa' "$o" 'D3 first item uses ├─'
has '├─ bb' "$o" 'D3 middle item uses ├─'
has '└─ cc' "$o" 'D3 last item uses └─'
hasnt '└─ aa' "$o" 'D3 only the last item uses └─'

# D3 tty-guard: no stdin → header only, no connectors, no hang
o="$("$GS" --density ntree --status '🟡' --slug t </dev/null)"
hasnt '├─' "$o" 'D3 no items → no ├─ connector'
hasnt '└─' "$o" 'D3 no items → no └─ connector'

# D4 conv
o="$("$GS" --density conv)"
has 'conv:' "$o" 'D4 renders conventions line'

# bad density → empty stdout + exit 0 (never blocks)
o="$("$GS" --density bogus 2>/dev/null)" ; rc=$?
eq '' "$o" 'bad density → empty stdout'
eq '0' "$rc" 'bad density → exit 0'

# missing density → exit 0 (never blocks)
"$GS" >/dev/null 2>&1 ; eq '0' "$?" 'missing density → exit 0'

# ── anchor extraction + slug normalization (controlled tmp repo — deterministic in CI) ──
TMP="$(mktemp -d)"
(
  cd "$TMP" || exit 1
  git init -q
  git -c user.email=t@t -c user.name=t commit --allow-empty -q -m 'init'   # no ticket in subject
  git checkout -q -b feature/VKS-2159-poc-openspec
) >/dev/null 2>&1

# regression: the DEFAULT ticket regex must work — `${var:-[A-Z]{2,}-[0-9]+}` silently
# truncated at the first `}` (broken regex) → anchor never extracted the ticket from the branch
o="$(cd "$TMP" && "$GS" --density name --status '🟡' --slug a3-judge --seq 9a72558e)"
has 'VKS-2159'  "$o" 'anchor extracts ticket from branch with the DEFAULT regex (regression)'
hasnt 'feature/' "$o" 'anchor is the ticket, not the full branch'

# explicit --ticket wins (highest salience), shape-validated
o="$(cd "$TMP" && "$GS" --density name --slug verify --seq 1 --ticket ABC-77)"
has 'ABC-77' "$o" 'explicit --ticket becomes the anchor'
o="$(cd "$TMP" && "$GS" --density name --slug verify --seq 1 --ticket 'not;a(ticket')"
has 'VKS-2159' "$o" 'malformed --ticket is ignored (shape-validation) → branch ticket anchors'

# slug dedupe: tokens the anchor already carries are dropped (case-insensitive, whole-token)
o="$(cd "$TMP" && "$GS" --density name --slug vks-2159-verify --seq 42)"
has '· verify'        "$o" 'slug keeps only what the anchor does not say'
hasnt 'vks-2159-verify' "$o" 'slug drops anchor-duplicated ticket tokens'

# derived slug fully covered by a no-ticket branch anchor → slug omitted (no duplication)
( cd "$TMP" && git checkout -q -b feature/payment-retry ) >/dev/null 2>&1
o="$(cd "$TMP" && "$GS" --density name --status '🟡' --seq ab)"
eq '🟡 · feature/payment-retry · #ab' "$o" 'no-ticket branch: derived slug deduped away (anchor says it all)'

rm -rf "$TMP"

# read-only: running the tool does not mutate git state
before="$(git -C "$DIR/.." status --short 2>/dev/null)"
"$GS" --density status >/dev/null 2>&1
"$GS" --density name   >/dev/null 2>&1
after="$(git -C "$DIR/.." status --short 2>/dev/null)"
eq "$before" "$after" 'read-only: no git mutation'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
