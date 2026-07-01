#!/usr/bin/env bash
# classify.sh — deterministic ORIENT pre-filter for bot-finding-arbiter (Praetor).
#
# Implements ONLY the DETERMINISTIC classification cues from bot-config-registry.md
# ("Classification cues" section). This is the ECE deterministic skeleton; the
# probabilistic disposition (which of the 7 dispositions, the actual teach-the-bot
# edit) stays in the LLM-driven SKILL.md OODA loop.
#
# The three deterministic buckets (evaluated in this safety order):
#   1. account/platform error  (state=error + platform keyword)
#        -> NOT repo-fixable · HITL · no config edit
#        (the bot's PLATFORM failed, not the code — e.g. Snyk "test limit reached").
#   2. security class          (secret/injection/auth/CVE/data-loss in the finding substance)
#        -> HITL-gated · never_suppress=true
#        (⛔ a security finding is NEVER deterministically auto-suppressed).
#   3. content                 (everything else)
#        -> defer-to-verify (hand to the probabilistic ORIENT + independent verify).
#
# SAFETY INVARIANTS (what the fixtures prove):
#   - security-class ALWAYS returns never_suppress=true (the ⛔ gate is code-enforced).
#   - content is NEVER deterministically marked repo-fixable/suppressible → defer-to-verify.
#   - only a state=error platform failure is marked repo_fixable=no (the account-vs-code split).
#
# Usage:  classify.sh [--json] [finding.json]   (reads stdin when no file arg)
#   finding.json fields: {"bot","context","state","description"}  (all optional strings)
# Output (default): one canonical line — bucket=… disposition=… repo_fixable=… never_suppress=…
# Output (--json):  the full verdict object.
# Exit: 0 on success · 2 invalid JSON · 3 missing jq.
set -euo pipefail

emit_json=0
if [ "${1:-}" = "--json" ]; then emit_json=1; shift; fi

src="${1:-/dev/stdin}"
command -v jq >/dev/null 2>&1 || { echo "classify.sh: jq is required" >&2; exit 3; }

raw="$(cat -- "$src")"
printf '%s' "$raw" | jq -e . >/dev/null 2>&1 || { echo "classify.sh: invalid JSON input" >&2; exit 2; }

# Extract + lowercase (deterministic, case-insensitive matching).
context="$(printf '%s' "$raw" | jq -r '.context // ""'     | tr '[:upper:]' '[:lower:]')"
state="$(printf '%s'   "$raw" | jq -r '.state // ""'       | tr '[:upper:]' '[:lower:]')"
desc="$(printf '%s'    "$raw" | jq -r '.description // ""'  | tr '[:upper:]' '[:lower:]')"

# Cue sets (POSIX ERE). platform_re matches quota/entitlement-SPECIFIC phrases only — high
# precision is MANDATORY here because account-error is the one bucket that says "not repo-fixable,
# stop." NOT a bare "limit" (tightened per amazon-q #192) and NOT a bare "import" (removed per
# qodo #192 — "failed to import" is ambiguous: a code import error is repo-fixable, a Snyk
# "unable to import project" is account-side → defer the ambiguous case to the probabilistic
# verify instead of deterministically dismissing it). Double-guarded: also consulted ONLY when
# state=error. Still catches BOTH real Snyk variants ("used your limit of private tests" ·
# "Code test limit reached"). HTTP codes are word-boundaried to avoid substring hits (e.g. "1502").
platform_re='quota|rate.?limit|(test|usage|monthly|daily|plan|account|your) ?limit|limit (reached|exceeded|of)|entitlement|not authorized|unauthorized|auth failed|timed? ?out|service unavailable|\b(429|50[23])\b'
security_re='secret|credential|password|api.?key|access.?token|injection|sqli|xss|auth(entication|orization)? ?(flaw|bypass)|cve-|vulnerab|data.?loss|\brce\b|\bssrf\b|hardcoded'

if [ "$state" = "error" ] && printf '%s' "$desc" | grep -Eiq "$platform_re"; then
  bucket="account-error"; disposition="hitl"; repo_fixable="no"; never_suppress="false"
  action="account/platform error (the bot's platform failed, not the code) — HITL playbook, NO config edit; a repo file cannot fix an account-side quota/limit"
elif printf '%s\n%s' "$desc" "$context" | grep -Eiq "$security_re"; then
  bucket="security-class"; disposition="hitl"; repo_fixable="gated"; never_suppress="true"
  action="security-class finding — NEVER auto-suppress; default fix/upgrade; any bot-wrong verdict here is HITL-gated with a deterministic proof"
else
  bucket="content"; disposition="defer-to-verify"; repo_fixable="maybe"; never_suppress="false"
  action="content finding — hand to the probabilistic ORIENT + independent verify (verifier>generator); never deterministically auto-suppress"
fi

if [ "$emit_json" -eq 1 ]; then
  jq -n --arg context "$context" --arg state "$state" \
        --arg bucket "$bucket" --arg disposition "$disposition" \
        --arg repo_fixable "$repo_fixable" --argjson never_suppress "$never_suppress" \
        --arg action "$action" \
        '{context:$context,state:$state,verdict:{bucket:$bucket,disposition:$disposition,repo_fixable:$repo_fixable,never_suppress:$never_suppress,action:$action}}'
else
  printf 'bucket=%s disposition=%s repo_fixable=%s never_suppress=%s\n' \
    "$bucket" "$disposition" "$repo_fixable" "$never_suppress"
fi
