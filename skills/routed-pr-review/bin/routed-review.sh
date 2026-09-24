#!/usr/bin/env bash
# routed-pr-review — dispatch an independent, context-isolated PR review.
#
# Soul-name: Euthyna (εὔθυνα — the independent end-of-term audit every Athenian
# magistrate underwent, conducted by officials who were not the magistrate).
#
# WHY THIS EXISTS: when the configured review bots are quota-blocked, a PR can
# still be *reviewed* even though it may not yet be *merged*. This dispatches a
# reviewer whose context is isolated from the delegator BY CONSTRUCTION (a fresh
# OS process in a different vendor family), and reports a gate verdict that
# never overstates what a routed review satisfies.
#
# GATE CONTRACT (pr-review-protocol.md §4.1(e), verbatim intent):
#   A routed review satisfies EXACTLY ONE thing — the independent cross-brand
#   opinion (the *diversity* limb of C3). It NEVER satisfies a configured
#   primary's verdict. It can complete convergence only where no primary is
#   configured (positively evidenced `absent`) OR after every configured
#   primary has already cleared. While a primary is pending or quota-blocked,
#   this review INFORMS THE WORK and the PR still waits or escalates.
#
# Exit codes: 0 review produced · 1 error · 2 no reviewer available
#             3 review produced BUT a configured primary is still pending
set -uo pipefail

STATE_FILE="${ROUTED_REVIEW_STATE:-$HOME/.claude/state/ai-review-bots.json}"
PR=""; REPO=""; REVIEWER="auto"; POST=0; JSON=0; MAX_TURNS=12; TIMEOUT=600
NO_PRIMARY_ATTESTED=0
DIFF_CAP="${ROUTED_REVIEW_DIFF_CAP:-120000}"   # bytes of diff handed to the reviewer

die() { printf 'routed-review: %s\n' "$*" >&2; exit 1; }
log() { [ "$JSON" -eq 1 ] || printf '%s\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage: routed-review.sh --pr N [options]

  --pr N              PR number (required)
  --repo OWNER/NAME   default: current repo via gh
  --reviewer NAME     auto (default) | claude | codex | gemini | kimi | qwen
                      | grok | pi | copilot | jcode | opencode | kiro
  --post              post the review as a PR comment with the §4.1(b) stamp
  --json              machine-readable verdict on stdout
  --timeout SEC       per-reviewer wall clock (default 600; never below 500 —
                      a 280s cap once burned $4.7 for zero output)
  --max-turns N       agentic turn cap (default 12)
  --no-primary-configured
                      OPERATOR ATTESTATION that this repository has no configured
                      primary reviewer. Required before a routed review may
                      complete convergence on its own. The tool will NEVER infer
                      this: proving a negative from API silence is exactly the
                      misclassification §4.1(a) forbids, so it is attested, not
                      guessed. Without it, a silent PR resolves to
                      `absence_requires_operator_attestation` and holds.
USAGE
}

# `shift 2` FAILS (returns 1) when only one argument remains, and this script
# deliberately runs without `set -e` — so a value option passed last left `$#`
# unchanged and spun the loop forever. Proven: 2000 iterations with `$#` stuck
# at 1. Every value-bearing option therefore asserts its value exists first.
need_val() {   # $1=flag $2=candidate-value
  case "${2-}" in
    "" ) die "option $1 requires a value" ;;
    -* ) die "option $1 requires a value (got the flag '$2')" ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --pr)       need_val "$1" "${2-}"; PR="$2";       shift 2 ;;
    --repo)     need_val "$1" "${2-}"; REPO="$2";     shift 2 ;;
    --reviewer) need_val "$1" "${2-}"; REVIEWER="$2"; shift 2 ;;
    --timeout)  need_val "$1" "${2-}"; TIMEOUT="$2";  shift 2 ;;
    --max-turns) need_val "$1" "${2-}"; MAX_TURNS="$2"; shift 2 ;;
    --no-primary-configured) NO_PRIMARY_ATTESTED=1; shift ;;
    --post) POST=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

case "$PR" in ''|*[!0-9]*) die "--pr must be a positive integer (got '$PR')" ;; esac
case "$TIMEOUT" in ''|*[!0-9]*) die "--timeout must be an integer (got '$TIMEOUT')" ;; esac
case "$MAX_TURNS" in ''|*[!0-9]*) die "--max-turns must be an integer (got '$MAX_TURNS')" ;; esac

[ -n "$PR" ] || { usage >&2; die "--pr is required"; }
command -v gh  >/dev/null 2>&1 || die "gh CLI not found — required to read the PR"
command -v jq  >/dev/null 2>&1 || die "jq not found — required to parse gh JSON"
# `timeout` is used on every reviewer dispatch (6 call sites) and on the sandbox
# probes; stock macOS ships without it. Unchecked, its absence surfaced as an
# opaque per-harness failure instead of a one-line diagnostic. Found by a routed
# kimi review on #414 (cycle 4) — gh/jq/tar were checked, this one was not.
command -v timeout >/dev/null 2>&1 \
  || die "timeout not found — required to bound every reviewer dispatch (brew install coreutils, or alias gtimeout)"
