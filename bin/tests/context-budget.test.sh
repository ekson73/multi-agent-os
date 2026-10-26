#!/usr/bin/env bash
# Tests for bin/context-budget. Self-contained: builds a fake $HOME in a temp dir,
# never reads the real ~/.claude. Run: bash bin/tests/context-budget.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CB="$DIR/../context-budget"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

pass=0 ; fail=0
ok() { pass=$((pass + 1)); printf '  \xe2\x9c\x93 %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \xe2\x9c\x97 %s\n      got: [%s]\n' "$1" "$2"; }
eq() { [ "$1" = "$2" ] && ok "$3" || no "$3" "got=[$2] want=[$1]"; }
# print JSON-style null for None so a missing field never reads as the string "None"
jq_() { python3 -c "import json,sys; d=json.load(sys.stdin); v=($1); print('null' if v is None else v)"; }

printf 'context-budget.test.sh\n'

H="$T/home"; W="$T/work/repo"
mkdir -p "$H/.claude/rules" "$H/.claude/skills/s1" "$H/.claude/agents" "$W"
printf '%0100d' 0 > "$H/.claude/rules/a.md"          # 100 bytes
printf '%0300d' 0 > "$H/.claude/rules/b.md"          # 300 bytes
printf '%040d'  0 > "$H/.claude/CLAUDE.md"           # 40 bytes
printf '%020d'  0 > "$W/CLAUDE.md"                   # 20 bytes
printf -- '---\nname: s1\ndescription: does x\n---\nbody\n' > "$H/.claude/skills/s1/SKILL.md"
printf -- '---\nname: ag\ndescription: agent y\n---\n' > "$H/.claude/agents/ag.md"
ENC="$(printf '%s' "$W" | sed 's/[^A-Za-z0-9]/-/g')"
mkdir -p "$H/.claude/projects/$ENC/memory"
printf '%080d' 0 > "$H/.claude/projects/$ENC/memory/MEMORY.md"   # 80 bytes

# --- disk mode
o="$("$CB" --mode disk --home "$H" --cwd "$W" --json)"; rc=$?
eq 0 "$rc" 'disk: exit 0'
eq 400 "$(printf '%s' "$o" | jq_ 'd["by_category"]["rules"]["bytes"]')" 'disk: rules bytes summed'
# the chain walks up to /, so count only the fixture tree: a CLAUDE.md in a real
# parent of $TMPDIR must not change the result
eq 60  "$(printf '%s' "$o" | T="$T" jq_ 'sum(r["bytes"] for r in d["sources"] if r["category"]=="claude_md" and r.get("path","").startswith(__import__("os").environ["T"]))')" 'disk: CLAUDE.md chain (home + cwd)'
eq 80  "$(printf '%s' "$o" | jq_ 'd["by_category"]["memory_index"]["bytes"]')" 'disk: MEMORY.md for encoded cwd'
eq 100 "$(printf '%s' "$o" | jq_ '[r for r in d["sources"] if r["source"].endswith("a.md")][0]["tokens_est"]*4')" 'disk: tokens_est = bytes/4'
eq 3   "$(printf '%s' "$o" | jq_ 'len([r for r in d["sources"] if r["status"]=="not_measured"])')" 'disk: hooks/mcp/deferred flagged not_measured'
eq estimated "$(printf '%s' "$o" | jq_ '[r for r in d["sources"] if r["category"]=="skills"][0]["status"]')" 'disk: listings labelled estimated'

# --- idempotence
o2="$("$CB" --mode disk --home "$H" --cwd "$W" --json)"
[ "$o" = "$o2" ] && ok 'disk: idempotent (same output twice)' || no 'disk: idempotent' 'differs'

