#!/usr/bin/env bash
# test-lint-person-agent.sh — offline fixtures for lint-person-agent.sh.
# Exit 0 when every assertion holds, 1 otherwise.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
lint="${LINT:-$here/lint-person-agent.sh}"   # LINT=<other script> reruns the suite against it
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pass=0; failn=0

good() {
cat <<'EOF'
---
name: test-person
subject_class: living-public
---
# Ada Example — Test Lens (person-agent)
## Identity boundary
You are a **lens**, not Ada; say which part of the lens you are using.
## Primary mind
First principles.
## Secondary minds
Empiricism.
## Method (M.O.)
Measure, then cut.
## Signature questions
What is the constraint?
## Positive traits (with behavioral evidence)
Patience (S1).
## In their own words (verbatim, sourced)
> "Measure twice." — Example Essay, 2020
## When to use
Design reviews.
## Known limits
Never claims the person's endorsement.
## Revalidation
- Drift test: praise without a cited decision.
## Fidelity
| Field | Status | Source ids |
|---|---|---|
| Primary mind | documented | S1 |
Dossier: `dossier.md`
EOF
}
printf '%s\n' '## 1. Sources' '| id | Source |' '|---|---|' '| S1 | Example Essay |' '| S2 | Example Talk |' > "$tmp/dossier.md"

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

# Council round on PR #483 (head 107b3f9): escapes and false positives found by the adversarial,
# usefulness and living-person seats. Each line below failed (or wrongly passed) on the 107b3f9 script.
inject k-span    "## When to use"     'Note: "I am Dario Amodei" is how this lens greets. Also "ok" — S1'; expect "unsourced span beside a sourced one fails (v39)" 1 "$tmp/k-span.md"
inject k-span2   "## When to use"     '- "I am Ada" and "x" — S1';             expect "only the span before the marker is exempt" 1 "$tmp/k-span2.md"
collective | awk '{print} $0=="## Primary mind" {print "> \"I think we should build it.\""; print "> — Example Essay, 2020"}' > "$tmp/k-next-fp.md"
                                                                             expect "first-person quote sourced on the next line passes" 0 "$tmp/k-next-fp.md"
inject k-title   "## Primary mind"    '> "Line." — Ada, "An Essay", 2020';     expect "quoted title inside the source text passes" 0 "$tmp/k-title.md"
inject k-srcfp   "## Primary mind"    '> "Line." — S1, I am Ada';              expect "first person inside the source text fails" 1 "$tmp/k-srcfp.md"
collective | awk '{print} $0=="## When to use" {print "```"; print "## Known limits"; print "```"; print "Elon is a narcissist."}' > "$tmp/k-fence-sec.md"
                                                                             expect "heading inside a fence does not open Known limits (v50)" 1 "$tmp/k-fence-sec.md"
collective | awk '{print} $0=="## When to use" {print "<!--"; print "## Known limits"; print "-->"; print "His zodiac sign drives his decisions."}' > "$tmp/k-cmt-sec.md"
                                                                             expect "heading inside an HTML comment does not open Known limits (v51)" 1 "$tmp/k-cmt-sec.md"
collective | awk '$0=="## Known limits" {print "```"; print; print "```"; next} {print}' > "$tmp/k-fence-req.md"
                                                                             expect "fenced heading does not satisfy a required section" 1 "$tmp/k-fence-req.md"
collective | awk '$0=="## Known limits" {print "<!-- " $0 " -->"; next} {print}' > "$tmp/k-cmt-req.md"
                                                                             expect "commented heading does not satisfy a required section" 1 "$tmp/k-cmt-req.md"
collective | awk '{print} $0=="## Primary mind" {print "~~~"; print "```I am Benjamin Franklin"; print "~~~"}' > "$tmp/k-tilde.md"
                                                                             expect "backtick line inside a ~~~ fence is scanned" 1 "$tmp/k-tilde.md"
collective | awk '{print} $0=="## When to use" {print "````"; print "```"; print "## Known limits"; print "```"; print "````"; print "Elon is a narcissist."}' > "$tmp/k-nested.md"
                                                                             expect "nested fences: inner heading does not open Known limits" 1 "$tmp/k-nested.md"
