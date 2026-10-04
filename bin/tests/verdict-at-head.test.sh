#!/usr/bin/env bash
# Tests for bin/verdict-at-head — offline, fixture-driven (no network, no gh).
# Bash 3.2-safe, self-contained. Run: bash bin/tests/verdict-at-head.test.sh
# No `set -e` on purpose: every case captures a NON-ZERO exit code of the script
#   under test (`out=$(...); rc=$?`), which `set -e` would abort on. Setup failures
#   are made fatal explicitly instead: `abort` for top-level setup, and a sentinel
#   file for fixture writes (they run inside `$(mk ...)` subshells, whose exit
#   cannot stop the parent) — checked after every fixture and again at the end.
set -uo pipefail

abort() { printf 'SETUP FAILURE: %s\n' "$1" >&2; exit 1; }

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)" || abort "cannot resolve test dir"
VAH="$DIR/../verdict-at-head"
[ -x "$VAH" ] || abort "script under test not executable: $VAH"
command -v jq >/dev/null 2>&1 || abort "jq not found"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/vah-test.XXXXXX")" || abort "mktemp failed"
[ -d "$WORK" ] || abort "work dir missing: $WORK"
trap 'rm -rf "$WORK"' EXIT
SETUP_FAIL="$WORK/.setup-failed"

pass=0 ; fail=0
ok() { pass=$((pass + 1)); printf '  \xe2\x9c\x93 %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \xe2\x9c\x97 %s\n      got: [%s]\n' "$1" "$2"; }
eq()  { if [ "$1" = "$2" ]; then ok "$3"; else no "$3" "got=[$2] want=[$1]"; fi; }
has() { case "$2" in *"$1"*) ok "$3" ;; *) no "$3" "$2" ;; esac; }

HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
OLD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
# Shares the first 12 chars with HEAD: a truncated compare would wrongly call it CURRENT.
NEAR=aaaaaaaaaaaacccccccccccccccccccccccccccc

# rv LOGIN STATE COMMIT SUBMITTED_AT ID -> one review object
rv() { printf '{"id":%s,"user":{"login":"%s"},"state":"%s","commit_id":"%s","submitted_at":"%s"}' "$5" "$1" "$2" "$3" "$4"; }

# mk NAME REVIEWS_JSON [STATUSES_JSON] [CHECKS_JSON] -> fixture dir path
mk() {
  d="$WORK/$1"
  { mkdir -p "$d" \
    && printf '{"headRefOid":"%s"}' "${HEADV:-$HEAD}" > "$d/pr.json" \
    && printf '%s' "$2" > "$d/reviews.json" \
    && printf '{"statuses":%s}' "${3:-[]}" > "$d/status.json" \
    && { [ -z "${4:-}" ] || printf '%s' "$4" > "$d/checks.json"; }
  } || { printf '%s\n' "$1" >> "$SETUP_FAIL"; return 1; }
  printf '%s' "$d"
}

# Refuse to evaluate a case whose fixture could not be written.
run() {
  [ -f "$SETUP_FAIL" ] && abort "fixture write failed: $(tr '\n' ' ' < "$SETUP_FAIL")"
  # Belt and braces: the sentinel itself may be unwritable; never run on a missing fixture.
  [ -f "${1:-}/pr.json" ] || abort "fixture missing for case: [${1:-}]"
  out="$("$VAH" --json --fixture-dir "$@" 2>&1)"; rc=$?
}
field() { printf '%s' "$out" | jq -r "$1"; }

printf 'verdict-at-head.test.sh\n'

# 1. approved at head -> CONVERGED
d="$(mk approved-head "[$(rv alice APPROVED $HEAD 2026-10-01T10:00:00Z 1)]")"
run "$d"; eq 0 "$rc" 'APPROVED at head -> exit 0'
eq CONVERGED "$(field .verdict)" 'APPROVED at head -> CONVERGED'
eq CURRENT "$(field '.reviewers[0].status')" 'APPROVED at head -> status CURRENT'

# 2. APPROVED on an old commit (the latestReviews trap) -> STALE, BLOCKED
d="$(mk approved-old "[$(rv alice APPROVED $OLD 2026-10-01T10:00:00Z 1)]")"
run "$d"; eq 3 "$rc" 'APPROVED on old commit -> exit 3'
eq STALE "$(field '.reviewers[0].status')" 'APPROVED on old commit -> STALE'
has 'stale:alice' "$(field '.reasons|join(",")')" 'reason names the stale reviewer'

