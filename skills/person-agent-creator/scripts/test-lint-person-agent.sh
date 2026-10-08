#!/usr/bin/env bash
# test-lint-person-agent.sh — offline fixtures for lint-person-agent.sh.
# Exit 0 when every assertion holds, 1 otherwise.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
lint="$here/lint-person-agent.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pass=0; failn=0

good() {
cat <<'EOF'
---
name: test-person
---
# Ada Example — Test Lens (person-agent)
## Identity boundary
A lens, not the person.
## Primary mind
First principles.
## Secondary minds
Empiricism.
## In their own words (verbatim, sourced)
> "Measure twice." — Example Essay, 2020
## Known limits
Never claims the person's endorsement.
## Fidelity
| Field | Status | Source ids |
|---|---|---|
| Primary mind | documented | S1 |
EOF
}

expect() { # expect <name> <expected-rc> <file>
  bash "$lint" "$3" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq "$2" ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: $1 (rc=$rc, want $2)"; fi
}

good > "$tmp/good.md";                                   expect "good charter passes" 0 "$tmp/good.md"
good | grep -v '^## Known limits$' > "$tmp/nolimits.md"; expect "missing Known limits fails" 1 "$tmp/nolimits.md"
good | grep -v '^| Field' > "$tmp/notable.md";           expect "missing fidelity table fails" 1 "$tmp/notable.md"
{ good; echo "Hello, I am Ada and I approve."; } > "$tmp/fp.md"; expect "first-person identity fails" 1 "$tmp/fp.md"
{ good; echo '> "Unsourced line."'; } > "$tmp/q.md";      expect "unsourced quote fails" 1 "$tmp/q.md"
good | sed 's/^Empiricism.$/Shows narcissistic drive./' > "$tmp/clin.md"; expect "clinical label outside limits fails" 1 "$tmp/clin.md"
good | sed 's/^Never claims the person.s endorsement.$/No diagnosis of the subject./' > "$tmp/limok.md"; expect "clinical word inside Known limits passes" 0 "$tmp/limok.md"
expect "missing file is usage error" 2 "$tmp/does-not-exist.md"

echo "lint-person-agent tests: $pass passed, $failn failed"
[ "$failn" -eq 0 ]
