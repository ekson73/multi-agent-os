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
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --pr) PR="${2:-}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --reviewer) REVIEWER="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --max-turns) MAX_TURNS="${2:-}"; shift 2 ;;
    --post) POST=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

[ -n "$PR" ] || { usage >&2; die "--pr is required"; }
command -v gh  >/dev/null 2>&1 || die "gh CLI not found — required to read the PR"
command -v jq  >/dev/null 2>&1 || die "jq not found — required to parse gh JSON"
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
# Classify each reviewer that has EVER spoken on this repo. Absence is proven
# by positive evidence only — never inferred from silence (the §4.1 defect).
KNOWN_BOTS='coderabbitai|qodo|copilot-pull-request-reviewer|github-advanced-security|amazon-q-developer|chatgpt-codex-connector|claude|snyk'
PRIMARY_STATE="$(printf '%s' "$PR_JSON" | jq -r --arg head "$HEAD_SHA" '
  ([.latestReviews[]? | {who: .author.login, sha: (.commit.oid // ""), verdict: .state}]) as $rv
  | ([.comments[]? | select(.author.login | test("'"$KNOWN_BOTS"'"; "i")) | {who: .author.login, body: (.body[0:400])}]) as $cm
  | {reviews: $rv, bot_comments: $cm, head: $head}')"

# quota / plan signals, per review-bot-quota-recovery taxonomy
QUOTA_HITS="$(printf '%s' "$PRIMARY_STATE" | jq -r '
  [.bot_comments[]? | select(.body | test("rate limit|rate-limited|Review limit reached|next review|paused for this user|requires Pro|quota|usage limit"; "i")) | .who] | unique | join(",")')"
STALE_OR_PENDING="$(printf '%s' "$PRIMARY_STATE" | jq -r '
  [.reviews[]? | select(.sha != .head and .sha != "") | .who] | unique | join(",")')"
CLEARED="$(printf '%s' "$PRIMARY_STATE" | jq -r --arg head "$HEAD_SHA" '
  [.reviews[]? | select(.sha == $head and (.verdict == "APPROVED" or .verdict == "COMMENTED")) | .who] | unique | join(",")')"
CHANGES_REQ="$(printf '%s' "$PR_JSON" | jq -r 'if .reviewDecision == "CHANGES_REQUESTED" then "yes" else "no" end')"

log "[B] primaries — cleared-for-head:[${CLEARED:--}] stale/earlier-head:[${STALE_OR_PENDING:--}] quota-signalled:[${QUOTA_HITS:--}] changes_requested:$CHANGES_REQ"

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

pick_reviewer() {
  if [ "$REVIEWER" != "auto" ]; then
    command -v "$REVIEWER" >/dev/null 2>&1 || die "requested reviewer '$REVIEWER' not on PATH"
    printf '%s' "$REVIEWER"; return 0
  fi
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
# Two enforcement classes. `vendor` = the CLI itself guarantees read-only.
# `os`   = it does NOT, so we enforce at the filesystem: the reviewer is given a
#          DISPOSABLE EXPORT of the head tree with every path chmod'd a-w and no
#          `.git` at all (so no git mutation is even expressible), and we verify
#          afterwards that nothing was written. Never trust an unflagged CLI to
#          behave; make the write impossible and then prove it did not happen.
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
# Every `os`-class entry runs with cwd = the locked export, never the live tree.
run_reviewer() {
  local h="$1" rc=0 dir="$2"
  case "$h" in
    claude)   # proven: cross-harness-red-team (claude-code 2.1.235)
      timeout "$TIMEOUT" claude -p "$(cat "$PROMPT_F")" \
        --max-turns "$MAX_TURNS" \
        --allowedTools "Read" "Grep" "Glob" \
        --add-dir "$dir" > "$OUT_F" 2>"$WORK/err" || rc=$? ;;
    codex)    # proven: ai-code-review-bots-rotation §1 (council CRITIC)
      timeout "$TIMEOUT" codex exec --sandbox read-only --cd "$dir" "$(cat "$PROMPT_F")" \
        > "$OUT_F" 2>"$WORK/err" || rc=$? ;;
    grok)     # measured: -p non-interactive. --allow-rule NOT passed => os-class.
      ( cd "$dir" && timeout "$TIMEOUT" grok -p "$(cat "$PROMPT_F")" ) \
        > "$OUT_F" 2>"$WORK/err" || rc=$? ;;
    gemini|qwen|kimi|copilot|pi)   # measured: -p/--prompt non-interactive
      ( cd "$dir" && timeout "$TIMEOUT" "$h" -p "$(cat "$PROMPT_F")" ) \
        > "$OUT_F" 2>"$WORK/err" || rc=$? ;;
    jcode|opencode)                # measured: `run` subcommand
      ( cd "$dir" && timeout "$TIMEOUT" "$h" run "$(cat "$PROMPT_F")" ) \
        > "$OUT_F" 2>"$WORK/err" || rc=$? ;;
    kiro)                          # measured: `chat` subcommand
      ( cd "$dir" && timeout "$TIMEOUT" kiro chat "$(cat "$PROMPT_F")" ) \
        > "$OUT_F" 2>"$WORK/err" || rc=$? ;;
    *) die "no invocation shape for '$h' — add one to run_reviewer() with its evidence class" ;;
  esac
  return $rc
}