[ "$TIMEOUT" -ge 500 ] 2>/dev/null || { log "[warn] raising --timeout $TIMEOUT -> 500 (measured floor)"; TIMEOUT=500; }

[ -n "$REPO" ] || REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" \
  || die "could not resolve repo; pass --repo OWNER/NAME"

# ---------------------------------------------------------------- Phase A: PR
log "[A] resolving $REPO#$PR"
PR_JSON="$(gh pr view "$PR" --repo "$REPO" \
  --json number,title,headRefOid,headRefName,baseRefName,url,author,mergeStateStatus,reviewDecision,latestReviews,comments 2>/dev/null)" \
  || die "cannot read $REPO#$PR"
HEAD_SHA="$(printf '%s' "$PR_JSON" | jq -r .headRefOid)"
[ -n "$HEAD_SHA" ] && [ "$HEAD_SHA" != "null" ] || die "no headRefOid for $REPO#$PR"
PR_TITLE="$(printf '%s' "$PR_JSON" | jq -r .title)"
PR_URL="$(printf '%s' "$PR_JSON" | jq -r .url)"
log "    head=$HEAD_SHA  \"$PR_TITLE\""

# ------------------------------------------- Phase B: §4.1(a) primary probe
# Classify each CONFIGURED REVIEWER (a known bot) that has spoken on this PR.
#
# ⛔ Only KNOWN_BOTS count as primaries. A HUMAN review must never land in
# CLEARED: a human `APPROVED`/`COMMENTED` would otherwise flip the state to
# `all_cleared_for_head` while a configured bot is still pending — and on a
# self-authored PR that is the author clearing their own gate. Humans are
# reported separately, for information only.
KNOWN_BOTS='coderabbitai|qodo|copilot-pull-request-reviewer|github-advanced-security|amazon-q-developer|chatgpt-codex-connector|claude|snyk'
PRIMARY_STATE="$(printf '%s' "$PR_JSON" | jq -r --arg head "$HEAD_SHA" '
  ([.latestReviews[]? | select(.author.login | test("'"$KNOWN_BOTS"'"; "i"))
     | {who: .author.login, sha: (.commit.oid // ""), verdict: .state}]) as $rv
  | ([.latestReviews[]? | select(.author.login | test("'"$KNOWN_BOTS"'"; "i") | not)
     | .author.login]) as $humans
  | ([.comments[]? | select(.author.login | test("'"$KNOWN_BOTS"'"; "i")) | {who: .author.login, body: (.body[0:400])}]) as $cm
  | {reviews: $rv, human_reviews: ($humans | unique), bot_comments: $cm, head: $head}')"

# quota / plan signals, per review-bot-quota-recovery taxonomy
QUOTA_HITS="$(printf '%s' "$PRIMARY_STATE" | jq -r '
  [.bot_comments[]? | select(.body | test("rate limit|rate-limited|Review limit reached|next review|paused for this user|requires Pro|quota|usage limit"; "i")) | .who] | unique | join(",")')"
# ⛔ `.head` does NOT exist inside a `.reviews[]` element — it is a SIBLING of the
# array, so `.sha != .head` reduced to `.sha != null` = always true. Every review
# was classified stale, `STALE_OR_PENDING` never emptied, and the
# `all_cleared_for_head` branch (the only path to `exit 0`) was dead code.
# Found by a routed kimi review of this very tool on PR #414; reproduced by
# executing the shipped expression. Bind the head explicitly, like CLEARED does.
STALE_OR_PENDING="$(printf '%s' "$PRIMARY_STATE" | jq -r --arg head "$HEAD_SHA" '
  [.reviews[]? | select(.sha != $head and .sha != "") | .who] | unique | join(",")')"
CLEARED="$(printf '%s' "$PRIMARY_STATE" | jq -r --arg head "$HEAD_SHA" '
  [.reviews[]? | select(.sha == $head and (.verdict == "APPROVED" or .verdict == "COMMENTED")) | .who] | unique | join(",")')"
HUMAN_REVIEWS="$(printf '%s' "$PRIMARY_STATE" | jq -r '.human_reviews | join(",")')"
CHANGES_REQ="$(printf '%s' "$PR_JSON" | jq -r 'if .reviewDecision == "CHANGES_REQUESTED" then "yes" else "no" end')"

log "[B] primaries(bots only) — cleared-for-head:[${CLEARED:--}] stale/earlier-head:[${STALE_OR_PENDING:--}] quota-signalled:[${QUOTA_HITS:--}] changes_requested:$CHANGES_REQ"
log "    humans reviewed (informational, never a primary): [${HUMAN_REVIEWS:--}]"

# ------------------------------------------- Phase C: pick isolated reviewer
# Cross-family preference: never route to the SAME vendor family as the caller
# (same-brand re-runs share blind spots — §4.1(b)). The caller declares itself
# via ROUTED_REVIEW_CALLER; unset = no exclusion.
CALLER="${ROUTED_REVIEW_CALLER:-}"
declare -a FAMILY_ORDER=(codex gemini kimi qwen grok claude copilot pi jcode opencode kiro)

expired() {  # $1=bot ; honours ai-code-review-bots-rotation.md §2 state file
  [ -f "$STATE_FILE" ] || return 1
  local now limited retry
  now="$(date +%s)"
  limited="$(jq -r --arg b "$1" '.bots[$b].last_limited_at // empty' "$STATE_FILE" 2>/dev/null)"
  [ -n "$limited" ] || return 1
  retry="$(jq -r --arg b "$1" '.bots[$b].retry_after_sec // 3600' "$STATE_FILE" 2>/dev/null)"
  local reset; reset=$(( $(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${limited%%.*}" +%s 2>/dev/null || echo 0) + retry ))
  [ "$now" -lt "$reset" ]
}

# ⛔ Validate an EXPLICIT --reviewer here, in the main shell — NOT inside
# pick_reviewer(). pick_reviewer runs in a command substitution, so a `die`
# there exits only the subshell; the `|| { … exit 2 }` below then swallows it
# and re-labels a usage error as `status:no_reviewer`. The stderr reason still
# printed, but a JSON consumer was told the wrong cause. Caught on the FIRST
# run of tests/contract.sh (case 5) — the composition class that four cycles
# of line-level checking never surfaced.
if [ "$REVIEWER" != "auto" ]; then
  command -v "$REVIEWER" >/dev/null 2>&1 || die "requested reviewer '$REVIEWER' not on PATH"
  # An explicit --reviewer must NOT bypass verifier != generator. Without this,
  # `ROUTED_REVIEW_CALLER=codex --reviewer codex` performs the correlated
  # same-family review the skill forbids, and the emitted comment would still
  # account it as "C3 diversity satisfied" — fabricated diversity evidence,
  # the §4.1(e) failure this tool exists to prevent.
  if [ -n "$CALLER" ] && [ "$REVIEWER" = "$CALLER" ]; then
    die "refusing --reviewer '$REVIEWER': identical to ROUTED_REVIEW_CALLER — that is a correlated verifier, not an independent one. Pick another family, or unset the caller only if you can justify it."
  fi
fi

pick_reviewer() {
  # Explicit reviewer already validated above; just hand it back.
  if [ "$REVIEWER" != "auto" ]; then printf '%s' "$REVIEWER"; return 0; fi
  local h
  for h in "${FAMILY_ORDER[@]}"; do
    [ "$h" = "$CALLER" ] && continue                      # verifier != generator
    command -v "$h" >/dev/null 2>&1 || continue
    expired "$h" && { log "    skip $h (expired per state file)"; continue; }
    printf '%s' "$h"; return 0
  done
  return 1
}

CHOSEN="$(pick_reviewer)" || {
  # §5 of ai-code-review-bots-rotation: never fabricate an empty review.
  log "[C] all-reviewers-unavailable — emitting honest diagnostic, NOT a review"
  [ "$JSON" -eq 1 ] && printf '{"status":"no_reviewer","repo":"%s","pr":%s,"head":"%s","diversity_limb":"unsatisfied","primary_verdict":"unknown","may_complete_c3":false}\n' "$REPO" "$PR" "$HEAD_SHA"
  exit 2
}
log "[C] reviewer=$CHOSEN (caller=${CALLER:-unset}, isolation=fresh-process)"

# ------------------------------------------- Phase D: isolated read-only run
WORK="$(mktemp -d "${TMPDIR:-/tmp}/routed-review.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DIFF_F="$WORK/diff.patch"; PROMPT_F="$WORK/prompt.md"; OUT_F="$WORK/review.txt"

gh pr diff "$PR" --repo "$REPO" > "$DIFF_F" 2>/dev/null || die "cannot fetch diff"
DIFF_BYTES="$(wc -c < "$DIFF_F" | tr -d ' ')"
if [ "$DIFF_BYTES" -gt "$DIFF_CAP" ]; then
  log "    diff ${DIFF_BYTES}B > cap ${DIFF_CAP}B — truncating (declared in output, never hidden)"
  head -c "$DIFF_CAP" "$DIFF_F" > "$DIFF_F.cut" && mv "$DIFF_F.cut" "$DIFF_F"
  TRUNCATED="yes"
else TRUNCATED="no"; fi

# REFUTE-first prompt. The reviewer is rewarded for BREAKING the change.
{
  cat <<PROMPT
You are an independent reviewer with NO prior context on this change. You did
not write it and you have never seen this conversation. Your job is to REFUTE
it, not to approve it.

Repository: $REPO
Pull request: #$PR — $PR_TITLE
Head commit under review: $HEAD_SHA
Diff truncated: $TRUNCATED

Rules:
- Judge ONLY what the diff and the repository show. Never assume intent.
- Classify every finding: severity [blocking|major|minor|nit] and class
  [correctness | security | silent-failure | governance | test-gap
   | false-claim | craft-defect].
- A finding MUST cite file:line and say why it matters, not merely that it
  differs from your taste.
- If the PR body or commit message CLAIMS something the diff does not support,
  that is a false-claim finding and it is at least major.
- Verify claimed counts and paths yourself; a fabricated path is blocking.
- If you cannot verify something, say "could not verify" — never guess.
- Emit findings even if incomplete: an incomplete review beats an absent one.

Close with exactly one line:
VERDICT: PASS | REQUEST_CHANGES  — <one sentence>

--- BEGIN DIFF ---
PROMPT
  cat "$DIFF_F"
  printf '\n--- END DIFF ---\n'
} > "$PROMPT_F"

# ---- Isolation enforcement ---------------------------------------------------
# THREE enforcement classes, named for what they actually guarantee:
#
#   vendor        the CLI itself confines writes (--sandbox read-only /
#                 --allowedTools). Trust the vendor, not us.
#   os-sandboxed  a KERNEL boundary (macOS `sandbox-exec`) denies file-write to
#                 the export AND to the live repository, plus the disposable
#                 chmod'd export and a post-run manifest check.
#   os-perms-only NO kernel boundary is available on this host. The export and
#                 chmod still reduce blast radius and the manifest still DETECTS
#                 writes — but `chmod a-w` does NOT confine a process running as
#                 the file owner: it can chmod u+w and rewrite, or write
#                 anywhere else it likes. This class is honestly weaker and says
#                 so in the emitted evidence. It defends against an
#                 INCIDENTALLY-writing reviewer, never a determined one.
#
# The distinction exists because an independent review found the original
# `os` class claiming a boundary that permissions cannot provide.
sandbox_class() {
  case "$1" in
    claude|codex) printf 'vendor' ;;   # --allowedTools / --sandbox read-only — the flag IS passed below
    # grok exposes --allow-rule but this dispatcher does not pass it, so it is
    # NOT vendor-enforced here. Claiming `vendor` on an unpassed flag is the
    # same false-claim class this tool is built to catch. It stays `os` until
    # the flag is actually passed AND proven in a recorded run.
    *)            printf 'os'     ;;
  esac
}

EXPORT_DIR=""
cleanup() {
  [ -n "$EXPORT_DIR" ] && [ -d "$EXPORT_DIR" ] && chmod -R u+w "$EXPORT_DIR" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

build_readonly_export() {
  command -v tar >/dev/null 2>&1 || die "tar not found — required for read-only export"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "not inside a git work tree — cannot build a read-only export"
  git cat-file -e "$HEAD_SHA^{commit}" 2>/dev/null \
    || git fetch origin "pull/$PR/head" --quiet 2>/dev/null \
    || die "head $HEAD_SHA not fetchable — cannot build a read-only export"
  git cat-file -e "$HEAD_SHA^{commit}" 2>/dev/null \
    || die "head $HEAD_SHA still absent after fetch"
  EXPORT_DIR="$WORK/tree"
  mkdir -p "$EXPORT_DIR"
  git archive "$HEAD_SHA" | tar -x -C "$EXPORT_DIR" \
    || die "git archive failed — cannot build a read-only export"
  # manifest BEFORE locking, so the check covers content, not just mtimes
  ( cd "$EXPORT_DIR" && find . -type f -print0 | sort -z \
      | xargs -0 shasum -a 256 2>/dev/null ) > "$WORK/manifest.before"
  chmod -R a-w "$EXPORT_DIR" 2>/dev/null
  log "    export: $(wc -l < "$WORK/manifest.before" | tr -d ' ') files, chmod a-w, no .git"
}

# A real kernel boundary where the host offers one. macOS ships `sandbox-exec`
# (deprecated but present and effective for file-write denial). The profile is
# deliberately `allow default` + targeted denies: a blanket write-deny breaks
# every CLI's own cache/config writes, so we deny exactly the two trees whose
# integrity we are claiming — the export and the live repository.
SANDBOX_PROFILE=""
build_sandbox_profile() {   # 0 = a kernel boundary is available and armed
  # ⛔ Build into a LOCAL, and publish the global only on success. The earlier
  # version assigned $SANDBOX_PROFILE up-front, so a failing probe returned 1
  # while LEAVING the global set — and `arm_sandbox_prefix` (which trusts only
  # non-emptiness) then wrapped every reviewer dispatch in a profile that had
  # just been PROVEN not to work. The result was an opaque per-harness failure:
  # the same fail-through class the two-step probe below was added to close,
  # one level up from it. Caught by tests/contract.sh case 8.
  SANDBOX_PROFILE=""
  command -v sandbox-exec >/dev/null 2>&1 || return 1
  local repo_root prof
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD")"
  prof="$WORK/deny-writes.sb"
  {
    printf '(version 1)\n(allow default)\n'
    printf '(deny file-write* (subpath "%s"))\n' "$(cd "$EXPORT_DIR" && pwd -P)"
    printf '(deny file-write* (subpath "%s"))\n' "$(cd "$repo_root" && pwd -P)"
  } > "$prof" || return 1
  # Two-step probe. A single step could NOT distinguish "sandbox-exec ran and
  # denied the write" from "sandbox-exec never ran at all" (invalid profile,
  # unsupported OS, SIP policy): both leave no probe file, both made the old
  # `if` false, and the fallthrough then returned 0 = ARMED. Measured:
  # `sandbox-exec -f /nonexistent.sb /bin/echo x` exits 65 — a failure to
  # confine was indistinguishable from a successful denial. Found by a routed
  # kimi review of this tool on #414 (cycle 4).
  # Step 1 — liveness: the profile must run a harmless ALLOWED command.
  sandbox-exec -f "$prof" /usr/bin/true >/dev/null 2>&1 || return 1
  # Step 2 — denial: the write must fail AND leave no file.
  sandbox-exec -f "$prof" /bin/sh -c \
    "echo probe > '$EXPORT_DIR/.sandbox-probe' 2>/dev/null" >/dev/null 2>&1
  if [ -e "$EXPORT_DIR/.sandbox-probe" ]; then
    rm -f "$EXPORT_DIR/.sandbox-probe" 2>/dev/null
    return 1   # the write LANDED => not a boundary
  fi
  SANDBOX_PROFILE="$prof"   # publish ONLY after both steps proved it
  return 0
}

# The manifest only ever covered the export. A reviewer that writes ELSEWHERE —
# most importantly into the live repository — was invisible to it. Capture the
# live tree's state too, so an escape is detected rather than assumed away.
LIVE_BEFORE=""
snapshot_live_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  LIVE_BEFORE="$(git status --porcelain 2>/dev/null | shasum -a 256 | cut -d' ' -f1)"
}
verify_live_repo_untouched() {
  [ -n "$LIVE_BEFORE" ] || return 0
  local now; now="$(git status --porcelain 2>/dev/null | shasum -a 256 | cut -d' ' -f1)"
  [ "$now" = "$LIVE_BEFORE" ] && return 0
  log "[!] live-repo check FAILED — the reviewer mutated the working tree outside its export"
  return 1
}
verify_export_untouched() {
  [ -n "$EXPORT_DIR" ] || return 0
  chmod -R u+rX "$EXPORT_DIR" 2>/dev/null
  ( cd "$EXPORT_DIR" && find . -type f -print0 | sort -z \
      | xargs -0 shasum -a 256 2>/dev/null ) > "$WORK/manifest.after"
  if cmp -s "$WORK/manifest.before" "$WORK/manifest.after"; then
    log "    tamper-check: export unmodified (manifest identical)"
    return 0
  fi
  log "[!] tamper-check FAILED — reviewer wrote to its read-only export:"
  diff "$WORK/manifest.before" "$WORK/manifest.after" 2>/dev/null | head -10 | sed 's/^/      /' >&2
  return 1
}

# Invocation table. `evidence` marks how the shape was established:
#   proven   = executed successfully in a recorded prior run
#   measured = flag confirmed present in this host's --help this build
# Every os-class entry runs with cwd = the locked export, never the live tree,
# and — when a kernel boundary is available — under `sandbox-exec`.
# `SBX` is the prefix array: empty for vendor-confined CLIs (their own sandbox
# would conflict), populated for os-class ones.
declare -a SBX=()
# ⛔ Every ${SBX[@]} below uses the ${SBX[@]+"${SBX[@]}"} idiom: under `set -u`
# bash 3.2 (the macOS default) treats expanding an EMPTY array as an unbound
# variable and aborts. SBX is empty exactly when no kernel boundary armed —
# i.e. the whole documented `os-perms-only` fallback class crashed on every
# dispatch, on every host without a working sandbox-exec (all of Linux). It
# never showed here because this host arms. Caught by tests/contract.sh case 8.
arm_sandbox_prefix() {
  SBX=()
  [ -n "$SANDBOX_PROFILE" ] || return 0
  SBX=(sandbox-exec -f "$SANDBOX_PROFILE")
}

run_reviewer() {
  local h="$1" rc=0 dir="$2"
  case "$h" in
    claude)   # proven: cross-harness-red-team (claude-code 2.1.235)
      # ⛔ `--add-dir` GRANTS access to a directory; it does NOT move the working
      # directory. Without the `cd`, Read/Grep/Glob open the CALLER's $PWD first —
      # the very checkout that just failed `cwd_is_head` — while the comment stamps
      # `Head reviewed: $HEAD_SHA`. Both tamper checks stayed clean because nothing
      # was written, so the wrong-tree read was invisible. This is the exact defect
      # the codex branch avoids with `--cd`. Found by a routed kimi review on #414.
      ( cd "$dir" && timeout "$TIMEOUT" claude -p "$(cat "$PROMPT_F")" \
        --max-turns "$MAX_TURNS" \
        --allowedTools "Read" "Grep" "Glob" \
        --add-dir "$dir" ) > "$OUT_F" 2>"$WORK/err" || rc=$? ;;
    codex)    # proven: ai-code-review-bots-rotation §1 (council CRITIC)
      timeout "$TIMEOUT" codex exec --sandbox read-only --cd "$dir" "$(cat "$PROMPT_F")" \
        > "$OUT_F" 2>"$WORK/err" || rc=$? ;;
    grok)     # measured: -p non-interactive. --allow-rule NOT passed => os-class.
      ( cd "$dir" && timeout "$TIMEOUT" ${SBX[@]+"${SBX[@]}"} grok -p "$(cat "$PROMPT_F")" ) \
        > "$OUT_F" 2>"$WORK/err" || rc=$? ;;
    gemini|qwen|kimi|copilot|pi)   # measured: -p/--prompt non-interactive
      ( cd "$dir" && timeout "$TIMEOUT" ${SBX[@]+"${SBX[@]}"} "$h" -p "$(cat "$PROMPT_F")" ) \
        > "$OUT_F" 2>"$WORK/err" || rc=$? ;;
    jcode|opencode)                # measured: `run` subcommand
      ( cd "$dir" && timeout "$TIMEOUT" ${SBX[@]+"${SBX[@]}"} "$h" run "$(cat "$PROMPT_F")" ) \
        > "$OUT_F" 2>"$WORK/err" || rc=$? ;;
    kiro)                          # measured: `chat` subcommand
      ( cd "$dir" && timeout "$TIMEOUT" ${SBX[@]+"${SBX[@]}"} kiro chat "$(cat "$PROMPT_F")" ) \
        > "$OUT_F" 2>"$WORK/err" || rc=$? ;;
    *) die "no invocation shape for '$h' — add one to run_reviewer() with its evidence class" ;;
  esac
  return $rc
}

