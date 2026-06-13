#!/usr/bin/env bash
# Tests for the R0 ticket-anchor section of plugin-scripts/governance/preflight-session.sh.
# Bash 3.2-safe, self-contained. Runs the real hook against synthetic repos via
# CLAUDE_PROJECT_DIR. Asserts: seed › branch › commit precedence, none→nudge, opt-out,
# offline-still-anchors, non-git silent exit 0, <2s, garbage-seed exit 0.
# Run: bash tests/governance/test-preflight-session-r0.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK="$DIR/../../plugin-scripts/governance/preflight-session.sh"

pass=0 ; fail=0
ok() { pass=$((pass + 1)); printf '  \xe2\x9c\x93 %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \xe2\x9c\x97 %s\n      got: [%s]\n' "$1" "$2"; }
has()  { case "$2" in *"$1"*) ok "$3" ;; *) no "$3" "$2" ;; esac; }
hasnt(){ case "$2" in *"$1"*) no "$3" "$2" ;; *) ok "$3" ;; esac; }
eq()   { [ "$1" = "$2" ] && ok "$3" || no "$3" "got=[$2] want=[$1]"; }

printf 'test-preflight-session-r0.sh\n'

ROOT="$(mktemp -d)"
mkrepo() {  # $1=name [+ optional branch] → echoes path
  local d="$ROOT/$1"; rm -rf "$d"; mkdir -p "$d"
  ( cd "$d" && git init -q && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init ) >/dev/null 2>&1
  printf '%s' "$d"
}
ctx() { CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>/dev/null | sed -n 's/.*"additionalContext":"\(.*\)"}}/\1/p'; }

# branch source
R="$(mkrepo branch)"; ( cd "$R" && git checkout -q -b feature/VKS-2178-r0 ) >/dev/null 2>&1
o="$(ctx "$R")"; has 'ticket=VKS-2178 (source=branch, mode=anchored)' "$o" 'R0 branch source anchors'

# commit source (no-ticket branch, ticket in last commit)
R="$(mkrepo commit)"; ( cd "$R" && git checkout -q -b plain && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m 'feat: DEF-123 x' ) >/dev/null 2>&1
o="$(ctx "$R")"; has 'ticket=DEF-123 (source=commit, mode=anchored)' "$o" 'R0 commit source anchors'

# seed precedence (branch ALSO has a ticket → seed must win, mode=continuation-candidate)
R="$(mkrepo seed)"; ( cd "$R" && git checkout -q -b feature/BR-1-x ) >/dev/null 2>&1
mkdir -p "$R/.git/maos"; printf '{"refs":{"ticket":"SEED-777"}}\n' > "$R/.git/maos/continuation-seed.latest.json"
o="$(ctx "$R")"; has 'ticket=SEED-777 (source=seed, mode=continuation-candidate)' "$o" 'R0 seed wins over branch'

# WORKTREE-SAFE seed path (Qodo #141 bug): in a linked worktree "$REPO/.git" is a FILE, not a dir.
# Seed lives in the COMMON git-dir's maos/; R0 must still find it (not silently miss continuation).
WTR="$(mkrepo wtmain)"; ( cd "$WTR" && git checkout -q -b feature/MAIN-1-x ) >/dev/null 2>&1
mkdir -p "$WTR/.git/maos"; printf '{"refs":{"ticket":"WT-555"}}\n' > "$WTR/.git/maos/continuation-seed.latest.json"
LW="$WTR-linked"; rm -rf "$LW"
( cd "$WTR" && git worktree add -q "$LW" -b feature/LINKED-9-x ) >/dev/null 2>&1
if [ -f "$LW/.git" ]; then   # confirm it's a gitlink FILE (the bug precondition)
  o="$(ctx "$LW")"; has 'ticket=WT-555 (source=seed, mode=continuation-candidate)' "$o" 'R0 finds seed in COMMON git-dir from a linked worktree (gitlink-file safe)'
