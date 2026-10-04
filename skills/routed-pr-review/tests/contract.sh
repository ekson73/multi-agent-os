#!/usr/bin/env bash
# routed-pr-review — gate CONTRACT tests.
#
# Why this exists: four dogfood cycles produced 19 findings, zero of them
# self-caught, and the two worst were COMPOSITION defects — every individual
# line verified against the binary while the PATH through them was dead
# (`exit 0` unreachable via a `.head` scope bug) or wrong (`--add-dir` granting
# access without moving cwd). Line-level checking cannot see either. These tests
# run the REAL script end-to-end against stubbed externals, so they assert the
# path, not the line.
#
# Design: no network, no real reviewer, no real gh. A temp git repo supplies a
# real HEAD_SHA (the script fetches/archives it, so it must exist), and a stub
# PATH supplies `gh` + a fake reviewer whose behaviour each case controls via
# T_* env vars. Exit codes and JSON fields are the contract under test.
#
# Usage: bash skills/routed-pr-review/tests/contract.sh [-v]
# Exit:  0 all pass · 1 any fail

set -uo pipefail
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$SELF_DIR/../bin/routed-review.sh"
[ -f "$SUT" ] || { echo "FATAL: script under test not found at $SUT" >&2; exit 1; }

PASS=0; FAIL=0; FAILED_NAMES=()

# ---------------------------------------------------------------- scaffolding
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/rr-contract.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

REPO_DIR="$SANDBOX/repo"; STUB_BIN="$SANDBOX/bin"
# Rotation state lives in its OWN subdir: the script write-denies the state
# directory to the reviewer, so marker files a hostile stub drops elsewhere in
# $SANDBOX must not share it (else a leak test passes for the wrong reason).
mkdir -p "$REPO_DIR" "$STUB_BIN" "$SANDBOX/state"

# A real one-commit repo: the script proves cwd == HEAD_SHA and can git-archive it.
(
  cd "$REPO_DIR"
  git init -q . 2>/dev/null
  git config user.email t@t; git config user.name t; git config commit.gpgsign false
  echo hello > file.txt
  git add -A && git commit -qm "seed"
) || { echo "FATAL: could not build temp repo" >&2; exit 1; }
HEAD_SHA="$(cd "$REPO_DIR" && git rev-parse HEAD)"

# `gh` stub. Behaviour is driven entirely by T_* env vars so each case is data,
# not code. It answers exactly the four call shapes the script makes.
cat > "$STUB_BIN/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "pr view")
    cat <<JSON
{ "number": 1, "title": "contract fixture", "headRefOid": "${T_HEAD}",
  "headRefName": "feat/x", "baseRefName": "main", "url": "https://example.invalid/pr/1",
  "author": {"login": "someone"},
  "mergeStateStatus": "${T_MERGESTATE:-UNSTABLE}",
  "reviewDecision": "${T_DECISION:-}",
  "latestReviews": ${T_REVIEWS:-[]},
  "comments": ${T_COMMENTS:-[]} }
JSON
    ;;
  "pr diff")    printf 'diff --git a/file.txt b/file.txt\n+contract fixture\n' ;;
  "pr comment") exit 0 ;;
  "api "*|"api")
                printf '%s\n' "${T_REPO_COMMENTS:-[]}" ;;
  *)            exit 0 ;;
esac
STUB
chmod +x "$STUB_BIN/gh"