ENFORCEMENT="$(sandbox_class "$CHOSEN")"
# ⛔ The comment will claim `Head reviewed: $HEAD_SHA`. That claim is only true
# if the tree the reviewer actually read IS that commit. `--repo` is arbitrary,
# so `$PWD` may be an unrelated checkout — the reviewer would then inspect other
# files while the stamp asserts this SHA. Never trust cwd: prove it, else export.
cwd_is_head() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  [ "$(git rev-parse HEAD 2>/dev/null)" = "$HEAD_SHA" ] || return 1
  # a dirty tree is not that commit either
  [ -z "$(git status --porcelain 2>/dev/null)" ] || return 1
}

snapshot_live_repo

if [ "$ENFORCEMENT" = "os" ]; then
  log "[D] $CHOSEN has no vendor read-only flag -> enforcing outside the CLI"
  build_readonly_export
  SAFE_DIR="$EXPORT_DIR"
  if build_sandbox_profile; then
    arm_sandbox_prefix
    ENFORCEMENT="os-sandboxed"
    log "    kernel boundary ARMED (sandbox-exec: file-write denied on export + repo, probe verified)"
  else
    ENFORCEMENT="os-perms-only"
    log "    [warn] no kernel boundary on this host -> os-perms-only: writes are DETECTED, not PREVENTED"
  fi