else
  ok 'R0 worktree-safe seed (skipped: linked worktree not a gitlink file on this fs)'
fi
( cd "$WTR" && git worktree remove --force "$LW" 2>/dev/null ) || rm -rf "$LW"

# none → nudge + NO ticket token
R="$(mkrepo none)"; ( cd "$R" && git checkout -q -b just-a-name ) >/dev/null 2>&1
o="$(ctx "$R")"; has 'No ticket anchor detected' "$o" 'R0 no-anchor → nudge'
has 'mode=unanchored' "$o" 'R0 no-anchor → mode=unanchored'
hasnt ' ticket=' "$o" 'R0 no-anchor → no ticket token leaked'

# opt-out PREFLIGHT_NO_TICKET_ANCHOR=1
R="$(mkrepo optout)"; ( cd "$R" && git checkout -q -b feature/OPT-9-x ) >/dev/null 2>&1
o="$(CLAUDE_PROJECT_DIR="$R" PREFLIGHT_NO_TICKET_ANCHOR=1 bash "$HOOK" 2>/dev/null | sed -n 's/.*"additionalContext":"\(.*\)"}}/\1/p')"
hasnt 'ticket=OPT-9' "$o" 'R0 opt-out skips anchor'

# offline (gh/curl shimmed to fail) — R0 still anchors from branch
R="$(mkrepo offline)"; ( cd "$R" && git checkout -q -b feature/OFF-5-x ) >/dev/null 2>&1
SHIM="$ROOT/shim"; rm -rf "$SHIM"; mkdir -p "$SHIM"
for c in gh curl; do printf '#!/bin/sh\nexit 99\n' > "$SHIM/$c"; chmod +x "$SHIM/$c"; done
o="$(CLAUDE_PROJECT_DIR="$R" PATH="$SHIM:$PATH" bash "$HOOK" 2>/dev/null | sed -n 's/.*"additionalContext":"\(.*\)"}}/\1/p')"
has 'ticket=OFF-5 (source=branch' "$o" 'R0 anchors offline (gh/curl unavailable)'

# non-git dir → silent exit 0, empty stdout (use system temp, outside any repo)
ND="$(mktemp -d /tmp/r0-notgit.XXXXXX)"
out="$(CLAUDE_PROJECT_DIR="$ND" bash "$HOOK" 2>/dev/null)"; rc=$?
eq 0 "$rc" 'R0 non-git → exit 0'
eq 0 "$(printf '%s' "$out" | wc -c | tr -d ' ')" 'R0 non-git → empty stdout'
rm -rf "$ND"

# garbage seed → exit 0 (never crash)
R="$(mkrepo garbage)"; ( cd "$R" && git checkout -q -b x ) >/dev/null 2>&1
mkdir -p "$R/.git/maos"; printf 'not json {{{' > "$R/.git/maos/continuation-seed.latest.json"
CLAUDE_PROJECT_DIR="$R" bash "$HOOK" >/dev/null 2>&1; eq 0 "$?" 'R0 garbage seed → exit 0'

# timing <2s — sub-second resolution (whole-second date +%s is flaky across a second boundary).
# Portable hi-res via perl Time::HiRes (present on macOS + Linux CI); fall back to date +%s.
now_ms() { perl -MTime::HiRes=time -e 'printf "%d", time*1000' 2>/dev/null || echo "$(( $(date +%s) * 1000 ))"; }
R="$(mkrepo timing)"; ( cd "$R" && git checkout -q -b feature/TIM-1-x ) >/dev/null 2>&1
T0=$(now_ms); CLAUDE_PROJECT_DIR="$R" bash "$HOOK" >/dev/null 2>&1; T1=$(now_ms)
ELAPSED_MS=$((T1-T0))
[ "$ELAPSED_MS" -lt 2000 ] && ok 'R0 completes <2s' || no 'R0 completes <2s' "${ELAPSED_MS}ms"

rm -rf "$ROOT"
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