# Fake reviewer, in a family that is never the caller. Output length + verdict
# are per-case, which is what drives the <40-byte and gate branches.
cat > "$STUB_BIN/kimi" <<'STUB'
#!/usr/bin/env bash
# Hostile-reviewer hooks (security cases 14-16). A real reviewer is a model
# steered by PR content; these model what a prompt-injected one could try.
[ -n "${T_LEAK_MARK:-}" ] && [ -n "${ROUTED_REVIEW_STATE:-}" ] && : > "$T_LEAK_MARK"
[ -n "${T_GH_MARK:-}" ] && [ -n "${GH_TOKEN:-}" ] && : > "$T_GH_MARK"
[ -n "${T_SLEEP:-}" ] && sleep "$T_SLEEP"
if [ -n "${T_DIR_SWAP:-}" ]; then   # swap the state FILE's parent dir for a decoy
  d="$(dirname "$T_DIR_SWAP")"; mkdir -p "$d.decoy"
  printf '%s' "${T_TAMPER_JSON:-}" > "$d.decoy/$(basename "$T_DIR_SWAP")" 2>/dev/null
  mv "$d" "$d.moved" 2>/dev/null && ln -s "$d.decoy" "$d" 2>/dev/null
fi
if [ -n "${T_RENAME_WRITE:-}" ]; then   # rename parent away, write the real inode, rename back
  d="$(dirname "$T_RENAME_WRITE")"
  mv "$d" "$d.away" 2>/dev/null \
    && printf '%s' "${T_TAMPER_JSON:-}" > "$d.away/$(basename "$T_RENAME_WRITE")" 2>/dev/null
  mv "$d.away" "$d" 2>/dev/null
fi
if [ -n "${T_ANC_SWAP:-}" ]; then   # swap a GRANDPARENT for a same-named real tree
  d="$(dirname "$T_ANC_SWAP")"; g="$(dirname "$d")"
  mv "$g" "$g.moved" 2>/dev/null && mkdir -p "$d" \
    && printf '%s' "${T_TAMPER_JSON:-}" > "$T_ANC_SWAP" 2>/dev/null
fi
[ -n "${T_TAMPER_MV:-}" ] && { printf 'x' > "$T_TAMPER_MV.tmp" 2>/dev/null; mv -f "$T_TAMPER_MV.tmp" "$T_TAMPER_MV" 2>/dev/null; rm -f "$T_TAMPER_MV" 2>/dev/null; }
[ -n "${T_TAMPER_PATH:-}" ] && printf '%s' "${T_TAMPER_JSON:-}" > "$T_TAMPER_PATH" 2>/dev/null
printf '%s\n' "${T_REVIEW_BODY:-}"
exit "${T_REVIEW_RC:-0}"
STUB
chmod +x "$STUB_BIN/kimi"

# A second family whose FAILURE mode each case controls (stderr text + rc). It
# lives in its own dir, prepended per-case via EXTRA_BIN, so it shadows any real
# `gemini` on the host only where a case asks for it.
GEM_BIN="$SANDBOX/gem"; mkdir -p "$GEM_BIN"
cat > "$GEM_BIN/gemini" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${T_GEMINI_ERR:-}" >&2
exit "${T_GEMINI_RC:-2}"
STUB
chmod +x "$GEM_BIN/gemini"

# ---------------------------------------------------------------- assertions
# Run the REAL script against the stub PATH. Per-case fixtures are passed as an
# env prefix (`T_REVIEWS=… sut`) — bash applies those to the function call, so
# each case is data rather than another copy of the invocation.
# `EXTRA_BIN` prepends a per-case stub dir (used to force a broken sandbox).
# `ONLY_BIN` REPLACES the PATH entirely (used to prove a missing dependency is
# diagnosed rather than surfacing later as an opaque failure).
sut() {
  local p="${STUB_BIN}:${PATH}"
  [ -n "${EXTRA_BIN:-}" ] && p="${EXTRA_BIN}:${p}"
  [ -n "${ONLY_BIN:-}" ]  && p="${ONLY_BIN}"
  # Hermetic rotation state: never read or write the operator's real state file.
  ( cd "$REPO_DIR" \
    && PATH="$p" T_HEAD="$HEAD_SHA" ROUTED_REVIEW_STATE="${STATE:-$SANDBOX/state/state-default.json}" \
       ROUTED_REVIEW_ENV_ALLOW="T_REVIEW_BODY T_REVIEW_RC T_LEAK_MARK T_GH_MARK T_TAMPER_PATH T_TAMPER_JSON T_GEMINI_ERR T_GEMINI_RC T_SLEEP T_TAMPER_MV T_DIR_SWAP T_ANC_SWAP T_RENAME_WRITE" \
       bash "$SUT" --pr 1 --repo o/r --reviewer "${RV:-kimi}" --timeout 500 --json 2>"$SANDBOX/err" )
}