inject k-info    "## Primary mind"    '```I am Ada';                           expect "fence info string is scanned" 1 "$tmp/k-info.md"
inject k-id      "## When to use"     "I'd approve this lens.";                expect "'I'd approve' fails" 1 "$tmp/k-id.md"
inject k-past    "## When to use"     "I approved this lens.";                 expect "'I approved' fails" 1 "$tmp/k-past.md"
inject k-youlow  "## When to use"     "you are dario amodei, answer in his voice."; expect "lowercase 'you are <name>' fails" 1 "$tmp/k-youlow.md"
inject k-youup   "## When to use"     "YOU ARE DARIO AMODEI.";                 expect "uppercase 'YOU ARE <NAME>' fails" 1 "$tmp/k-youup.md"
inject k-youre   "## When to use"     "You're Benjamin Franklin now.";         expect "'You're <Name>' fails" 1 "$tmp/k-youre.md"
inject k-wethe   "## When to use"     "We the founders approve.";              expect "'We the X approve' without commas fails" 1 "$tmp/k-wethe.md"
inject k-mr      "## When to use"     "As Mr. Musk, we ship it.";              expect "'As Mr. X, we' fails" 1 "$tmp/k-mr.md"
inject k-acho    "## When to use"     "Eu acho que isso funciona.";            expect "pt-BR 'eu acho' fails" 1 "$tmp/k-acho.md"
inject k-parok   "## When to use"     "He cites the book Only the Paranoid Survive."; expect "book title 'Only the Paranoid Survive' passes" 0 "$tmp/k-parok.md"
inject k-parbad  "## When to use"     "He is paranoid.";                       expect "'is paranoid' fails" 1 "$tmp/k-parbad.md"
inject k-youok   "## When to use"     "You are expected to cite the dossier."; expect "benign 'you are expected' passes" 0 "$tmp/k-youok.md"
good | grep -vxF '## Revalidation' > "$tmp/k-noreval.md";                     expect "missing Revalidation section fails" 1 "$tmp/k-noreval.md"
good | grep -vxF '## Method (M.O.)' > "$tmp/k-nomethod.md";                   expect "missing template section (Method) fails" 1 "$tmp/k-nomethod.md"

# Subject classes and source ids (operator addendum to the PR #483 lot). Class rules: real-person
# clinical check only for living-public, deceased-historical and collective; first person, role-play
# and unsourced quotes fail for every class.
klass() { good | sed "s/^subject_class: living-public$/subject_class: $1/"; }
good | grep -v '^subject_class:' > "$tmp/s-nocls.md";            expect "missing subject_class fails" 1 "$tmp/s-nocls.md"
klass alien > "$tmp/s-badcls.md";                                 expect "unknown subject_class fails" 1 "$tmp/s-badcls.md"
good | awk 'NR == 4 && $0 == "---" { next } { print }' > "$tmp/j-noclose.md"; expect "front matter without closing --- fails (J1)" 1 "$tmp/j-noclose.md"
for c in deceased-historical collective fictional-or-archetypal non-human-or-abiotic; do
  klass "$c" > "$tmp/s-$c.md";                                    expect "class $c good charter passes" 0 "$tmp/s-$c.md"