elif cwd_is_head; then
  SAFE_DIR="$PWD"
  log "[D] cwd proven at $HEAD_SHA and clean -> vendor sandbox over the live tree"
else
  # vendor-sandboxed but cwd is NOT the reviewed commit: export anyway so the
  # `Head reviewed:` stamp stays true. Enforcement is then belt-and-braces.
  log "[D] cwd is NOT $HEAD_SHA (or is dirty) -> exporting so the head stamp stays true"
  build_readonly_export
  SAFE_DIR="$EXPORT_DIR"
  ENFORCEMENT="vendor+os"
fi

log "[D] dispatching $CHOSEN (timeout=${TIMEOUT}s, enforcement=$ENFORCEMENT, cwd=$SAFE_DIR)"
RC=0; run_reviewer "$CHOSEN" "$SAFE_DIR" || RC=$?

# Two independent tamper checks. The export manifest catches writes INSIDE the
# sandboxed tree; the live-repo hash catches an ESCAPE — a reviewer writing to
# the working tree it was never given. The second exists because the first,
# alone, could not see outside its own directory.
TAMPER="n/a"
case "$ENFORCEMENT" in
  *os*)
    TAMPER="clean"
    verify_export_untouched   || TAMPER="violated:export"
    verify_live_repo_untouched || TAMPER="violated:live-repo"
    ;;
  *) verify_live_repo_untouched || TAMPER="violated:live-repo" ;;