# 3. full-SHA compare: a commit sharing a 12-char prefix is NOT the head
d="$(mk near-prefix "[$(rv alice APPROVED $NEAR 2026-10-01T10:00:00Z 1)]")"
run "$d"; eq STALE "$(field '.reviewers[0].status')" 'shared 12-char prefix is still STALE (no truncation)'

# 4. CHANGES_REQUESTED on an old commit, never superseded -> still blocking
d="$(mk cr-stale "[$(rv bob CHANGES_REQUESTED $OLD 2026-10-01T10:00:00Z 1)]")"
run "$d"; eq 3 "$rc" 'stale CHANGES_REQUESTED -> exit 3'
eq true "$(field '.reviewers[0].changes_requested_active')" 'stale CHANGES_REQUESTED is still active'

# 5. CHANGES_REQUESTED then APPROVED at head -> resolved
d="$(mk cr-resolved "[$(rv bob CHANGES_REQUESTED $OLD 2026-10-01T10:00:00Z 1),$(rv bob APPROVED $HEAD 2026-10-02T10:00:00Z 2)]")"
run "$d"; eq 0 "$rc" 'CHANGES_REQUESTED superseded by APPROVED at head -> exit 0'
eq false "$(field '.reviewers[0].changes_requested_active')" 'superseded CHANGES_REQUESTED is inactive'

# 6. CHANGES_REQUESTED then COMMENTED at head -> GitHub keeps it blocking
d="$(mk cr-then-comment "[$(rv bob CHANGES_REQUESTED $OLD 2026-10-01T10:00:00Z 1),$(rv bob COMMENTED $HEAD 2026-10-02T10:00:00Z 2)]")"
run "$d"; eq 3 "$rc" 'COMMENTED after CHANGES_REQUESTED -> still exit 3'
eq CURRENT "$(field '.reviewers[0].status')" 'its latest review is CURRENT'
has 'changes-requested:bob' "$(field '.reasons|join(",")')" 'active CHANGES_REQUESTED reported'

# 7. rate-limited success status at head -> BLOCKED (green tick, no verdict)
d="$(mk rate-limited "[$(rv 'coderabbitai[bot]' COMMENTED $OLD 2026-10-01T10:00:00Z 1)]" \
  '[{"context":"CodeRabbit","state":"success","description":"Review rate limited"}]')"
run "$d" --primary coderabbitai; eq 3 "$rc" 'success + "Review rate limited" -> exit 3'
eq true "$(field '.reviewers[0].rate_limited')" 'rate limit mapped to the reviewer login'
has 'rate-limited-check:CodeRabbit' "$(field '.reasons|join(",")')" 'rate-limited check reported'

# 8. rate-limited signal even when the reviewer looks current
d="$(mk rate-limited-current "[$(rv 'coderabbitai[bot]' COMMENTED $HEAD 2026-10-01T10:00:00Z 1)]" \
  '[{"context":"CodeRabbit","state":"success","description":"Review rate limited"}]')"
run "$d"; eq 3 "$rc" 'rate limit at head blocks even with a current review'

# 9. a non-rate-limit success status does not block
d="$(mk ok-status "[$(rv alice APPROVED $HEAD 2026-10-01T10:00:00Z 1)]" \
  '[{"context":"CodeRabbit","state":"success","description":"Review completed"}]')"
run "$d"; eq 0 "$rc" 'ordinary success status does not block'

# 10. rate limit reported through a check run output title
d="$(mk rate-limited-check "[$(rv alice APPROVED $HEAD 2026-10-01T10:00:00Z 1)]" '[]' \
  '[{"total_count":1,"check_runs":[{"name":"Some Bot","status":"completed","conclusion":"neutral","output":{"title":"Rate limit exceeded","summary":""}}]}]')"
run "$d"; eq 3 "$rc" 'check-run titled "Rate limit exceeded" -> exit 3'

# 11. pagination: 35 reviews split in pages of 30 + 5; the newest lives on page 2
p1=""; i=1
while [ $i -le 30 ]; do
  [ -n "$p1" ] && p1="$p1,"
  p1="$p1$(rv alice COMMENTED $OLD "2026-09-01T00:00:$(printf '%02d' $((i % 60)))Z" $i)"
  i=$((i + 1))
