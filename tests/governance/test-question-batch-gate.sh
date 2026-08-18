#!/usr/bin/env sh
# question-batch-gate.test.sh — deterministic tests for the Stop-event question-batch
# gate. Every case below is either a documented behaviour or a REPRODUCTION of a
# red-team finding (H6 governance artifact — `red-teaming-mandatory-trigger`).
# Covers: firing threshold · the four exclusions (fence / blockquote / table / heading)
# · bold-question counting (the agent's own mandated emphasis style) · unbalanced-fence
# fail-toward-counting · one-shot idempotency · BLOCKING-1 unset HOME · BLOCKING-2 path
# traversal via payload-controlled session_id/prompt_id · BLOCKING-3 the ledger logs
# EVERY invocation incl. skips · threshold injection. Uses a temp QBG_STATE_DIR —
# never touches the real ~/.claude/state/. License: MIT.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"      # tests/governance/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"  # multi-agent-os path convention (see test-worktree-gate.sh)
HOOK="$PROJECT_ROOT/plugin-scripts/governance/question-batch-gate.sh"
TMP="$(mktemp -d)"
QBG_STATE_DIR="$TMP/state"; export QBG_STATE_DIR
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s — %s\n' "$1" "$2"; }

# emit <prompt_id> <message> -> stdout of hook; sets RC
emit() {
  OUT="$(jq -cn --arg m "$2" --arg p "$1" --arg s "${SID:-sess1}" \
    '{hook_event_name:"Stop",session_id:$s,prompt_id:$p,last_assistant_message:$m}' \
    | bash "$HOOK" 2>/dev/null)"; RC=$?
}
fired() { printf '%s' "$OUT" | grep -q 'additionalContext'; }

# expect <name> <fire:yes|no> <prompt_id> <message>
expect() {
  emit "$3" "$4"
  [ "$RC" -eq 0 ] || { bad "$1" "exit $RC (must ALWAYS be 0)"; return; }
  if fired; then g=yes; else g=no; fi
  [ "$g" = "$2" ] && ok "$1" || bad "$1" "expected fire=$2 got=$g"
}

printf '\n# threshold\n'
expect "3 questions fires"            yes t1 "Qual caminho?
Sigo com o merge?
Abro o PR?"
expect "1 question silent"            no  t2 "Pronto. Quer que eu mergeie?"
expect "2 questions (== threshold)"   no  t3 "O que acha?
Sigo?"
expect "3 questions on ONE line"      yes t4 "a? b? c?"

printf '\n# exclusions (self-inflicted false positives)\n'
expect "fenced code with ?"           no  x1 'Veja:
```bash
grep "why?" f
test -f a?
[ -n "$x" ] && echo ok?
```'
expect "blockquote = operator voice"  no  x2 "> qual é o backlog?
> em qual harness comecei?
> o que eu pensava?"
expect "table row"                    no  x3 "| item | persisted? | boy-scout? |
| a | y | y |
| b | y | y |"
expect "ATX headings"                 no  x4 "## Why?
### What next?
#### How?"
expect "real §4.1 fenced bullet list" no  x5 'Fechando:
```
STATUS CHECKLIST
- gaps · pendings · persisted? · boy-scout? · what-next ->
```'

