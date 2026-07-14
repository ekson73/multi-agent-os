#!/usr/bin/env bash
# classify.sh — deterministic HARD-BOUNDARY pre-filter for hitl-authorizer (Tribune).
#
# The Tribune brokers an escalation that WOULD otherwise fall back to a human: it either
# authorizes it in the human's place OR defers to real HITL. This script is the ECE
# deterministic skeleton (f=0) that runs FIRST in ORIENT — it decides ONLY whether a
# council may be spawned at all. It NEVER emits "authorize": the ≥0.90 + convergence +
# independent-verify AUTHORIZE decision is the probabilistic SKILL.md OODA layer.
#
# The three deterministic buckets (evaluated in this fail-CLOSED safety order):
#   1. carve-out  (secrets ⛔ · HUMAN_DOMAIN · merge→main/prod)
#        -> disposition=defer-hitl · council=none · never_authorize=true
#        The un-liftable / human-owned classes. Matched FIRST; NO council is spawned.
#        Secrets-exposure is checked before everything else and is ABSOLUTE: operator
#        authorization does NOT waive it (CLAUDE.md Guardrails; COWORK-AUTONOMY-POLICY ⛔).
#   2. hard-trigger  (red-team H1-H12: behavioral auth/crypto/access-control/guardrail
#        change · self-edit of a governance rule · irreversible high-blast · unattended
#        side-effect · cross-org · dangerous-capability · untrusted-input-steered · fail-open)
#        -> disposition=adversarial-verify-required · council=red-team+council · never_authorize=false
#        MAY be authorized ONLY after an INDEPENDENT red-team (Elenchus) passes (verifier>generator).
#   3. residue  (SOFT / uncertainty: low-confidence · resolvable ambiguity · missing context/perspective)
#        -> disposition=council · council=moe+council · never_authorize=false
#        The uncertainty-residue a diverse council can resolve; MAY be authorized at ≥0.90 downstream.
#
# SAFETY INVARIANTS (what the fixtures prove):
#   - secrets/HUMAN_DOMAIN/merge-prod ALWAYS -> defer-hitl · never_authorize=true · council=none
#     (the ⛔ gate is code-enforced; the Tribune can NEVER substitute the human here).
#   - a hard-trigger is NEVER marked authorizable without an independent red-team.
#   - residue is the ONLY bucket that reaches the council — and even it never authorizes here.
#
# Usage:  classify.sh [--json] [escalation.json]   (reads stdin when no file arg)
#   escalation.json fields (all optional strings): {"decision","action","context","scope",
#     "targets","description","state"} — the pending decision/action + its frame.
# Output (default): one canonical line — bucket=… disposition=… council=… never_authorize=…
# Output (--json):  the full verdict object.
# Exit: 0 on success · 2 invalid JSON · 3 missing jq.
set -euo pipefail

emit_json=0
if [ "${1:-}" = "--json" ]; then emit_json=1; shift; fi

src="${1:-/dev/stdin}"
command -v jq >/dev/null 2>&1 || { echo "classify.sh: jq is required" >&2; exit 3; }

raw="$(cat -- "$src")"
printf '%s' "$raw" | jq -e . >/dev/null 2>&1 || { echo "classify.sh: invalid JSON input" >&2; exit 2; }

# Combine the salient escalation fields into ONE lowercase haystack (deterministic,
# case-insensitive). Fail-closed: matching more text = MORE likely to defer, never less.
hay="$(printf '%s' "$raw" | jq -r '
  [ .decision, .action, .context, .scope, .targets, .description, .state ]
  | map(select(. != null) | tostring) | join(" ")
' | tr '[:upper:]' '[:lower:]')"