esac
if [ "${TAMPER#violated}" != "$TAMPER" ]; then
  log "[D] ABORT ($TAMPER): isolation violated — no review will be stamped or reported as valid"
  [ "$JSON" -eq 1 ] && printf '{"status":"isolation_violated","detail":"%s","reviewer":"%s","diversity_limb":"unsatisfied","may_complete_c3":false}\n' "$TAMPER" "$CHOSEN"
  exit 1
fi
REVIEW_BYTES="$(wc -c < "$OUT_F" 2>/dev/null | tr -d ' ' || echo 0)"

if [ "$REVIEW_BYTES" -lt 40 ]; then
  # No substantive content => there is NO review. Never stamp an empty claim.
  log "[D] reviewer produced ${REVIEW_BYTES}B (rc=$RC) — treating as NO REVIEW (anti-theater)"
  [ -s "$WORK/err" ] && sed 's/^/    stderr: /' "$WORK/err" | head -5 >&2
  # record the limit so rotation skips it next time
  if [ -w "$(dirname "$STATE_FILE")" ] 2>/dev/null || mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null; then
    [ -f "$STATE_FILE" ] || printf '{"bots":{}}' > "$STATE_FILE"
    tmp="$(mktemp)"; jq --arg b "$CHOSEN" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '.bots[$b].last_limited_at=$t | .bots[$b].retry_after_sec=(.bots[$b].retry_after_sec // 3600) | .bots[$b].consecutive_limits=((.bots[$b].consecutive_limits // 0)+1)' \
      "$STATE_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$STATE_FILE" || rm -f "$tmp"
  fi
  [ "$JSON" -eq 1 ] && printf '{"status":"empty_review","reviewer":"%s","rc":%s,"diversity_limb":"unsatisfied","may_complete_c3":false}\n' "$CHOSEN" "$RC"
  exit 2