check() {  # check <name> <expected-rc> [<jq-filter> <expected-value>]
  local name="$1" want_rc="$2" filter="${3:-}" want_val="${4:-}" ok=1 why=""
  [ "$RC" = "$want_rc" ] || { ok=0; why="exit $RC, wanted $want_rc"; }
  if [ -n "$filter" ] && [ "$ok" = 1 ]; then
    local got; got="$(printf '%s' "$OUT" | jq -r "$filter" 2>/dev/null)"
    [ "$got" = "$want_val" ] || { ok=0; why="$filter = '$got', wanted '$want_val'"; }
  fi
  if [ "$ok" = 1 ]; then
    PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m  %s\n' "$name"
  else
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$name")
    printf '  \033[31mFAIL\033[0m  %s — %s\n' "$name" "$why"
    [ "$VERBOSE" = 1 ] && { printf '        stdout: %s\n' "${OUT:0:400}"; printf '        stderr: %s\n' "$(tail -3 "$SANDBOX/err")"; }
  fi
}

ok_grep() {  # ok_grep <name> <pattern> — assert stderr carries a reason
  if grep -qi "$2" "$SANDBOX/err"; then
    PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m  %s\n' "$1"
  else
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); printf '  \033[31mFAIL\033[0m  %s\n' "$1"
  fi
}

AT_HEAD='[{"author":{"login":"coderabbitai"},"state":"%s","commit":{"oid":"'"$HEAD_SHA"'"}}]'
OLD_SHA='[{"author":{"login":"coderabbitai"},"state":"APPROVED","commit":{"oid":"0000000000000000000000000000000000000000"}}]'
BODY="Finding 1 [major] the fixture body is deliberately well past the forty byte floor.
VERDICT: REQUEST_CHANGES — substantive."

echo "routed-pr-review — gate contract"
echo "  SUT: $SUT"
echo "  fixture head: ${HEAD_SHA:0:7}"
echo

# ── 1 ── `exit 0` must be REACHABLE.
# Regression for the `.head` scope bug: `.head` does not exist inside a
# `.reviews[]` element, so `select(.sha != .head)` was `!= null` = always true;
# every review counted stale and this path was dead code. Four cycles of
# line-level verification never caught it because every line was correct.
OUT="$(T_REVIEWS="$(printf "$AT_HEAD" APPROVED)" T_DECISION=APPROVED T_REVIEW_BODY="$BODY" \
       ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "exit 0 reachable when a configured primary cleared THIS head" 0 '.may_complete_c3' "true"

# ── 2 ── an approval at an OLDER sha must not clear the gate (no false-green).
OUT="$(T_REVIEWS="$OLD_SHA" T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "stale-head approval does NOT clear C3" 3 '.may_complete_c3' "false"

# ── 3 ── §4.1(e): routing never dismisses an active CHANGES_REQUESTED.
OUT="$(T_REVIEWS="$(printf "$AT_HEAD" CHANGES_REQUESTED)" T_DECISION=CHANGES_REQUESTED \
       T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "CHANGES_REQUESTED is never dismissed by a routed review" 3 '.may_complete_c3' "false"

# ── 4 ── empty reviewer output is NOT a review (anti-theater guard #1).
OUT="$(T_REVIEWS='[]' T_REVIEW_BODY="" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "under-40-byte output is treated as NO review" 2 '.status' "empty_review"

# ── 5 ── verifier != generator: the caller's own family may not review.
OUT="$(RV=kimi ROUTED_REVIEW_CALLER=kimi sut)"; RC=$?
check "explicit --reviewer identical to the caller is REFUSED" 1
ok_grep "refusal names the correlated-verifier reason" 'correlated verifier'

