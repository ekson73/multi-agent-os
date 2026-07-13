#!/usr/bin/env bash
# run-tests.sh — real (not theater) deterministic tests for the goal-loop typed envelopes.
# Proves: (1) both example envelopes VALIDATE, (2) an invalid envelope is REFUSED (gate fires),
# (3) the idempotency digest is INVARIANT under a confidence jitter (same state -> same envelope,
# modulo the probabilistic confidence float). Stdlib only; exit 0 iff all pass.
# NOTE: expected-FAILURE checks (validator exit 3) use if/then/else, not `A && B || C`, so they
# neither abort under `set -e` nor mask a failure via SC2015.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS="$(cd "$HERE/../.." && pwd)"                       # .../skills
VALIDATE="$SKILLS/goal-recovery/bin/validate_envelope.py"
HANDOFF="$SKILLS/goal-recovery/templates/handoff-as-prompt.example.json"
DOD="$SKILLS/ooda-loop/templates/dod-as-prompt.example.json"
INVALID="$SKILLS/goal-recovery/tests/handoff-as-prompt.invalid.example.json"

PY="$(command -v python3 || command -v python)"
[ -n "$PY" ] || { echo "FAIL: no python found"; exit 1; }

pass=0 fail=0
ok()   { echo "  ok   — $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL — $1"; fail=$((fail+1)); }

echo "== goal-loop envelope tests =="

# 1. valid handoff -> exit 0
if "$PY" "$VALIDATE" "$HANDOFF" >/dev/null 2>&1; then
  ok "valid handoff-as-prompt validates (exit 0)"
else
  bad "valid handoff-as-prompt should validate"
fi

# 2. valid dod -> exit 0
if "$PY" "$VALIDATE" "$DOD" >/dev/null 2>&1; then
  ok "valid dod-as-prompt validates (exit 0)"
else
  bad "valid dod-as-prompt should validate"
fi

# 3. invalid handoff -> SpecError (exit 3)  [expected-failure: capture rc, don't abort under set -e]
if "$PY" "$VALIDATE" "$INVALID" >/dev/null 2>&1; then rc=0; else rc=$?; fi
if [ "$rc" -eq 3 ]; then
  ok "invalid handoff is REFUSED (SpecError exit 3 — low-confidence gate fires)"
else
  bad "invalid handoff should be refused with exit 3"
fi

# 4. idempotency: digest invariant under a confidence jitter
D1="$("$PY" "$VALIDATE" "$HANDOFF" --digest 2>/dev/null || true)"   # empty on failure -> caught by [ -n ] below
JITTER="$(mktemp)"; trap 'rm -f "$JITTER"' EXIT
"$PY" - "$HANDOFF" "$JITTER" <<'PYEOF'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
o = json.load(open(src))
# perturb ONLY the probabilistic confidence floats (aggregate + each hypothesis) — nothing else
o["params"]["confidence"] = 0.72
for h in o["params"]["hypotheses"]:
    h["confidence"] = round(h["confidence"] * 0.8, 3)
json.dump(o, open(dst, "w"))
PYEOF
D2="$("$PY" "$VALIDATE" "$JITTER" --digest 2>/dev/null || true)"
if [ -n "$D1" ] && [ "$D1" = "$D2" ]; then
  ok "idempotency digest invariant under confidence jitter ($D1)"
else
  bad "idempotency digest changed under confidence jitter ($D1 vs $D2)"
fi

# 5. sanity: a MEANINGFUL change (the goal itself) MUST change the digest (digest isn't trivially constant)
JITTER2="$(mktemp)"; trap 'rm -f "$JITTER" "$JITTER2"' EXIT
"$PY" - "$HANDOFF" "$JITTER2" <<'PYEOF'
import json, sys
o = json.load(open(sys.argv[1]))
o["params"]["goal"] = "A DIFFERENT recovered goal."
json.dump(o, open(sys.argv[2], "w"))
PYEOF
D3="$("$PY" "$VALIDATE" "$JITTER2" --digest 2>/dev/null || true)"
if [ "$D1" != "$D3" ]; then
  ok "digest DOES change when the deterministic content (goal) changes (not trivially constant)"
else
  bad "digest should change when the goal changes"
fi

# 6-8. full gate coverage: every SpecError gate must REFUSE (exit 3), each from a distinct violation
gate_test() {   # $1=label  $2=python mutation of `o` (loaded from HANDOFF)
  local label="$1" body="$2" tmp
  tmp="$(mktemp)"
  "$PY" - "$HANDOFF" "$tmp" "$body" <<'PYEOF'
import json, sys
o = json.load(open(sys.argv[1]))
exec(sys.argv[3])
json.dump(o, open(sys.argv[2], "w"))
PYEOF
  if "$PY" "$VALIDATE" "$tmp" >/dev/null 2>&1; then rc=0; else rc=$?; fi
  if [ "$rc" -eq 3 ]; then ok "gate fires: $label (exit 3)"; else bad "gate should refuse: $label"; fi
  rm -f "$tmp"
}
gate_test "empty goal without inconclusive flag"        'o["params"]["goal"]=""'
gate_test "recovered_from empty while confidence>0"     'o["params"]["recovered_from"]=[]'
gate_test "goal != hypotheses[0].goal (no flag)"        'o["params"]["hypotheses"][0]["goal"]="a different top hypothesis"'

echo "-- $pass passed, $fail failed --"
[ "$fail" -eq 0 ]