printf '\n# counting fidelity (red-team MINOR-6)\n'
expect "**Bold question?** counts"    yes b1 "**Devo seguir?**
**Abro o PR?**
**Mergeio agora?**"
expect "unbalanced fence must NOT swallow" yes b2 'inicio
```bash
echo oi
Devo seguir?
Abro o PR?
Mergeio?'

printf '\n# safety invariants\n'
expect "idempotent: same prompt_id"   no  t1 "de novo?
e de novo?
e mais?"

emit "" "a?
b?
c?"
[ "$RC" -eq 0 ] && ! fired && ok "absent prompt_id -> exit 0, no injection" \
  || bad "absent prompt_id" "rc=$RC fired?"

printf '' | bash "$HOOK" >/dev/null 2>&1
[ $? -eq 0 ] && ok "empty stdin -> exit 0" || bad "empty stdin" "nonzero exit"

printf 'not json at all' | bash "$HOOK" >/dev/null 2>&1
[ $? -eq 0 ] && ok "non-JSON stdin -> exit 0" || bad "non-JSON stdin" "nonzero exit"

# BLOCKING-1: unset HOME must not abort under `set -u`
O="$(jq -cn '{session_id:"h",prompt_id:"h2",last_assistant_message:"a?\nb?\nc?"}' \
  | env -u HOME -u QBG_STATE_DIR PATH="$PATH" bash "$HOOK" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "unset HOME -> exit 0 (BLOCKING-1)" \
  || bad "unset HOME" "rc=$RC out=$(printf '%s' "$O" | head -1)"
# Issue #366 finding 4: with HOME unset, the hook falls back to
# ${HOME:-/tmp}/.claude/state/question-batch-gate = /tmp/.claude/state/
# question-batch-gate — a REAL path outside $TMP, left uncleaned and
# polluting later test runs' idempotency path (stray markers accumulate
# across CI runs on a shared /tmp). Bounded, literal, non-computed path.
rm -rf "/tmp/.claude/state/question-batch-gate" 2>/dev/null || true

# BLOCKING-2: payload-controlled ids must never escape STATE_DIR. Assert on
# directory-EMPTINESS of the victim dir, not a specific filename — issue #366
# finding 2: the original assertions checked for "$VICTIM/1.pwned.2.p9.marker.d"
# / "$VICTIM/1.x.marker.d", but the hook's actual marker format is
# "${#sid}.${sid}.${#pid}.${pid}.marker.d" (both filenames omitted the
# length-prefix), so those exact paths could never exist regardless of
# whether the guard held or regressed — the assertion was vacuous. The
# emptiness check (already used correctly below for the unsafe-session_id
# ord2 case) is robust to the exact marker-naming format.
VICTIM="$TMP/victim"; mkdir -p "$VICTIM"
SID="../../victim/pwned" emit "p9" "a?
b?
c?"
[ -z "$(ls -A "$VICTIM" 2>/dev/null)" ] && [ "$RC" -eq 0 ] \
  && ok "traversal via session_id blocked (BLOCKING-2)" \
  || bad "traversal session_id" "escaped to $VICTIM"
SID=sess1 emit "../../victim/x" "a?
b?
c?"
[ -z "$(ls -A "$VICTIM" 2>/dev/null)" ] && [ "$RC" -eq 0 ] \
  && ok "traversal via prompt_id blocked (BLOCKING-2)" \
  || bad "traversal prompt_id" "escaped to $VICTIM"

# BLOCKING-3: the ledger must record EVERY invocation, including skips
L="$QBG_STATE_DIR/ledger.jsonl"
if [ -s "$L" ]; then
  ok "ledger written ($(wc -l < "$L" | tr -d ' ') lines)"
  grep -q '"skipped"' "$L" && ok "skip paths are logged (BLOCKING-3)" \
    || bad "skip logging" "no skipped:* line — silent==healthy blind spot"
  grep -q '"fired":true' "$L" && ok "fired events logged" || bad "fired logging" "none"
else
  bad "ledger" "empty or missing"
fi

# threshold injection
O="$(jq -cn '{session_id:"s",prompt_id:"inj",last_assistant_message:"a?\nb?\nc?\nd?"}' \
  | QBG_MAX_QUESTIONS='2 ; touch '"$TMP"'/PWNED' bash "$HOOK" 2>/dev/null)"; RC=$?
[ ! -e "$TMP/PWNED" ] && [ "$RC" -eq 0 ] && ok "threshold injection inert" \
  || bad "threshold injection" "command executed"

printf '\n# v1.1.0 order fix: the count must be REAL on the id-skip paths\n'
# Empirical trigger: 19 of the first 55 real invocations hit
# `unsafe_or_absent_prompt_id`, and the pre-v1.1.0 order logged a HARDCODED
# `questions:0` there because the path-safety gate ran BEFORE the count. Those
# rows were indistinguishable from a genuine zero-question turn.
OL="$TMP/order-ledger"; mkdir -p "$OL"

# absent prompt_id + 4 real questions -> must still skip, but log questions:4
jq -cn '{session_id:"ord1",prompt_id:"",last_assistant_message:"a?\nb?\nc?\nd?"}' \
  | QBG_STATE_DIR="$OL" bash "$HOOK" >/dev/null 2>&1; RC=$?
OLL="$OL/ledger.jsonl"
[ "$RC" -eq 0 ] && ok "absent prompt_id still exits 0" \
  || bad "absent prompt_id exit" "exit $RC"
grep -q '"questions":4' "$OLL" 2>/dev/null \
  && ok "absent prompt_id logs the REAL count (4, not hardcoded 0)" \
  || bad "absent prompt_id count" "expected questions:4, got: $(tail -1 "$OLL" 2>/dev/null)"
grep -q '"skipped":"unsafe_or_absent_prompt_id"' "$OLL" 2>/dev/null \
  && ok "absent prompt_id still records the skip reason" \
  || bad "absent prompt_id skip reason" "missing"

# traversal-unsafe session_id + 3 questions -> skip, real count, no escape
VICTIM2="$TMP/victim2"; mkdir -p "$VICTIM2"
jq -cn --arg s "../../../../${VICTIM2#/}/x" \
  '{session_id:$s,prompt_id:"ord2",last_assistant_message:"a?\nb?\nc?"}' \
  | QBG_STATE_DIR="$OL" bash "$HOOK" >/dev/null 2>&1
grep -q '"questions":3' "$OLL" 2>/dev/null \
  && ok "unsafe session_id logs the REAL count (3)" \
  || bad "unsafe session_id count" "expected questions:3"
[ -z "$(ls -A "$VICTIM2" 2>/dev/null)" ] \
  && ok "unsafe session_id still blocked from escaping (BLOCKING-2 intact)" \
  || bad "unsafe session_id traversal" "victim dir not empty"

# under-threshold with absent prompt_id -> plain log, no skip reason needed
jq -cn '{session_id:"ord3",prompt_id:"",last_assistant_message:"tudo pronto."}' \
  | QBG_STATE_DIR="$OL" bash "$HOOK" >/dev/null 2>&1
tail -1 "$OLL" 2>/dev/null | grep -q '"questions":0' \
  && ok "under-threshold + absent id logs a genuine 0" \
  || bad "under-threshold absent id" "got: $(tail -1 "$OLL" 2>/dev/null)"

# the advisory must STILL fire normally when ids are present (no regression)
jq -cn '{session_id:"ord4",prompt_id:"ord4p",last_assistant_message:"a?\nb?\nc?"}' \
  | QBG_STATE_DIR="$OL" bash "$HOOK" 2>/dev/null | grep -q 'additionalContext' \
  && ok "advisory still fires with valid ids (no regression)" \
  || bad "advisory regression" "did not fire with valid ids"

printf '\n# issue #366 fix 1a: overlong ids are rejected (closes the ENAMETOOLONG root cause)\n'
LONG="$(awk 'BEGIN{s="";for(i=0;i<129;i++)s=s "a"; print s}')"  # 129 chars, over the 128 cap
O="$(jq -cn --arg s "$LONG" '{session_id:$s,prompt_id:"okpid",last_assistant_message:"a?\nb?\nc?"}' \
  | bash "$HOOK" 2>/dev/null)"; RC=$?
[ "$RC" -eq 0 ] && ! printf '%s' "$O" | grep -q additionalContext \
  && ok "overlong session_id rejected, no injection" \
  || bad "overlong session_id" "rc=$RC out=$O"

printf '\n# issue #366 fix 1b: a non-duplicate mkdir failure logs marker_claim_failed, not idempotent\n'
FL="$TMP/failstate"; mkdir -p "$FL"
MARKER="$FL/3.fl1.3.fl2.marker.d"
: > "$MARKER"   # pre-existing FILE (not dir) at the exact marker path the hook targets
jq -cn '{session_id:"fl1",prompt_id:"fl2",last_assistant_message:"a?\nb?\nc?"}' \
  | QBG_STATE_DIR="$FL" bash "$HOOK" >/dev/null 2>&1
FLL="$FL/ledger.jsonl"
tail -1 "$FLL" 2>/dev/null | grep -q '"skipped":"marker_claim_failed"' \
  && ok "mkdir-failure-not-a-duplicate logs marker_claim_failed (not idempotent)" \
  || bad "marker_claim_failed" "got: $(tail -1 "$FLL" 2>/dev/null)"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
rm -rf "$TMP"
[ "$FAIL" -eq 0 ]