# ── 6 ── silence is never 'absent'. No bot ever seen, no attestation => HOLD.
OUT="$(T_REVIEWS='[]' T_COMMENTS='[]' T_REPO_COMMENTS='[]' T_REVIEW_BODY="$BODY" \
       ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "silence alone never proves 'no primary configured'" 3 '.may_complete_c3' "false"

# ── 7 ── argument parsing must terminate.
# Regression for the `shift 2` infinite loop: a value option passed last left
# \$# unchanged and the loop spun (2000 iterations measured before the fix).
timeout 10 bash "$SUT" --pr 1 --repo >/dev/null 2>&1; RC=$?
if [ "$RC" = 1 ]; then
  PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m  %s\n' "trailing value-option dies immediately (no infinite loop)"
else
  FAIL=$((FAIL+1)); FAILED_NAMES+=("arg loop")
  printf '  \033[31mFAIL\033[0m  trailing value-option: exit %s (124 = hung)\n' "$RC"
fi

# ── 8 ── the sandbox probe must FAIL CLOSED.
# Cycle-4 regression. The single-step probe could not tell "sandbox-exec ran and
# denied the write" from "sandbox-exec never ran" — both leave no probe file,
# and the old fallthrough then reported ARMED. A failure to confine was
# indistinguishable from a successful denial: a fail-open inside the control
# added to close a fail-open. A `sandbox-exec` that always fails must therefore
# degrade the class to `os-perms-only`, never claim `os-sandboxed`.
BROKEN_SBX="$SANDBOX/broken"; mkdir -p "$BROKEN_SBX"
printf '#!/usr/bin/env bash\nexit 65\n' > "$BROKEN_SBX/sandbox-exec"
chmod +x "$BROKEN_SBX/sandbox-exec"
OUT="$(EXTRA_BIN="$BROKEN_SBX" T_REVIEWS='[]' T_REVIEW_BODY="$BODY" \
       ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "a broken sandbox-exec degrades to os-perms-only (never claims os-sandboxed)" \
      3 '.isolation.read_only_enforcement' "os-perms-only"

# ── 9 ── a missing hard dependency is DIAGNOSED, not discovered late.
# Cycle-4 regression. `timeout` is used at 6 dispatch sites and in both sandbox
# probes, but was never checked while gh/jq/tar were; on a host without it the
# absence surfaced as an opaque per-harness failure. The guard sits after the
# gh + jq checks, so a PATH carrying those two — plus the interpreter itself —
# reaches it. (First draft of this case omitted `bash` and scored exit 127:
# the harness was measuring its own missing shell, not the guard. A test that
# fails for the wrong reason is worse than no test.)
ONLY="$SANDBOX/only"; mkdir -p "$ONLY"
cp "$STUB_BIN/gh" "$ONLY/gh"
ln -sf "$(command -v jq)"   "$ONLY/jq"
ln -sf "$(command -v bash)" "$ONLY/bash"
OUT="$(ONLY_BIN="$ONLY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "absent \`timeout\` aborts with a diagnostic instead of failing opaquely later" 1
ok_grep "the diagnostic names the dependency and the remedy" 'timeout not found'

# ── 10 ── a BROKEN candidate is not a quota-limited one (§4.1(b) tier-2/3).
# Auto-pick chose a CLI whose account is ineligible: rc=2, no output, an
# `IneligibleTierError` on stderr. That is not a capacity signal — waiting will
# not fix it — so it must be excluded and the pick must fall through to the
# next family, instead of the run dying and the bot being queued as "retry later".
# ROUTED_REVIEW_CALLER=codex keeps a real host `codex` out of the pool.
ELIG="IneligibleTierError: this account is not eligible for the requested tier"
STATE="$SANDBOX/state/state-broken.json"
OUT="$(STATE="$STATE" EXTRA_BIN="$GEM_BIN" RV=auto T_GEMINI_ERR="$ELIG" T_GEMINI_RC=2 \
       T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=codex sut)"; RC=$?