done
p2="$(rv alice COMMENTED $OLD 2026-09-02T00:00:00Z 31),$(rv alice COMMENTED $OLD 2026-09-02T00:00:01Z 32),$(rv carol APPROVED $HEAD 2026-09-02T00:00:02Z 33),$(rv alice COMMENTED $OLD 2026-09-02T00:00:03Z 34),$(rv alice APPROVED $HEAD 2026-09-03T00:00:00Z 35)"
d="$(mk paginated "[[${p1}],[${p2}]]")"
run "$d"; eq 0 "$rc" 'page-2 review is read (exit 0 only if pagination is honoured)'
eq 2 "$(field '.summary.reviewers')" 'pagination: 2 distinct reviewers across pages'
eq APPROVED "$(field '.reviewers[] | select(.login=="alice") | .state')" 'pagination: newest review (page 2) wins'

# 12. force-push: reviews are bound to a commit no longer in the branch
HEADV=dddddddddddddddddddddddddddddddddddddddd
d="$(mk force-push "[$(rv alice APPROVED $HEAD 2026-10-01T10:00:00Z 1)]")"
unset HEADV
run "$d"
eq 3 "$rc" 'head force-pushed -> previous approval is STALE (exit 3)'

# 13. --primary with no review -> NONE, BLOCKED
d="$(mk primary-none "[$(rv alice APPROVED $HEAD 2026-10-01T10:00:00Z 1)]")"
run "$d" --primary 'alice,dave[bot]'; eq 3 "$rc" 'missing primary -> exit 3'
eq NONE "$(field '.reviewers[] | select(.login=="dave") | .status')" 'missing primary -> NONE'

# 14. --primary narrows the requirement: a stale non-primary does not block
d="$(mk primary-only "[$(rv alice APPROVED $HEAD 2026-10-01T10:00:00Z 1),$(rv eve COMMENTED $OLD 2026-10-01T09:00:00Z 2)]")"
run "$d" --primary ALICE; eq 0 "$rc" 'stale non-primary COMMENTED does not block (case-insensitive primary)'
eq false "$(field '.reviewers[] | select(.login=="eve") | .primary')" 'non-primary flagged as not required'

# 15. ... but an active CHANGES_REQUESTED from a non-primary still blocks
d="$(mk primary-cr "[$(rv alice APPROVED $HEAD 2026-10-01T10:00:00Z 1),$(rv eve CHANGES_REQUESTED $HEAD 2026-10-01T11:00:00Z 2)]")"
run "$d" --primary alice; eq 3 "$rc" 'non-primary active CHANGES_REQUESTED blocks'

# 16. no reviews and no primaries -> nothing to converge on
d="$(mk empty "[]")"
run "$d"; eq 3 "$rc" 'no reviewers -> exit 3 (never vacuous convergence)'
has 'no-required-reviewer' "$(field '.reasons|join(",")')" 'empty case reason'