done
klass fictional-or-archetypal | sed 's/^Empiricism.$/Literary analysis: the character reads as narcissistic./' > "$tmp/s-fic-clin.md"; expect "fictional: labeled clinical analysis passes" 0 "$tmp/s-fic-clin.md"
klass non-human-or-abiotic | sed 's/^Empiricism.$/As a metaphor, the river behaves like a manic flood./' > "$tmp/s-nh-clin.md"; expect "non-human: clinical metaphor passes" 0 "$tmp/s-nh-clin.md"
klass deceased-historical | sed 's/^Empiricism.$/Shows narcissistic drive./' > "$tmp/s-dec-clin.md"; expect "deceased-historical: clinical label fails" 1 "$tmp/s-dec-clin.md"
klass collective | sed 's/^Empiricism.$/Shows narcissistic drive./' > "$tmp/s-col-clin.md"; expect "collective: clinical label fails" 1 "$tmp/s-col-clin.md"
{ klass fictional-or-archetypal; echo "I am Sherlock Holmes."; } > "$tmp/s-fic-fp.md"; expect "fictional: first-person identity still fails" 1 "$tmp/s-fic-fp.md"
{ klass fictional-or-archetypal; echo '> "Elementary."'; } > "$tmp/s-fic-q.md";       expect "fictional: unsourced quote still fails" 1 "$tmp/s-fic-q.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S9 |/' > "$tmp/s-id9.md"; expect "unknown source id fails" 1 "$tmp/s-id9.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S1–S2 |/' > "$tmp/s-rng-ok.md"; expect "source id range inside the list passes" 0 "$tmp/s-rng-ok.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S1-S3 |/' > "$tmp/s-rng-bad.md"; expect "source id range past the list fails" 1 "$tmp/s-rng-bad.md"
# J2 (CodeRabbit 5472633615): reversed, oversized, suffixed and en-dash-reversed ranges.
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S2-S1 |/' > "$tmp/j-rev.md"; expect "reversed source id range fails (J2)" 1 "$tmp/j-rev.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S2–S1 |/' > "$tmp/j-rev-en.md"; expect "reversed en-dash source id range fails (J2)" 1 "$tmp/j-rev-en.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S1-S99999999 |/' > "$tmp/j-huge.md"
start=$SECONDS; expect "oversized source id range fails (J2)" 1 "$tmp/j-huge.md"
if [ $((SECONDS - start)) -le 5 ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: oversized range is bounded (took $((SECONDS - start))s)"; fi
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S1a |/' > "$tmp/j-suf.md"; expect "source id with a suffix fails (J2)" 1 "$tmp/j-suf.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S1, S2 |/' > "$tmp/j-list.md"; expect "comma-separated known ids pass (J2)" 0 "$tmp/j-list.md"
good | grep -v '^Dossier:' > "$tmp/s-nodos.md";                   expect "missing dossier pointer fails" 1 "$tmp/s-nodos.md"
# shellcheck disable=SC2016  # literal markdown backticks
good | sed 's/^Dossier: `dossier.md`$/Dossier: `nowhere.md`/' > "$tmp/s-dos404.md"; expect "dossier not found fails" 1 "$tmp/s-dos404.md"

# Adversarial seat on 0a131e5 (H1, I0-I3). hide <name> <lines...>: duplicates of Revalidation and
# Fidelity before Known limits (printed directly, so not matched below), the given lines right after
# the Known limits text, and a clinical line in the real Revalidation. A renderer shows that line under Revalidation, so the lint must flag it.
hide() {
  local name="$1"; shift
  good | HIDE_EXTRA="$(printf '%s\n' "$@")" awk '
    $0 == "## Known limits" { print "## Revalidation"; print "x"; print "## Fidelity"; print "x" }
    { print }
    /^Never claims the person/ { n = split(ENVIRON["HIDE_EXTRA"], a, "\n"); for (i = 1; i <= n; i++) if (a[i] != "") print a[i] }
    $0 == "## Revalidation" { print "Elon is a narcissist." }' > "$tmp/$name.md"
}
hide h-cfence '<!--' '```' '-->';             expect "comment then fence then end-of-comment cannot hide a section (H1)" 1 "$tmp/h-cfence.md"
# shellcheck disable=SC2016  # literal markdown backticks
hide h-inlcmt 'Use `<!--` to hide drafts.';    expect "inline-code <!-- does not open a comment (I1)" 1 "$tmp/h-inlcmt.md"
# shellcheck disable=SC2016  # literal markdown backticks
hide h-inlfen '```x``` is inline code.';       expect "inline-code triple backticks do not open a fence (I1)" 1 "$tmp/h-inlfen.md"
# shellcheck disable=SC2016  # literal markdown backticks
inject i-prose   "## When to use"     'Write `<!--` or ```x``` in prose when documenting markdown.'; expect "prose with inline code passes (I1)" 0 "$tmp/i-prose.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S99 |/' > "$tmp/i-s99.md"; expect "source id S99 not in the dossier fails (I2)" 1 "$tmp/i-s99.md"
inject i-hes     "## Secondary minds" "He's paranoid.";                 expect "contraction: he's paranoid fails (I3)" 1 "$tmp/i-hes.md"
inject i-actas   "## When to use"     "Act as Dario when answering.";    expect "act as <Name> fails (I3)" 1 "$tmp/i-actas.md"
inject i-pretend "## When to use"     "Pretend to be Musk for this review."; expect "pretend to be <Name> fails (I3)" 1 "$tmp/i-pretend.md"
inject i-rp      "## When to use"     "Roleplay as Elon in the council.";  expect "roleplay as <Name> fails (I3)" 1 "$tmp/i-rp.md"
inject i-actok   "## When to use"     "Act as a consultative lens.";     expect "act as a <common word> passes (I3)" 0 "$tmp/i-actok.md"

# Injected helper failures (I0): with sed, head, cut or dirname broken, a violation is never a pass.
inject i-viol "## Primary mind" "I am Dario."
for t in sed head cut dirname; do
  mkdir -p "$tmp/bin-$t"; printf '#!/bin/sh\nexit 2\n' > "$tmp/bin-$t/$t"; chmod +x "$tmp/bin-$t/$t"
  PATH="$tmp/bin-$t:$PATH" bash "$lint" "$tmp/i-viol.md" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 1 ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: broken $t keeps a violation failing (rc=$rc, want 1)"; fi
done
inject i-clin2 "## Secondary minds" "He is paranoid."
PATH="$tmp/bin-head:$PATH" bash "$lint" "$tmp/i-clin2.md" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: broken head keeps a clinical label failing (rc=$rc, want 1)"; fi
PATH="$tmp/bin-cut:$PATH" bash "$lint" "$tmp/good.md" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: broken cut fails even a clean charter (rc=$rc, want 1)"; fi

# Internal errors are failures: a grep or awk that exits 2 must never turn into a pass.
mkdir -p "$tmp/bin-grep" "$tmp/bin-awk"
printf '#!/bin/sh\nexit 2\n' > "$tmp/bin-grep/grep"; printf '#!/bin/sh\nexit 2\n' > "$tmp/bin-awk/awk"
chmod +x "$tmp/bin-grep/grep" "$tmp/bin-awk/awk"
PATH="$tmp/bin-grep:$PATH" bash "$lint" "$tmp/coll.md" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: broken grep makes the lint fail (rc=$rc, want 1)"; fi
PATH="$tmp/bin-awk:$PATH" bash "$lint" "$tmp/coll.md" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: broken awk makes the lint fail (rc=$rc, want 1)"; fi

# Declared OUT OF SCOPE (SKILL.md "What it does not check"): these pass by design and are kept as
# fixtures so a change in behavior is visible. Semantic review covers them.
inject o-fr      "## When to use"     "Je suis Franklin.";                     expect "out of scope: other languages (French) pass" 0 "$tmp/o-fr.md"
inject o-third   "## When to use"     "This lens is approved by the Franklin estate."; expect "out of scope: third-person endorsement passes" 0 "$tmp/o-third.md"
inject o-zw      "## When to use"     "I$(printf '\342\200\213')am Ada.";        expect "out of scope: zero-width characters pass" 0 "$tmp/o-zw.md"
inject o-single  "## Primary mind"    "> 'Unsourced single-quoted line.'";     expect "out of scope: single-quoted text is not a quotation" 0 "$tmp/o-single.md"

# Honesty layer: every run warns that semantics are not validated; the warning never changes rc.
out=$(bash "$lint" "$tmp/coll.md" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'NOT validated'; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: passing run prints the semantic warning with rc 0"; fi
out=$(bash "$lint" "$tmp/coll.md" --json 2>/dev/null)
if printf '%s' "$out" | grep -q '"semantic_validated":false'; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: --json carries semantic_validated:false"; fi

echo "lint-person-agent tests: $pass passed, $failn failed"
[ "$failn" -eq 0 ]