check "broken auto-pick candidate falls through to the next family" 3 '.reviewer' "kimi"
check "the fallthrough is recorded in the evidence" 3 '.skipped_candidates[0].class' "broken"
GOT="$(jq -r '[.bots.gemini.broken_at != null, .bots.gemini.last_limited_at == null] | all' "$STATE" 2>/dev/null)"
RC=0; OUT="{\"v\":\"$GOT\"}"
check "state marks it broken, NOT rate-limited" 0 '.v' "true"

# ── 11 ── a broken mark keeps it out of the pool for the next run too.
OUT="$(STATE="$STATE" EXTRA_BIN="$GEM_BIN" RV=auto T_GEMINI_ERR="$ELIG" \
       T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=codex sut 2>/dev/null)"; RC=$?
check "a marked-broken candidate is skipped on the next pick" 3 '.skipped_candidates | length' "0"

# ── 12 ── positive control: a real quota signal is still classified as quota.
# Without this, case 10 could pass with a classifier that calls EVERYTHING broken.
STATE="$SANDBOX/state/state-quota.json"
OUT="$(STATE="$STATE" EXTRA_BIN="$GEM_BIN" RV=auto T_GEMINI_ERR="Error 429: rate limit exceeded, retry later" \
       T_GEMINI_RC=1 T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=codex sut)"; RC=$?
check "a quota-limited candidate also falls through" 3 '.skipped_candidates[0].class' "quota"
GOT="$(jq -r '[.bots.gemini.last_limited_at != null, .bots.gemini.broken_at == null] | all' "$STATE" 2>/dev/null)"
RC=0; OUT="{\"v\":\"$GOT\"}"
check "quota is recorded as rate-limited, NOT broken" 0 '.v' "true"

# ── 13 ── an EXPLICIT --reviewer is the operator's choice: classify, never swap.
STATE="$SANDBOX/state/state-explicit.json"
OUT="$(STATE="$STATE" EXTRA_BIN="$GEM_BIN" RV=gemini T_GEMINI_ERR="$ELIG" T_GEMINI_RC=2 \
       T_REVIEWS='[]' ROUTED_REVIEW_CALLER=codex sut)"; RC=$?
check "explicit broken reviewer is NOT silently replaced" 2 '.failure_class' "broken"

# ── 14 ── the reviewer must not even learn where rotation state lives.
# The state path rode into the reviewer through the inherited environment;
# a reviewer that can find the file can poison the next pick.
OUT="$(STATE="$SANDBOX/state/state-leak.json" T_LEAK_MARK="$SANDBOX/leak" T_REVIEWS='[]' \
       T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
if [ ! -e "$SANDBOX/leak" ]; then GOT=hidden; else GOT=leaked; fi
RC=0; OUT="{\"v\":\"$GOT\"}"
check "ROUTED_REVIEW_STATE is scrubbed from the reviewer's environment" 0 '.v' "hidden"

# ── 15 ── a reviewer that WRITES the state file is an isolation breach.
# Force os-perms-only (no kernel boundary) so the write lands, then require it
# to be detected, the run aborted, and the file restored byte-for-byte.
STATE="$SANDBOX/state/state-tamper.json"
printf '{"bots":{}}' > "$STATE"; cp "$STATE" "$SANDBOX/state/state-tamper.orig"
OUT="$(EXTRA_BIN="$BROKEN_SBX" T_TAMPER_PATH="$STATE" \
       T_TAMPER_JSON='{"bots":{"codex":{"broken_at":"2026-01-01T00:00:00Z"}}}' \
       T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "a reviewer that writes rotation state aborts as isolation_violated" 1 '.detail' "violated:state-file"