# 17. PENDING (draft) reviews are ignored
d="$(mk pending "[$(rv alice APPROVED $HEAD 2026-10-01T10:00:00Z 1),{\"id\":2,\"user\":{\"login\":\"alice\"},\"state\":\"PENDING\",\"commit_id\":\"$OLD\",\"submitted_at\":null}]")"
run "$d"; eq 0 "$rc" 'PENDING draft review ignored'

# 18. DISMISSED latest review of a primary -> no standing verdict
d="$(mk dismissed "[$(rv alice DISMISSED $HEAD 2026-10-01T10:00:00Z 1)]")"
run "$d"; eq 3 "$rc" 'DISMISSED primary -> exit 3'

# 19. fail-closed errors -> exit 2 (never 0)
d="$(mk bad-head "[]")"; printf '{"headRefOid":"not-a-sha"}' > "$d/pr.json"
run "$d"; eq 2 "$rc" 'invalid headRefOid -> exit 2'
d="$(mk bad-json "[]")"; printf '{oops' > "$d/reviews.json"
run "$d"; eq 2 "$rc" 'malformed reviews JSON -> exit 2'
out="$("$VAH" --json --fixture-dir "$WORK/does-not-exist" 2>&1)"; rc=$?; eq 2 "$rc" 'missing fixture dir -> exit 2'
out="$("$VAH" --pr 1 2>&1)"; rc=$?; eq 2 "$rc" 'missing --repo -> exit 2'
out="$("$VAH" --repo a/b --pr x 2>&1)"; rc=$?; eq 2 "$rc" 'non-numeric --pr -> exit 2'
out="$("$VAH" --bogus 2>&1)"; rc=$?; eq 2 "$rc" 'unknown flag -> exit 2'

# 20. text mode renders and keeps the exit code
d="$(mk text "[$(rv alice APPROVED $OLD 2026-10-01T10:00:00Z 1)]")"
out="$("$VAH" --fixture-dir "$d" 2>&1)"; rc=$?
eq 3 "$rc" 'text mode keeps exit 3'
has 'verdict: BLOCKED' "$out" 'text mode prints verdict'

# 21. status pages: a rate-limit description on page 2 still blocks
d="$(mk status-pages "[$(rv alice APPROVED $HEAD 2026-10-01T10:00:00Z 1)]")"
printf '[{"statuses":[{"context":"ci","state":"success","description":"ok"}]},{"statuses":[{"context":"ReviewBot","state":"success","description":"Review rate limited"}]}]' > "$d/status.json"
run "$d"; eq 3 "$rc" 'rate limit on status page 2 -> exit 3'

# 22. unknown/malformed review state at head is not a verdict
d="$(mk unknown-state "[$(rv alice WEIRD $HEAD 2026-10-01T10:00:00Z 1)]")"
run "$d"; eq 3 "$rc" 'unknown review state at head -> exit 3'
has 'no-verdict-state:alice' "$(field '.reasons|join(",")')" 'unknown state reported'

# 23. rate limit only in check-run output.text
d="$(mk rate-limited-text "[$(rv alice APPROVED $HEAD 2026-10-01T10:00:00Z 1)]" '[]' \
  '[{"check_runs":[{"name":"Some Bot","conclusion":"neutral","output":{"title":"Done","summary":"","text":"Hit the rate limit for this account"}}]}]')"
run "$d"; eq 3 "$rc" 'rate limit only in check-run output.text -> exit 3'

# 24. regex is literal: "rateXlimit" is not a rate-limit signal
d="$(mk regex-literal "[$(rv alice APPROVED $HEAD 2026-10-01T10:00:00Z 1)]" \
  '[{"context":"ci","state":"success","description":"rateXlimit rate5limit"}]')"
run "$d"; eq 0 "$rc" 'rateXlimit / rate5limit do not match (character class is literal)'

# 25. attribution never uses a prefix: context "ci" must NOT mark reviewer "cicero"
d="$(mk attr-ci "[$(rv cicero COMMENTED $HEAD 2026-10-01T10:00:00Z 1)]" \
  '[{"context":"ci","state":"success","description":"Review rate limited"}]')"
run "$d"; eq false "$(field '.reviewers[] | select(.login=="cicero") | .rate_limited')" 'context "ci" does not mark reviewer "cicero" (no prefix match)'
eq 3 "$rc" 'unattributed rate limit still blocks (fail-safe verdict kept)'

# 26. positive control: "Qodo Merge" IS attributed to qodo[bot] (token match after [bot] strip)
d="$(mk attr-qodo "[$(rv 'qodo[bot]' COMMENTED $HEAD 2026-10-01T10:00:00Z 1)]" \
  '[{"context":"Qodo Merge","state":"success","description":"Review rate limited"}]')"
run "$d"; eq true "$(field '.reviewers[] | select(.login=="qodo") | .rate_limited')" 'context "Qodo Merge" detected on reviewer qodo[bot]'
has 'rate-limited-reviewer:qodo' "$(field '.reasons|join(",")')" 'per-reviewer reason names qodo'

# 27. a shared non-vendor token is not attribution: "code/snyk" must not mark "qodo-code-review"
d="$(mk attr-shared-token "[$(rv 'qodo-code-review[bot]' COMMENTED $HEAD 2026-10-01T10:00:00Z 1)]" \
  '[{"context":"code/snyk (acct)","state":"error","description":"rate limit reached"}]')"
run "$d"; eq false "$(field '.reviewers[0].rate_limited')" 'shared token "code" does not attribute snyk to qodo-code-review'

# 28. full normalized equality: "Amazon Q Developer" <-> amazon-q-developer[bot]
d="$(mk attr-amazon "[$(rv 'amazon-q-developer[bot]' COMMENTED $HEAD 2026-10-01T10:00:00Z 1)]" \
  '[{"context":"Amazon Q Developer","state":"success","description":"Review rate limited"}]')"
run "$d"; eq true "$(field '.reviewers[0].rate_limited')" 'normalized equality attributes "Amazon Q Developer"'

[ -f "$SETUP_FAIL" ] && abort "fixture write failed: $(tr '\n' ' ' < "$SETUP_FAIL")"
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