fi

VERDICT_LINE="$(grep -aoE 'VERDICT: *(PASS|REQUEST_CHANGES).*' "$OUT_F" | tail -1)"
[ -n "$VERDICT_LINE" ] || VERDICT_LINE="VERDICT: (not emitted by reviewer — read the body)"

# ------------------------------------------- Phase E: gate verdict + comment
# The ONLY honest computation of what this review licenses.
#
# ⛔ `absent` is NEVER inferred. Two rounds of review killed two successive
# attempts to infer it:
#   (1) `bot_comments == 0` on THIS PR — pure silence, the exact
#       misclassification §4.1(a) names ("inferring absence from *silence*").
#   (2) a single unpaginated `issues/comments?per_page=100` page — which also
#       never sees review submissions, so a bot that spoke outside that page is
#       missed and the conclusion is again unsupported.
# The lesson is not "paginate harder": proving a NEGATIVE ("no primary is
# configured anywhere") is not something this tool can establish cheaply or
# reliably from the API. So it does not try. Absence is an OPERATOR ATTESTATION
# (`--no-primary-configured`), and without it the tool HOLDS. Fail-closed by
# construction beats a smarter guess.
#
# The repo-wide probe survives only as CORROBORATION: it can CONTRADICT an
# attestation (a bot demonstrably spoke ⇒ the attestation is wrong, and wrong
# loudly), but it can never grant one.
repo_reviewer_seen() {   # 0 = a known bot has demonstrably spoken · 1 = none seen · 2 = probe failed
  local out
  out="$(gh api --paginate "repos/$REPO/issues/comments?per_page=100" \
          --jq '[.[] | select(.user.login | test("'"$KNOWN_BOTS"'"; "i")) | .user.login]' 2>/dev/null \
        | jq -s 'add // [] | unique | length' 2>/dev/null)" || return 2
  [ -n "$out" ] || return 2
  [ "$out" -gt 0 ] 2>/dev/null && return 0 || return 1
}