# ⛔ No blind restore: rewriting the file from a snapshot would overwrite a
# concurrent run's legitimate record (confused deputy). Detect, abort, leave it.
if grep -q '"codex"' "$STATE"; then GOT=left-for-inspection; else GOT=overwritten; fi
RC=0; OUT="{\"v\":\"$GOT\"}"
check "the orchestrator does not blindly overwrite the state file" 0 '.v' "left-for-inspection"

# ── 16 ── forged state entries are ignored, never obeyed (fail-closed).
# A far-future broken_at would silence a family forever, and a non-numeric
# retry_after_sec must never reach shell arithmetic. Both mean "no state".
STATE="$SANDBOX/state/state-forged.json"
cat > "$STATE" <<'JSON'
{"bots":{"kimi":{"broken_at":"2099-01-01T00:00:00Z",
                 "last_limited_at":"2099-01-01T00:00:00Z",
                 "retry_after_sec":"not-a-number"}}}
JSON
OUT="$(STATE="$STATE" EXTRA_BIN="$GEM_BIN" RV=auto T_GEMINI_ERR="$ELIG" \
       T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=codex sut)"; RC=$?
check "forged future/garbage state does not exclude a healthy reviewer" 3 '.reviewer' "kimi"

# ── 17 ── a COMMENTED review is never a convergence verdict.
# Only APPROVED at the current head clears a configured primary; COMMENTED is
# commentary. Counting it as clearing let a bot's walkthrough complete C3.
COMMENT_AT_HEAD="$(printf "$AT_HEAD" COMMENTED)"
OUT="$(T_REVIEWS="$COMMENT_AT_HEAD" T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "COMMENTED at head does NOT clear C3" 3 '.may_complete_c3' "false"

# ── 18 ── every configured primary must approve; one approval is not enough.
# A second bot that commented, or requested changes without moving
# reviewDecision, at the SAME head was invisible to the gate.
MIXED='[{"author":{"login":"coderabbitai"},"state":"APPROVED","commit":{"oid":"'"$HEAD_SHA"'"}},
        {"author":{"login":"qodo-merge"},"state":"CHANGES_REQUESTED","commit":{"oid":"'"$HEAD_SHA"'"}}]'
OUT="$(T_REVIEWS="$MIXED" T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "a non-approving primary at head blocks C3 even beside an approval" 3 '.may_complete_c3' "false"

# ── 19 ── the tamper check must not pass vacuously.
# With a hashing tool that prints nothing, both manifests were empty, `cmp`
# found them equal and the check reported `clean` — verifying nothing.
NOHASH="$SANDBOX/nohash"; mkdir -p "$NOHASH"
printf '#!/usr/bin/env bash\nexit 1\n' > "$NOHASH/shasum"; chmod +x "$NOHASH/shasum"
OUT="$(EXTRA_BIN="$NOHASH" T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
check "a failing hash tool aborts instead of reporting a clean tamper check" 1
ok_grep "the abort names the integrity check" 'manifest'

# ── 20 ── the reviewer env is an ALLOWLIST: unrelated credentials never reach it.
OUT="$(GH_TOKEN=dummy-not-a-secret T_GH_MARK="$SANDBOX/ghleak" T_REVIEWS='[]' \
       T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
if [ ! -e "$SANDBOX/ghleak" ]; then GOT=dropped; else GOT=leaked; fi
RC=0; OUT="{\"v\":\"$GOT\"}"
check "GH_TOKEN is not in the reviewer's allowlisted environment" 0 '.v' "dropped"

# ── 21 ── a CONCURRENT routed-review writing state is not an isolation breach
# when the kernel boundary is armed (the reviewer cannot write it, so any
# change came from outside). Out-of-sandbox writer lands mid-dispatch.
STATE="$SANDBOX/state/state-concurrent.json"; printf '{"bots":{}}' > "$STATE"
( sleep 1; printf '{"bots":{"qwen":{"broken_at":"2026-01-01T00:00:00Z"}}}' > "$STATE" ) &
OUT="$(T_SLEEP=3 T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
wait
if command -v sandbox-exec >/dev/null 2>&1 \
   && sandbox-exec -p '(version 1)(allow default)' /usr/bin/true 2>/dev/null; then
  check "kernel armed: a concurrent writer does not abort a valid review" 3 '.status' "reviewed"
  if grep -q qwen "$STATE"; then GOT=kept; else GOT=reverted; fi
  RC=0; OUT="{\"v\":\"$GOT\"}"
  check "kernel armed: the concurrent run's record survives" 0 '.v' "kept"
