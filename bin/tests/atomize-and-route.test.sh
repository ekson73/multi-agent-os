#!/usr/bin/env bash
# Tests for bin/atomize-and-route — deterministic format+destination resolver
# + capture/routing ledger (Diairesis). Bash 3.2-safe, self-contained.
# Run: bash bin/tests/atomize-and-route.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BIN="$DIR/../atomize-and-route"

pass=0 ; fail=0
ok() { pass=$((pass + 1)); printf '  \xe2\x9c\x93 %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \xe2\x9c\x97 %s\n      got: [%s]\n' "$1" "$2"; }
has()  { case "$2" in *"$1"*) ok "$3" ;; *) no "$3" "$2" ;; esac; }
hasnt(){ case "$2" in *"$1"*) no "$3" "$2" ;; *) ok "$3" ;; esac; }
eq()   { [ "$1" = "$2" ] && ok "$3" || no "$3" "got=[$2] want=[$1]"; }

printf 'atomize-and-route.test.sh\n'

# isolate ledger from the real one (never write to $HOME/.claude/audit in tests)
TMPDIR_TEST="$(mktemp -d 2>/dev/null || mktemp -d -t aar)"
export ATOMIZE_ROUTE_DIR="$TMPDIR_TEST"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- usage / validation -------------------------------------------------
o="$("$BIN" 2>&1)"; rc=$?
eq "0" "$rc" 'bare invocation (usage) exits 0'

o="$("$BIN" bogus-verb 2>&1)"; rc=$?
eq "1" "$rc" 'unknown verb exits 1'

o="$("$BIN" route --scope user 2>&1)"; rc=$?
eq "1" "$rc" 'route without --type exits 1'
has 'is required' "$o" 'route without --type gives a usage-shaped error'

o="$("$BIN" route --type norm 2>&1)"; rc=$?
eq "1" "$rc" 'route without --scope exits 1'

o="$("$BIN" route --type not-a-real-type --scope user --dry-run 2>&1)"; rc=$?
eq "1" "$rc" 'route with unknown --type exits 1'

o="$("$BIN" route --type norm --scope not-a-real-scope --dry-run 2>&1)"; rc=$?
eq "1" "$rc" 'route with unknown --scope exits 1'

# --- resolution correctness across atom types ---------------------------
o="$("$BIN" route --type norm --scope user --dry-run --json 2>/dev/null)"
has '.claude/rules' "$o" 'norm resolves under ~/.claude/rules'
has 'markdown+frontmatter' "$o" 'norm format is markdown+frontmatter'

o="$("$BIN" route --type procedure --scope community --dry-run --json 2>/dev/null)"
has 'SKILL.md' "$o" 'procedure resolves to a SKILL.md path'

o="$("$BIN" route --type insight --scope project --dry-run --json 2>/dev/null)"
has 'memory' "$o" 'insight resolves under memory/'

o="$("$BIN" route --type idea --scope durable-personal --dry-run --json 2>/dev/null)"
has 'eko-engram' "$o" 'idea resolves under eko-engram'

o="$("$BIN" route --type work --scope work --dry-run --json 2>/dev/null)"
has 'tracker' "$o" 'work resolves to a tracker destination'

o="$("$BIN" route --type gap --scope self --dry-run --json 2>/dev/null)"
has 'taxis' "$o" 'gap resolves to the Taxis triage queue (loose-end-triage-queue)'

# --- determinism (same input -> byte-identical output, ignoring atom_id) --
o1="$("$BIN" route --type norm --scope user --dry-run --json 2>/dev/null | jq -c 'del(.atom_id)')"
o2="$("$BIN" route --type norm --scope user --dry-run --json 2>/dev/null | jq -c 'del(.atom_id)')"
eq "$o1" "$o2" 'route resolution is deterministic (identical type+scope -> identical answer)'

# --- --dry-run truly never writes the ledger ----------------------------
"$BIN" route --type norm --scope user --dry-run --json >/dev/null 2>&1
[ -f "$ATOMIZE_ROUTE_DIR/atomize-and-route.jsonl" ] && no '--dry-run writes nothing to the ledger' "file exists" || ok '--dry-run writes nothing to the ledger'

# --- non-dry-run: writes + is idempotent --------------------------------
"$BIN" route --type norm --scope user --atom-id test-atom-1 --json >/dev/null 2>&1
n1="$(wc -l < "$ATOMIZE_ROUTE_DIR/atomize-and-route.jsonl" | tr -d ' ')"
eq "1" "$n1" 'first non-dry-run route appends exactly 1 ledger line'

"$BIN" route --type norm --scope user --atom-id test-atom-1 --json >/dev/null 2>&1
n2="$(wc -l < "$ATOMIZE_ROUTE_DIR/atomize-and-route.jsonl" | tr -d ' ')"
eq "1" "$n2" 're-routing the identical atom_id is idempotent (no duplicate line)'

# --- ledger --append + --query --unrouted -------------------------------
rm -f "$ATOMIZE_ROUTE_DIR/atomize-and-route.jsonl"
"$BIN" ledger --append '{"atom_id":"cap-1","kind":"insight","text":"unrouted example"}' >/dev/null 2>&1
"$BIN" ledger --append '{"atom_id":"cap-2","kind":"insight","text":"will be routed"}' >/dev/null 2>&1
"$BIN" route --type insight --scope project --atom-id cap-2 --json >/dev/null 2>&1

o="$("$BIN" ledger --query --unrouted --json 2>/dev/null)"
has 'cap-1' "$o" '--query --unrouted lists a captured-but-never-routed atom'
hasnt '"atom_id":"cap-2"' "$o" '--query --unrouted excludes an atom that WAS routed'

# ledger --append is itself idempotent on identical atom_id
"$BIN" ledger --append '{"atom_id":"cap-1","kind":"insight","text":"unrouted example"}' >/dev/null 2>&1
n3="$(grep -c '"event":"captured"' "$ATOMIZE_ROUTE_DIR/atomize-and-route.jsonl" 2>/dev/null || echo 0)"
eq "2" "$n3" 're-appending the identical captured atom_id is idempotent (still 2 captured events total)'

# --- empty-ledger graceful degradation -----------------------------------
rm -f "$ATOMIZE_ROUTE_DIR/atomize-and-route.jsonl"
o="$("$BIN" ledger --query --unrouted --json 2>/dev/null)"
eq "[]" "$o" 'empty/absent ledger --query --unrouted returns [] cleanly'

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
