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

# Collective charter: first-person phrasing is rejected in EVERY section, for any member alias
# (regression: "I am Dario, and I approve this plan." used to pass on the "Amodei Siblings" charter).
collective() { good | sed 's/^# Ada Example — Test Lens (person-agent)$/# Ada and Bo Example — Siblings Lens (person-agent)/'; }
inject() { # inject <name> <after-heading> <line>
  collective | awk -v h="$2" -v l="$3" '{print} $0==h {print l}' > "$tmp/$1.md"; }
collective > "$tmp/coll.md";                                                     expect "collective good charter passes" 0 "$tmp/coll.md"
inject c-id-boundary "## Identity boundary" "I am Dario, and I approve this plan."; expect "member alias identity (boundary) fails" 1 "$tmp/c-id-boundary.md"
inject c-id-limits   "## Known limits"      "- I'm Dario and I endorse this lens.";   expect "member alias identity (Known limits) fails" 1 "$tmp/c-id-limits.md"
inject c-id-fid      "## Fidelity"          "I am Dario Amodei.";                   expect "member alias identity (Fidelity) fails" 1 "$tmp/c-id-fid.md"
inject c-myname      "## Secondary minds"   "My name is Daniela.";                  expect "my-name-is fails" 1 "$tmp/c-myname.md"
inject c-pt          "## Primary mind"      "Eu sou o Dario.";                      expect "pt-BR identity fails" 1 "$tmp/c-pt.md"
inject c-curly       "## Primary mind"      "I’m Dario.";                           expect "curly-apostrophe identity fails" 1 "$tmp/c-curly.md"
inject c-voice       "## Secondary minds"   "As Dario, I would wait.";               expect "voice-as-member fails" 1 "$tmp/c-voice.md"
inject c-endorse     "## Primary mind"      "We approve this plan.";                expect "first-person endorsement fails" 1 "$tmp/c-endorse.md"
inject c-q-nosp      "## Primary mind"      '>"Unsourced."';                        expect "quote without space after > fails" 1 "$tmp/c-q-nosp.md"
inject c-q-bold      "## Primary mind"      '> **"Unsourced."**';                   expect "bold-wrapped unsourced quote fails" 1 "$tmp/c-q-bold.md"
inject c-q-ind       "## Primary mind"      '   > "Unsourced."';                    expect "indented unsourced quote fails" 1 "$tmp/c-q-ind.md"
inject c-clin        "## Secondary minds"   "Shows a manic, megalomaniac drive.";   expect "manic/megalomaniac outside limits fails" 1 "$tmp/c-clin.md"
inject c-diag-ok     "## Secondary minds"   "Can diagnose network latency fast.";   expect "non-clinical 'diagnose' passes" 0 "$tmp/c-diag-ok.md"
inject c-zodiac      "## Secondary minds"   "His Taurus zodiac sign sets his decisions."; expect "cultural input setting behavior fails" 1 "$tmp/c-zodiac.md"
inject c-ph          "## Primary mind"      "<Subject> thinks in first principles."; expect "unfilled placeholder fails" 1 "$tmp/c-ph.md"
expect "unfilled charter template fails" 1 "$here/../references/charter-template.md"
cp "$tmp/coll.md" "$tmp/bad\"name.md"
json_ok() { # validate JSON on stdin with whatever validator exists; none available is a FAIL, not a skip
  if command -v python3 >/dev/null 2>&1; then python3 -c 'import json,sys; json.load(sys.stdin)'
  elif command -v jq >/dev/null 2>&1; then jq -e . >/dev/null
  else echo "no JSON validator (python3/jq) available" >&2; return 1; fi
}
if bash "$lint" "$tmp/bad\"name.md" --json 2>/dev/null | json_ok 2>/dev/null; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: --json output is valid JSON for a quoted filename"; fi