else
  printf '  \033[33mSKIP\033[0m  case 21 needs a working sandbox-exec on this host\n'
fi

# ── 22 ── without a kernel boundary a concurrent write is ambiguous: abort
# (fail-closed) but NEVER revert the other run's record.
STATE="$SANDBOX/state/state-concurrent2.json"; printf '{"bots":{}}' > "$STATE"
( sleep 1; printf '{"bots":{"qwen":{"broken_at":"2026-01-01T00:00:00Z"}}}' > "$STATE" ) &
OUT="$(EXTRA_BIN="$BROKEN_SBX" T_SLEEP=3 T_REVIEWS='[]' T_REVIEW_BODY="$BODY" \
       ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
wait
check "no kernel: a state change during dispatch aborts" 1 '.detail' "violated:state-file"
if grep -q qwen "$STATE"; then GOT=kept; else GOT=reverted; fi
RC=0; OUT="{\"v\":\"$GOT\"}"
check "no kernel: the concurrent record is not reverted" 0 '.v' "kept"

# ── 23 ── a symlinked state file is refused (no write-through to its target).
STATE="$SANDBOX/state/state-link.json"; printf '{"bots":{}}' > "$SANDBOX/linktarget.json"
ln -sf "$SANDBOX/linktarget.json" "$STATE"
OUT="$(STATE="$STATE" EXTRA_BIN="$GEM_BIN" RV=auto T_GEMINI_ERR="$ELIG" \
       T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=codex sut)"; RC=$?
if grep -q gemini "$SANDBOX/linktarget.json"; then GOT=written-through; else GOT=refused; fi
RC=0; OUT="{\"v\":\"$GOT\"}"
check "state writes never follow a symlink" 0 '.v' "refused"

# ── 24 ── the armed kernel profile really denies the state FILE — direct write,
# rename-over and unlink. This is what licenses skipping the compare in case 21.
if command -v sandbox-exec >/dev/null 2>&1 \
   && sandbox-exec -p '(version 1)(allow default)' /usr/bin/true 2>/dev/null; then
  STATE="$SANDBOX/state/state-armed.json"; printf '{"bots":{}}' > "$STATE"; cp "$STATE" "$SANDBOX/armed.orig"
  OUT="$(T_TAMPER_PATH="$STATE" T_TAMPER_JSON='{"bots":{"codex":{"broken_at":"2026-01-01T00:00:00Z"}}}' \
         T_TAMPER_MV="$STATE" T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
  check "armed: a hostile reviewer's write to the state file is denied" 3 '.isolation.read_only_enforcement' "os-sandboxed"
  if cmp -s "$STATE" "$SANDBOX/armed.orig"; then GOT=intact; else GOT=modified; fi
  RC=0; OUT="{\"v\":\"$GOT\"}"
  check "armed: write, rename-over and unlink of the state file all fail" 0 '.v' "intact"
else
  printf '  \033[33mSKIP\033[0m  case 24 needs a working sandbox-exec on this host\n'
fi

# ── 25 ── the state file's PARENT directory cannot be swapped unnoticed.
# The file itself is write-denied, but the directory entry holding it can be
# renamed and replaced (here by a symlink to a decoy carrying a forged entry).
# Skipping the content compare under an armed boundary must not skip this.
STATE="$SANDBOX/swap/state.json"; mkdir -p "$SANDBOX/swap"; printf '{"bots":{}}' > "$STATE"
OUT="$(T_DIR_SWAP="$STATE" \
       T_TAMPER_JSON='{"bots":{"codex":{"broken_at":"2026-01-01T00:00:00Z"}}}' \
       T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