MAY_COMPLETE_C3="false"; PRIMARY_STATUS="pending_or_unknown"
if [ "$CHANGES_REQ" = "yes" ]; then
  PRIMARY_STATUS="changes_requested"      # §4.1(e): routing never dismisses this
elif [ -z "$STALE_OR_PENDING" ] && [ -z "$QUOTA_HITS" ] && [ -n "$CLEARED" ]; then
  # CLEARED is bot-only (phase B); a human approval can never land here.
  PRIMARY_STATUS="all_cleared_for_head"; MAY_COMPLETE_C3="true"
elif [ -z "$CLEARED" ] && [ -z "$STALE_OR_PENDING" ] && [ -z "$QUOTA_HITS" ] \
  && [ "$(printf '%s' "$PRIMARY_STATE" | jq -r '.bot_comments | length')" = "0" ]; then
  if [ "$NO_PRIMARY_ATTESTED" -eq 1 ]; then
    repo_reviewer_seen; probe_rc=$?
    if [ "$probe_rc" -eq 0 ]; then
      # the attestation is contradicted by evidence — refuse it, loudly
      PRIMARY_STATUS="attestation_contradicted_bot_has_spoken_in_repo"
      log "[!] --no-primary-configured was passed, but a known reviewer HAS spoken in this repo."
      log "[!] Refusing the attestation. This PR is PENDING, not absent."
    else
      PRIMARY_STATUS="none_configured_operator_attested"; MAY_COMPLETE_C3="true"
      [ "$probe_rc" -eq 2 ] && log "    note: corroboration probe failed; resting on the attestation alone"
    fi
  else
    PRIMARY_STATUS="absence_requires_operator_attestation"
    log "    silent PR + no attestation -> holding (pass --no-primary-configured only if true)"
  fi
