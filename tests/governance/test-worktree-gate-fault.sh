#!/usr/bin/env bash
# Regression: an UNEXPECTED fault inside worktree-gate.sh must fail CLOSED for git
# commands (exit 2 = BLOCK) and must not launch an AI CLI unless MAOS_SELFHEAL=1.
# The fault is injected into a sandbox copy of the hook (a lib that fails to source).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../../plugin-scripts/governance"

SBX="$(mktemp -d)" || { echo "FAIL: mktemp"; exit 1; }
[ -n "$SBX" ] && [ -d "$SBX" ] || { echo "FAIL: sandbox"; exit 1; }
trap 'rm -rf "$SBX"' EXIT

cp -R "$SRC" "$SBX/governance"
echo 'false' >> "$SBX/governance/lib/worktree-utils.sh"   # injected fault: source returns 1
GATE="$SBX/governance/worktree-gate.sh"

# Fake AI CLI: records that it was launched.
mkdir -p "$SBX/bin"
printf '#!/usr/bin/env bash\ntouch "%s/claude-launched"\n' "$SBX" > "$SBX/bin/claude"
chmod +x "$SBX/bin/claude"

PASS=0; FAIL=0
ok()  { echo "  PASS $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }
run() { # $1 = stdin json; extra env via caller
  # env -u: an inherited MAOS_SELFHEAL=1 must not mask the default under test.
  printf '%s' "$1" | env -u MAOS_SELFHEAL -u MAOS_AI_HARNESS PATH="$SBX/bin:$PATH" TMPDIR="$SBX" bash "$GATE" >/dev/null 2>&1; echo $?
}

rc="$(run '{"tool_input":{"command":"git commit -m x"}}')"
[ "$rc" = 2 ] && ok "fault on git command blocks (exit 2)" || bad "git command fault exit=$rc (want 2)"
[ ! -e "$SBX/claude-launched" ] && ok "no AI CLI launched by default" || bad "AI CLI launched without opt-in"

rc="$(run '')"
[ "$rc" = 2 ] && ok "fault with unreadable input blocks" || bad "empty input fault exit=$rc (want 2)"

rc="$(run '{"tool_input":{"command":"ls -la"}}')"
[ "$rc" != 2 ] && [ "$rc" != 0 ] && ok "fault on non-git command keeps original code ($rc)" || bad "non-git fault exit=$rc"

rm -f "$SBX/claude-launched"
rc="$(printf '%s' '{"tool_input":{"command":"git commit -m x"}}' | MAOS_SELFHEAL=1 MAOS_AI_HARNESS=claude PATH="$SBX/bin:$PATH" TMPDIR="$SBX" bash "$GATE" >/dev/null 2>&1; echo $?)"
[ -e "$SBX/claude-launched" ] && ok "opt-in relay still dispatches (positive control)" || bad "opt-in relay did not dispatch"
[ "$rc" = 2 ] && ok "opt-in relay still blocks the git command" || bad "opt-in exit=$rc (want 2)"

# Faults INSIDE a function or from `set -u` never fire an ERR trap (no errtrace)
# and exit 1; the gate must still block. Evaluated in a fresh repo on main so the
# gate reaches its RF01 branch-creation path.
# shellcheck source=/dev/null
source "$HERE/../lib/fixture-guard.sh"   # #495: fail closed before git mutations
fx_reject_git_env || exit 1
REPO="$SBX/repo"; fx_mkdir "$REPO" || exit 1
( fx_enter_fresh "$REPO" && git init -q -b main && fx_assert_root "$REPO" \
    && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init ) >/dev/null 2>&1 \
  || { echo "FAIL: fixture repo"; exit 1; }
for kind in fn unbound; do
  rm -rf "$SBX/g-$kind"; cp -R "$SRC" "$SBX/g-$kind"
  case "$kind" in
    fn)      echo 'log_audit() { false; echo after; }' >> "$SBX/g-$kind/lib/worktree-utils.sh" ;;
    unbound) echo 'log_audit() { echo "$MAOS_TEST_UNSET_VAR_XYZ"; }' >> "$SBX/g-$kind/lib/worktree-utils.sh" ;;
  esac
  rc="$(fx_enter "$REPO" && printf '%s' '{"tool_input":{"command":"git checkout -b feat/x"}}' \
        | PATH="$SBX/bin:$PATH" TMPDIR="$SBX" bash "$SBX/g-$kind/worktree-gate.sh" >/dev/null 2>&1; echo $?)"
  [ "$rc" = 2 ] && ok "fault inside a function ($kind) blocks (exit 2)" || bad "function fault ($kind) exit=$rc (want 2)"
done
rc="$(fx_enter "$REPO" && printf '%s' '{"tool_input":{"command":"git checkout -b feat/x"}}' | bash "$SRC/worktree-gate.sh" >/dev/null 2>&1; echo $?)"
[ "$rc" = 2 ] && ok "healthy hook blocks branch creation on main (control)" || bad "healthy hook RF01 exit=$rc (want 2)"

# Positive control: the unbroken hook still allows a plain non-git command.
rc="$(printf '%s' '{"tool_input":{"command":"ls"}}' | bash "$SRC/worktree-gate.sh" >/dev/null 2>&1; echo $?)"
[ "$rc" = 0 ] && ok "healthy hook allows non-git command" || bad "healthy hook exit=$rc"

echo "worktree-gate fault: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