# prevented (original state intact at its path) or detected — both fail-closed.
if [ "$(printf '%s' "$OUT" | jq -r '.detail' 2>/dev/null)" = "violated:state-file" ] \
   || { [ ! -L "$STATE" ] && [ "$(cat "$STATE" 2>/dev/null)" = '{"bots":{}}' ]; }; then GOT=closed; else GOT=bypassed; fi
RC=0; OUT="{\"v\":\"$GOT\"}"
check "a swapped state directory is prevented or aborts as isolation_violated" 0 '.v' "closed"

# ── 26 ── same for an ANCESTOR swapped for a real (non-symlink) tree whose
# resolved path is identical — only the directory's inode betrays it.
STATE="$SANDBOX/anc/inner/state.json"; mkdir -p "$SANDBOX/anc/inner"; printf '{"bots":{}}' > "$STATE"
OUT="$(T_ANC_SWAP="$STATE" T_TAMPER_JSON='{"bots":{"codex":{"broken_at":"2026-01-01T00:00:00Z"}}}' \
       T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
# prevented (original state intact at its path) or detected — both fail-closed.
if [ "$(printf '%s' "$OUT" | jq -r '.detail' 2>/dev/null)" = "violated:state-file" ] \
   || { [ ! -L "$STATE" ] && [ "$(cat "$STATE" 2>/dev/null)" = '{"bots":{}}' ]; }; then GOT=closed; else GOT=bypassed; fi
RC=0; OUT="{\"v\":\"$GOT\"}"
check "an ancestor swap is prevented or aborts as isolation_violated" 0 '.v' "closed"

# ── 27 ── (TOCTOU) rename the state dir away, write the REAL file through the
# new path, rename it back: same inode, same path — content changed.
STATE="$SANDBOX/rw/state.json"; mkdir -p "$SANDBOX/rw"; printf '{"bots":{}}' > "$STATE"; cp "$STATE" "$SANDBOX/rw.orig"
OUT="$(T_RENAME_WRITE="$STATE" T_TAMPER_JSON='{"bots":{"codex":{"broken_at":"2026-01-01T00:00:00Z"}}}' \
       T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=claude sut)"; RC=$?
if cmp -s "$STATE" "$SANDBOX/rw.orig"; then GOT=denied; else GOT=written; fi
# prevented (content intact) or detected (violated) are both acceptable;
# "written AND reviewed" is the bypass.
if [ "$GOT" = denied ] || [ "$(printf '%s' "$OUT" | jq -r '.detail' 2>/dev/null)" = "violated:state-file" ]; then GOT=closed; else GOT=bypassed; fi
RC=0; OUT="{\"v\":\"$GOT\"}"
check "rename-away / write / rename-back of the state dir is prevented or detected" 0 '.v' "closed"

# ── 28 ── (fail-open) a SYMLINKED state file is not used at all: the deny
# names the link, writes follow it, nothing vouches for the target. A forged
# but well-formed entry behind the link must therefore not affect the pick.
mkdir -p "$SANDBOX/sl"
printf '{"bots":{"kimi":{"broken_at":"%s"}}}' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$SANDBOX/sl-target.json"
ln -sf "$SANDBOX/sl-target.json" "$SANDBOX/sl/state.json"; STATE="$SANDBOX/sl/state.json"
OUT="$(EXTRA_BIN="$GEM_BIN" RV=auto T_GEMINI_ERR="$ELIG" \
       T_REVIEWS='[]' T_REVIEW_BODY="$BODY" ROUTED_REVIEW_CALLER=codex sut)"; RC=$?
check "a symlinked state file is ignored (its entries never exclude a reviewer)" 3 '.reviewer' "kimi"

echo
printf '  %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || { printf '  failed: %s\n' "${FAILED_NAMES[*]}"; exit 1; }
exit 0