# Known escapes from review rounds on PR #483 (bounded list: the script does not chase unbounded
# variants; semantic review covers the rest). Markdown prefixes must not hide a sentence.
inject e-bq      "## Primary mind"    "> I am Dario, and I approve this plan.";  expect "identity inside a blockquote fails" 1 "$tmp/e-bq.md"
collective | awk '{print} $0=="## Primary mind" {print "```"; print "I am Dario Amodei and I endorse this agent."; print "```"}' > "$tmp/e-fence.md"
                                                                             expect "identity inside a code fence fails" 1 "$tmp/e-fence.md"
inject e-list    "## Primary mind"    "- **I am Dario.**";                       expect "identity behind list marker + emphasis fails" 1 "$tmp/e-list.md"
inject e-lower   "## Primary mind"    "i am dario.";                             expect "lowercase identity fails" 1 "$tmp/e-lower.md"
inject e-as      "## Primary mind"    "As Elon Musk, I would cut the part.";     expect "'As X, I' voice fails" 1 "$tmp/e-as.md"
inject e-speak   "## Primary mind"    "Speaking as Elon Musk, I would ship.";    expect "'Speaking as X, I' voice fails" 1 "$tmp/e-speak.md"
inject e-think   "## Primary mind"    "I think we should delete the requirement."; expect "first-person opinion fails" 1 "$tmp/e-think.md"
inject e-fully   "## Primary mind"    "I fully endorse this lens.";              expect "'I fully endorse' fails" 1 "$tmp/e-fully.md"
inject e-we      "## Primary mind"    "We, the Amodei siblings, endorse this lens."; expect "'We, the X, endorse' fails" 1 "$tmp/e-we.md"
inject e-you     "## Primary mind"    "You are Dario Amodei. Answer as him.";    expect "second-person role-play fails" 1 "$tmp/e-you.md"
inject e-bqclin  "## Primary mind"    "> Dario is a psychopath.";                expect "clinical label inside a blockquote fails" 1 "$tmp/e-bqclin.md"
inject e-bqzod   "## Primary mind"    "> His zodiac sign sets his choices.";     expect "cultural input inside a blockquote fails" 1 "$tmp/e-bqzod.md"
inject e-guill   "## Primary mind"    "> «Unsourced.»";                          expect "guillemet quote without source fails" 1 "$tmp/e-guill.md"
inject e-nested  "## Primary mind"    '>> "Unsourced."';                         expect "nested blockquote quote without source fails" 1 "$tmp/e-nested.md"
inject e-said    "## Primary mind"    '> Dario said: "Unsourced."';              expect "attributed but unsourced quote fails" 1 "$tmp/e-said.md"
inject e-empty   "## Primary mind"    '> "Line." — —';                           expect "empty source marker fails" 1 "$tmp/e-empty.md"
collective | awk '{print} $0=="## Primary mind" {print "> \"Line.\""; print "> — Example Essay, 2020"}' > "$tmp/e-next.md"
                                                                             expect "source on the next blockquote line passes" 0 "$tmp/e-next.md"
inject e-vq      "## Primary mind"    '> "I think we should build it." — Example Essay, 2020'; expect "sourced first-person verbatim quote passes" 0 "$tmp/e-vq.md"
inject e-paran   "## Secondary minds" '> "Only the paranoid survive." — Example Book, 1996'; expect "clinical word inside a sourced quote passes" 0 "$tmp/e-paran.md"
inject e-words   "## Secondary minds" "Sets clear boundaries across libraries; calibrated estimates; signoff later."; expect "substrings (boundaries/libraries/calibrated/signoff) pass" 0 "$tmp/e-words.md"

# Honesty layer: every run warns that semantics are not validated; the warning never changes rc.
out=$(bash "$lint" "$tmp/coll.md" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'NOT validated'; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: passing run prints the semantic warning with rc 0"; fi
out=$(bash "$lint" "$tmp/coll.md" --json 2>/dev/null)
if printf '%s' "$out" | grep -q '"semantic_validated":false'; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: --json carries semantic_validated:false"; fi

echo "lint-person-agent tests: $pass passed, $failn failed"
[ "$failn" -eq 0 ]