fi

log "[E] diversity_limb=satisfied  primary=$PRIMARY_STATUS  may_complete_c3=$MAY_COMPLETE_C3"

COMMENT_F="$WORK/comment.md"
{
  printf '## Routed review — `%s`\n\n' "$CHOSEN"
  printf 'Reviewed-By: %s (routed, §4.1(b))\n' "$CHOSEN"
  printf 'Head reviewed: `%s`\n' "$HEAD_SHA"
  printf 'Context isolation: fresh OS process, no delegator history.\n'
  printf 'Read-only enforcement: `%s` (%s)\n' "$ENFORCEMENT" \
    "$([ "$ENFORCEMENT" = vendor ] && printf 'CLI sandbox/tool-allowlist' || printf 'disposable git-archive export, chmod a-w, no .git')"
  printf 'Post-run tamper check: `%s`\n' "$TAMPER"
  printf 'Diff truncated: %s\n\n' "$TRUNCATED"
  printf '%s\n\n' "$VERDICT_LINE"
  printf '<details><summary>Full reviewer output (%s bytes)</summary>\n\n```\n' "$REVIEW_BYTES"
  cat "$OUT_F"
  printf '\n```\n</details>\n\n'
  printf -- '---\n**Gate accounting (§4.1(e)) — what this does and does NOT satisfy**\n\n'
  printf '| limb | state |\n|---|---|\n'
  printf '| C3 diversity (independent cross-brand opinion) | satisfied |\n'
  printf '| Configured primary verdict | `%s` |\n' "$PRIMARY_STATUS"
  printf '| May complete convergence on its own | `%s` |\n\n' "$MAY_COMPLETE_C3"
  if [ "$MAY_COMPLETE_C3" != "true" ]; then
    printf '> This routed review **informs the work**; it is not the primary reviewer'"'"'s verdict.\n'
    printf '> The PR waits for the primary or escalates for an explicit operator override.\n'
  fi
} > "$COMMENT_F"

if [ "$POST" -eq 1 ]; then
  # ⛔ The scan is MANDATORY, not best-effort. The comment embeds the reviewer's
  # verbatim output, which read a whole repository tree — a plausible secret
  # carrier. Silently skipping the scan when gitleaks is absent, and posting
  # anyway, made the documented guarantee false and the leak real. A PR comment
  # is a paste-anywhere surface; secrets are absolute, so no scanner ⇒ no post.
  command -v gitleaks >/dev/null 2>&1 \
    || die "gitleaks not installed — refusing to post (the pre-post secret scan is mandatory, not best-effort). Install gitleaks, or drop --post and inspect the review on stdout."
  gitleaks detect --no-git --source="$COMMENT_F" --no-banner >/dev/null 2>&1 \
    || die "gitleaks flagged the review body — comment NOT posted (secrets are absolute)"
  gh pr comment "$PR" --repo "$REPO" --body-file "$COMMENT_F" >/dev/null \
    && log "[E] posted to $PR_URL" || die "failed to post comment"
fi

if [ "$JSON" -eq 1 ]; then
  jq -n --arg repo "$REPO" --arg pr "$PR" --arg head "$HEAD_SHA" --arg rv "$CHOSEN" \
        --arg verdict "$VERDICT_LINE" --arg ps "$PRIMARY_STATUS" --arg c3 "$MAY_COMPLETE_C3" \
        --arg trunc "$TRUNCATED" --arg enf "$ENFORCEMENT" --arg tamper "$TAMPER" \
        --argjson bytes "$REVIEW_BYTES" \
    '{status:"reviewed",repo:$repo,pr:($pr|tonumber),head:$head,reviewer:$rv,
      isolation:{mode:"fresh-process",read_only_enforcement:$enf,tamper_check:$tamper},
      review_bytes:$bytes,diff_truncated:$trunc,
      verdict:$verdict,diversity_limb:"satisfied",primary_verdict:$ps,
      may_complete_c3:($c3=="true")}'
else
  cat "$COMMENT_F"
fi

[ "$MAY_COMPLETE_C3" = "true" ] || exit 3
exit 0