# ── Cue sets (POSIX ERE), fail-CLOSED (favor defer on ambiguity) ────────────────────────
# secrets_re — the ⛔ ABSOLUTE un-liftable class. Checked FIRST. A decision that even
# TOUCHES secret-exposure territory defers — over-defer here is the correct fail-safe bias.
secrets_re='secret|credential|password|passwd|api.?key|access.?token|\btoken\b|1password|\bop://|\.env\b|gitleaks|private.?key|ssh.?key|client.?secret|bearer'
# human_domain_re — [C17] §2 HUMAN_DOMAIN: production PII, irreversible, cross-org, ethics, $$$.
human_domain_re='production.?(data|pii|database|secret)|\bpii\b|lgpd|gdpr|personal.?data|data.?subject|irreversible|force.?push|--?no-verify|\brm -rf\b|delete[^a-z]*(data|branch|prod|table|repo)|drop.?(table|schema|database)|truncate|cross.?org|customer.?facing|third.?part|\bethic|compliance|\$\$\$|\bbilling\b|\bpayment\b|financial.?transaction|hire|fire|legal'
# merge_prod_re — merge→main/prod is the human owner's call (never auto-substituted).
merge_prod_re='merge[^a-z]*(to[^a-z]*)?(main|master|prod|production|release)|deploy[^a-z]*(to[^a-z]*)?(prod|production|main)|push[^a-z]*(to[^a-z]*)?(main|master|protected)'
# redteam_re — red-team (Elenchus) H1-H12 instance hard-triggers: MAY authorize ONLY after
# an INDEPENDENT red-team passes. Behavioral auth/crypto/access-control/guardrail change,
# self-edit of a governance rule, dangerous capability, untrusted-input-steered, fail-open.
redteam_re='auth(entication|orization)?[^a-z]*(change|flaw|bypass|flip)|\bcrypto\b|encryption[^a-z]*(change|disable)|access.?control|guard.?rail|self.?edit|governance.?rule|edit[^a-z]*(a[^a-z]*)?(rule|policy|guardrail)|dangerous.?capab|\brce\b|\bssrf\b|untrusted.?input|fail.?open|unattended[^a-z]*(side.?effect|write|mutat)|aggregate[^a-z]*campaign'

if printf '%s' "$hay" | grep -Eiq "$secrets_re"; then
  bucket="carve-out-secret"; disposition="defer-hitl"; council="none"; never_authorize="true"
  action="secrets-exposure ⛔ ABSOLUTE — un-liftable even by operator authorization; DEFER to HITL, spawn NO council, NEVER authorize"
elif printf '%s' "$hay" | grep -Eiq "$human_domain_re"; then
  bucket="carve-out-human-domain"; disposition="defer-hitl"; council="none"; never_authorize="true"
  action="[C17] §2 HUMAN_DOMAIN (production PII / irreversible / cross-org / ethics / \$\$\$) — human-owned; DEFER to HITL, spawn NO council, NEVER auto-substitute"
elif printf '%s' "$hay" | grep -Eiq "$merge_prod_re"; then
  bucket="carve-out-merge-prod"; disposition="defer-hitl"; council="none"; never_authorize="true"
  action="merge→main/production is the human owner's decision — DEFER to HITL, spawn NO council, NEVER auto-substitute"
elif printf '%s' "$hay" | grep -Eiq "$redteam_re"; then
  bucket="hard-trigger"; disposition="adversarial-verify-required"; council="red-team+council"; never_authorize="false"
  action="red-team (Elenchus) H1-H12 hard-trigger — MAY authorize ONLY if an INDEPENDENT red-team (verifier>generator, gated by bin/convergence-guard) passes; else HOLD/DEFER"
else
  bucket="residue"; disposition="council"; council="moe+council"; never_authorize="false"
  action="uncertainty-residue (SOFT) — run the MoE→Council ladder; MAY authorize at score≥0.90 ∧ convergence ∧ independent-verify, else DEFER with ranked recommendation"
fi

if [ "$emit_json" -eq 1 ]; then
  jq -n --arg bucket "$bucket" --arg disposition "$disposition" \
        --arg council "$council" --argjson never_authorize "$never_authorize" \
        --arg action "$action" \
        '{verdict:{bucket:$bucket,disposition:$disposition,council:$council,never_authorize:$never_authorize,action:$action}}'
else
  printf 'bucket=%s disposition=%s council=%s never_authorize=%s\n' \
    "$bucket" "$disposition" "$council" "$never_authorize"
fi