# --- transcript mode
TR="$T/t.jsonl"
python3 - "$TR" <<'PY'
import json,sys
L=[
 {"type":"attachment","attachment":{"type":"prompt_snapshot","systemPrompt":"x"*50}},
 {"type":"attachment","attachment":{"type":"instructions","files":[
   {"path":"/h/.claude/rules/r.md","type":"User","content":"r"*200},
   {"path":"/h/.claude/CLAUDE.md","type":"User","content":"c"*30},
   {"path":"/h/.claude/projects/p/memory/MEMORY.md","type":"AutoMem","content":"m"*10}]}},
 {"type":"attachment","attachment":{"type":"skill_listing","content":"s"*70,"skillCount":2}},
 {"type":"attachment","attachment":{"type":"deferred_tools_delta","addedLines":["ab","cd"],"addedNames":["ab","cd"]}},
 {"type":"attachment","attachment":{"type":"hook_success","hookEvent":"SessionStart","hookName":"SessionStart:startup","content":"h"*9,"stdout":"SECRET-NOT-COUNTED"}},
 {"type":"attachment","attachment":{"type":"hook_success","hookEvent":"PostToolUse","hookName":"x","content":"z"*999}},
 {"type":"attachment","attachment":{"type":"async_hook_response","hookEvent":"SessionStart","hookName":"a","stdout":"ASYNC-STDOUT-NOT-COUNTED","response":{"systemMessage":"shown to user","hookSpecificOutput":{"additionalContext":"k"*7}}}},
 {"type":"attachment","attachment":{"type":"async_hook_response","hookEvent":"SessionStart","hookName":"b","stdout":"{}","response":{"suppressOutput":True}}},
 {"type":"attachment","attachment":{"type":"hook_non_blocking_error","hookEvent":"SessionStart","hookName":"c","stderr":"ERR-NOT-COUNTED","stdout":"","exitCode":1}},
 {"type":"assistant","message":{}},
 {"type":"attachment","attachment":{"type":"skill_listing","content":"late"*1000,"skillCount":9}},
]
open(sys.argv[1],"w").write("\n".join(json.dumps(x) for x in L)+"\n")
PY
o="$("$CB" --mode transcript --transcript "$TR" --home /h --json)"; rc=$?
eq 0 "$rc" 'transcript: exit 0'
eq 50  "$(printf '%s' "$o" | jq_ 'd["by_category"]["system_prompt"]["bytes"]')" 'transcript: system prompt'
eq 200 "$(printf '%s' "$o" | jq_ 'd["by_category"]["rules"]["bytes"]')" 'transcript: rules classified'
eq 10  "$(printf '%s' "$o" | jq_ 'd["by_category"]["memory_index"]["bytes"]')" 'transcript: MEMORY.md classified'
eq 70  "$(printf '%s' "$o" | jq_ 'd["by_category"]["skills"]["bytes"]')" 'transcript: only initial window (before first reply)'
# 5 = "ab" + "\n" + "cd" (the two fixture deferred-tool names, newline-joined)
eq 5   "$(printf '%s' "$o" | jq_ 'd["by_category"]["deferred_tools"]["bytes"]')" 'transcript: deferred tool lines'
# 16 = 9 hook_success content + 7 async additionalContext; stdout/stderr/systemMessage not counted
eq 16  "$(printf '%s' "$o" | jq_ 'd["by_category"]["hooks"]["bytes"]')" 'transcript: injected hook text only (not stdout/stderr, not PostToolUse)'
eq 0   "$(printf '%s' "$o" | jq_ 'len([r for r in d["sources"] if r["category"]=="unknown"])')" 'transcript: async/non-blocking hook records not dumped as unknown'
# 381 = 50 system + 200 rules + 30 CLAUDE.md + 10 memory + 70 skills + 5 deferred + 16 hooks
eq 381 "$(printf '%s' "$o" | jq_ 'd["total"]["bytes"]')" 'transcript: total'
case "$o" in *SECRET-NOT-COUNTED*|*ASYNC-STDOUT-NOT-COUNTED*|*ERR-NOT-COUNTED*) no 'transcript: hook stdout/stderr never echoed' "$o" ;; *) ok 'transcript: hook stdout/stderr never echoed' ;; esac

# --- security: hook command line is never echoed (only name + argv[0] basename)
TS="$T/secret.jsonl"
python3 - "$TS" <<'PY2'
import json,sys
cmd = ("FOO_TOKEN=sk-fake123 /usr/local/bin/hookx --auth 'Bearer abcSECRETbearer' "
       "https://usr:pAsSwD@x.io/p?k=QUERYSECRET")
L=[{"type":"attachment","attachment":{"type":"hook_success","hookEvent":"SessionStart",
    "hookName":"SessionStart:startup","command":cmd,"content":"h"*5}},
   {"type":"assistant","message":{}}]