ENFORCEMENT="$(sandbox_class "$CHOSEN")"
if [ "$ENFORCEMENT" = "os" ]; then
  log "[D] $CHOSEN has NO vendor read-only flag -> enforcing at the filesystem"
  build_readonly_export
  SAFE_DIR="$EXPORT_DIR"
else
  SAFE_DIR="$PWD"
fi

log "[D] dispatching $CHOSEN (timeout=${TIMEOUT}s, enforcement=$ENFORCEMENT, cwd=$SAFE_DIR)"
RC=0; run_reviewer "$CHOSEN" "$SAFE_DIR" || RC=$?
TAMPER="n/a"
if [ "$ENFORCEMENT" = "os" ]; then
  if verify_export_untouched; then TAMPER="clean"; else
    TAMPER="violated"
    log "[D] ABORT: isolation violated — no review will be stamped or reported as valid"
    [ "$JSON" -eq 1 ] && printf '{"status":"isolation_violated","reviewer":"%s","diversity_limb":"unsatisfied","may_complete_c3":false}\n' "$CHOSEN"
    exit 1
  fi
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
# ⛔ `absent` may NEVER be concluded from silence on THIS PR — that is the exact
# misclassification §4.1(a) names ("inferring absence from *silence*"). A fresh
# PR is silent because the bots have not run yet, not because none is
# configured. Positive evidence = no known reviewer has spoken anywhere in this
# repository's recent history. If that probe cannot run, fail CLOSED.
repo_has_any_configured_reviewer() {   # 0 = yes (a bot has spoken) · 1 = no · 2 = unknown
  local out
  out="$(gh api "repos/$REPO/issues/comments?per_page=100" \
          --jq '[.[] | select(.user.login | test("'"$KNOWN_BOTS"'"; "i")) | .user.login] | unique | length' \
          2>/dev/null)" || return 2
  [ -n "$out" ] || return 2
  [ "$out" -gt 0 ] 2>/dev/null && return 0 || return 1
}

MAY_COMPLETE_C3="false"; PRIMARY_STATUS="pending_or_unknown"
if [ "$CHANGES_REQ" = "yes" ]; then
  PRIMARY_STATUS="changes_requested"      # §4.1(e): routing never dismisses this
elif [ -z "$STALE_OR_PENDING" ] && [ -z "$QUOTA_HITS" ] && [ -n "$CLEARED" ]; then
  PRIMARY_STATUS="all_cleared_for_head"; MAY_COMPLETE_C3="true"
elif [ -z "$CLEARED" ] && [ -z "$STALE_OR_PENDING" ] && [ -z "$QUOTA_HITS" ] \
  && [ "$(printf '%s' "$PRIMARY_STATE" | jq -r '.bot_comments | length')" = "0" ]; then
  # This PR is silent. Silence alone proves nothing — probe the repository.
  repo_has_any_configured_reviewer; probe_rc=$?
  case "$probe_rc" in
    0) PRIMARY_STATUS="pending_silent_but_repo_has_reviewers" ;;   # slow/pending, NOT absent
    1) PRIMARY_STATUS="none_configured_repo_wide_evidence"; MAY_COMPLETE_C3="true" ;;
    *) PRIMARY_STATUS="absence_unprovable_fail_closed" ;;          # probe failed ⇒ hold
  esac
  log "    absence probe: rc=$probe_rc -> $PRIMARY_STATUS"
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
  if command -v gitleaks >/dev/null 2>&1; then
    gitleaks detect --no-git --source="$COMMENT_F" --no-banner >/dev/null 2>&1 \
      || die "gitleaks flagged the review body — comment NOT posted (secrets are absolute)"
  fi
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