open(sys.argv[1],"w").write("\n".join(json.dumps(x) for x in L)+"\n")
PY2
for fmt in text json; do
  if [ "$fmt" = json ]; then o="$("$CB" --mode transcript --transcript "$TS" --home /h --json)"
  else o="$("$CB" --mode transcript --transcript "$TS" --home /h)"; fi
  leak=""
  for s in sk-fake123 FOO_TOKEN abcSECRETbearer pAsSwD QUERYSECRET usr:; do
    case "$o" in *"$s"*) leak="$leak $s";; esac
  done
  [ -z "$leak" ] && ok "security ($fmt): hook secrets not printed" || no "security ($fmt): hook secrets not printed" "$leak"
  case "$o" in *hookx*) ok "security ($fmt): argv[0] basename shown";; *) no "security ($fmt): argv[0] basename shown" "$o";; esac
done
o="$(printf '%s\n' '{"type":"attachment","attachment":{"type":"hook_success","hookEvent":"SessionStart","hookName":"n","command":"X_KEY=leakme \"unbalanced","content":"h"}}' > "$T/q.jsonl"; "$CB" --mode transcript --transcript "$T/q.jsonl" --home /h --json)"
case "$o" in *leakme*) no 'security: unbalanced quotes do not leak' "$o";; *) ok 'security: unbalanced quotes do not leak';; esac

# --- robustness: non-object records never crash; repeated/unknown attachments accumulate
TM="$T/messy.jsonl"
python3 - "$TM" <<'PY2'
import json,sys
L=[ [1,2], "a string", 7, None,
 {"type":"attachment","attachment":"not-a-dict"},
 {"type":"attachment","attachment":[1]},
 {"type":"attachment","attachment":{"type":"instructions","files":["x", 3,
   {"path":"/h/.claude/rules/r.md","type":"User","content":"r"*20}]}},
 {"type":"attachment","attachment":{"type":"skill_listing","content":"s"*30,"skillCount":2}},
 {"type":"attachment","attachment":{"type":"skill_listing","content":"t"*12,"skillCount":1}},
 {"type":"attachment","attachment":{"type":"brand_new_kind","payload":"p"*5}},
 {"type":"attachment","attachment":{"type":"brand_new_kind","payload":"q"*5}},
 {"type":"assistant","message":{}},
]
open(sys.argv[1],"w").write("\n".join(json.dumps(x) for x in L)+"\n")
PY2
o="$("$CB" --mode transcript --transcript "$TM" --home /h --json 2>&1)"; rc=$?
eq 0 "$rc" 'robust: malformed records do not crash (exit 0)'
eq 6  "$(printf '%s' "$o" | jq_ '[r for r in d["sources"] if r["category"]=="skipped"][0]["count"]')" 'robust: non-object records counted'
eq 20 "$(printf '%s' "$o" | jq_ 'd["by_category"]["rules"]["bytes"]')" 'robust: non-dict instruction files skipped, valid kept'
eq 42 "$(printf '%s' "$o" | jq_ 'd["by_category"]["skills"]["bytes"]')" 'accumulate: repeated attachments of one type summed'
eq 3  "$(printf '%s' "$o" | jq_ '[r for r in d["sources"] if r["category"]=="skills"][0]["count"]')" 'accumulate: counts summed'
eq 2  "$(printf '%s' "$o" | jq_ '[r for r in d["sources"] if r["source"]=="unknown:brand_new_kind"][0]["count"]')" 'unknown: type reported, not dropped'
"$CB" --mode transcript --transcript "$TM" --home /h >/dev/null 2>&1; eq 0 "$?" 'robust: text mode exit 0'

# --- skillCount: a boolean is not an int
TB="$T/bool.jsonl"
python3 - "$TB" <<'PY2'
import json,sys
L=[{"type":"attachment","attachment":{"type":"skill_listing","content":"s"*4,"skillCount":True}},
   {"type":"attachment","attachment":{"type":"skill_listing","content":"t"*4,"skillCount":2}},
   {"type":"assistant","message":{}}]
open(sys.argv[1],"w").write("\n".join(json.dumps(x) for x in L)+"\n")
PY2
o="$("$CB" --mode transcript --transcript "$TB" --home /h --json)"
eq 2 "$(printf '%s' "$o" | jq_ '[r for r in d["sources"] if r["category"]=="skills"][0]["count"]')" 'skillCount: boolean ignored'

# --- security: PASSWORD / PASS / AUTH keys redacted, look-alike words kept
TP="$T/pass.jsonl"
python3 - "$TP" <<'PY2'
import json,sys
L=[{"type":"attachment","attachment":{"type":"hook_success","hookEvent":"SessionStart",
    "hookName":"n DB_PASSWORD=pwone PASS=pwtwo MY_AUTH_HEADER=auththree --auth=authfour BYPASS=keepme",
    "command":"/bin/hk","content":"h"}},
   {"type":"assistant","message":{}}]
open(sys.argv[1],"w").write("\n".join(json.dumps(x) for x in L)+"\n")
PY2
for fmt in text json; do
  if [ "$fmt" = json ]; then o="$("$CB" --mode transcript --transcript "$TP" --home /h --json)"
  else o="$("$CB" --mode transcript --transcript "$TP" --home /h)"; fi
  leak=""
  for s in pwone pwtwo auththree authfour; do case "$o" in *"$s"*) leak="$leak $s";; esac; done
  [ -z "$leak" ] && ok "security ($fmt): PASSWORD/PASS/AUTH redacted" || no "security ($fmt): PASSWORD/PASS/AUTH redacted" "$leak"
  case "$o" in *BYPASS=keepme*) ok "security ($fmt): BYPASS not over-redacted";; *) no "security ($fmt): BYPASS not over-redacted" "$o";; esac
done

# --- robustness: enabledPlugins that is not an object is ignored and counted
H2="$T/home2"; mkdir -p "$H2/.claude/plugins"
printf '{"enabledPlugins":["a"]}' > "$H2/.claude/settings.json"
printf '{"plugins":{"a":[{"installPath":"/nonexistent"}]}}' > "$H2/.claude/plugins/installed_plugins.json"
o="$("$CB" --mode disk --home "$H2" --cwd "$W" --json 2>&1)"; rc=$?
eq 0 "$rc" 'robust: non-dict enabledPlugins does not crash'
eq 1 "$(printf '%s' "$o" | jq_ '[r for r in d["sources"] if r["source"]=="ignored malformed plugin config records"][0]["count"]')" 'robust: non-dict enabledPlugins counted as ignored'

# --- disk: a symlinked directory under commands/ is not traversed
H3="$T/home3"; mkdir -p "$H3/.claude/commands" "$T/outside"
printf -- '---\nname: c\ndescription: real\n---\n' > "$H3/.claude/commands/c.md"
printf -- '---\nname: o\ndescription: outside\n---\n' > "$T/outside/o.md"
ln -s "$T/outside" "$H3/.claude/commands/link"
o="$("$CB" --mode disk --home "$H3" --cwd "$W" --json)"
eq 1 "$(printf '%s' "$o" | jq_ '[r for r in d["sources"] if r["category"]=="commands"][0]["count"]')" 'disk: symlinked commands dir not followed'

# --- text mode + fallbacks
o="$("$CB" --mode transcript --transcript "$TR" --home /h --top 2)"
case "$o" in *"TOTAL"*"top 2 sources"*) ok 'text: table + top-N';; *) no 'text: table + top-N' "$o";; esac
"$CB" --mode transcript --transcript "$T/missing.jsonl" >/dev/null 2>&1; eq 1 "$?" 'transcript missing: exit 1'
err="$("$CB" --transcript "$T/missing.jsonl" --home "$H" --cwd "$W" 2>&1 >/dev/null)"; rc=$?
eq 1 "$rc" 'auto + explicit missing --transcript: exit 1 (no silent disk fallback)'
case "$err" in *"transcript not found"*) ok 'auto + explicit missing --transcript: error on stderr';; *) no 'auto + explicit missing --transcript: error on stderr' "$err";; esac
o="$("$CB" --home "$H" --cwd "$W" --json)"; rc=$?
eq 0 "$rc" 'auto without transcript: exit 0'
eq disk "$(printf '%s' "$o" | jq_ 'd["mode"]')" 'auto without transcript: falls back to disk'

# --- read-only: nothing written under fake HOME
# file list + per-file checksums: a new empty file changes the list, an edit the sums
snap() { find "$H" | sort; find "$H" -type f -exec cksum {} + | sort; }
before="$(snap)"
"$CB" --home "$H" --cwd "$W" >/dev/null
after="$(snap)"
eq "$before" "$after" 'read-only: fake HOME unchanged'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
