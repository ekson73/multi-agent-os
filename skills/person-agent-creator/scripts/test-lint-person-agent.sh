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
json_ok() { # validate JSON on stdin with whatever validator exists
  if command -v python3 >/dev/null 2>&1; then python3 -c 'import json,sys; json.load(sys.stdin)'
  else jq -e . >/dev/null; fi
}
skipn=0
if ! command -v python3 >/dev/null 2>&1 && ! command -v jq >/dev/null 2>&1; then
  skipn=$((skipn+1)); echo "SKIP: --json validity (no python3/jq in this environment)"   # environment gap, not a lint failure
elif bash "$lint" "$tmp/bad\"name.md" --json 2>/dev/null | json_ok 2>/dev/null; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: --json output is valid JSON for a quoted filename"; fi

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
klass() { # klass <class>: fictional and non-human charters carry the required Class basis line (check 5b)
  case "$1" in
    fictional-or-archetypal|non-human-or-abiotic)
      good | sed "s/^subject_class: living-public$/subject_class: $1/" | awk '{print} $0=="## Identity boundary" {print "Class basis: Example Essay (S1)."}' ;;
    *) good | sed "s/^subject_class: living-public$/subject_class: $1/" ;;
  esac
}
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
# The rc AND the "lint error" message are asserted: a FAIL for another reason would hide the bug.
out=$(PATH="$tmp/bin-grep:$PATH" bash "$lint" "$tmp/coll.md" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'lint error'; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: broken grep makes the lint fail with 'lint error' (rc=$rc, want 1)"; fi
out=$(PATH="$tmp/bin-awk:$PATH" bash "$lint" "$tmp/coll.md" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'lint error'; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: broken awk makes the lint fail with 'lint error' (rc=$rc, want 1)"; fi
out=$(PATH="$tmp/bin-awk:$PATH" bash "$lint" "$tmp/coll.md" --json 2>&1); rc=$?
if [ "$rc" -eq 1 ] && ! printf '%s' "$out" | grep -q '"passed":true'; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: broken awk never yields JSON passed:true (rc=$rc)"; fi

# Addendum L: a failing dirname or json_str must fail even a clean charter, with "lint error".
out=$(PATH="$tmp/bin-dirname:$PATH" bash "$lint" "$tmp/good.md" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'lint error'; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: broken dirname fails a clean charter with 'lint error' (rc=$rc, want 1)"; fi
realawk=$(command -v awk); mkdir -p "$tmp/bin-jsonawk"
printf '#!/bin/sh\ncase "$*" in *"ORS = \\"\\""*) exit 2;; esac\nexec "%s" "$@"\n' "$realawk" > "$tmp/bin-jsonawk/awk"; chmod +x "$tmp/bin-jsonawk/awk"
out=$(PATH="$tmp/bin-jsonawk:$PATH" bash "$lint" "$tmp/good.md" --json 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'lint error' && ! printf '%s' "$out" | grep -q '"passed":true'; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: a failing json_str fails --json with 'lint error' (rc=$rc, want 1)"; fi

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

# Final adversarial round on PR #483 (head 6c16de67): class laundering, front matter swallowing the
# body, contractions and more role-play verbs, CRLF. Each case below passed (or wrongly failed) there.
laund() { klass fictional-or-archetypal | awk -v l="$1" '{print} $0=="## Secondary minds" {print l}'; }
laund "Dario is a narcissist and a psychopath." > "$tmp/l-laund.md";        expect "real person reclassified as fictional: clinical line fails" 1 "$tmp/l-laund.md"
klass non-human-or-abiotic | awk '{print} $0=="## Secondary minds" {print "Dario is a narcissist."}' > "$tmp/l-laund-nh.md"; expect "reclassified as non-human: unlabeled clinical line fails" 1 "$tmp/l-laund-nh.md"
laund "The character reads as narcissistic." > "$tmp/l-unlab.md";           expect "fictional: unlabeled clinical line fails" 1 "$tmp/l-unlab.md"
laund "Literary analysis: Holmes reads as narcissistic (S1)." > "$tmp/l-lab.md"; expect "fictional: labeled literary analysis with class basis passes" 0 "$tmp/l-lab.md"
good | sed "s/^subject_class: living-public$/subject_class: fictional-or-archetypal/" > "$tmp/l-nobasis.md"; expect "fictional without Class basis fails" 1 "$tmp/l-nobasis.md"
klass fictional-or-archetypal | sed 's/^Class basis: Example Essay (S1).$/Class basis: Example Essay./' > "$tmp/l-basis-noid.md"; expect "Class basis without a source id fails" 1 "$tmp/l-basis-noid.md"
klass fictional-or-archetypal | sed 's/^Class basis: Example Essay (S1).$/Class basis: Example Essay (S9)./' > "$tmp/l-basis-s9.md"; expect "Class basis citing an unknown source id fails" 1 "$tmp/l-basis-s9.md"
klass collective | awk '{print} $0=="## Secondary minds" {print "Literary analysis: Dario is a narcissist."}' > "$tmp/l-lab-real.md"; expect "real-person class: the literary-analysis label exempts nothing" 1 "$tmp/l-lab-real.md"
{ good | awk 'NR == 4 && $0 == "---" { next } { print }'; echo "---"; echo "Footer."; } > "$tmp/j-body-rule.md"; expect "missing closing --- with a later body rule fails (J1 residual)" 1 "$tmp/j-body-rule.md"
good | awk '{print} NR == 3 {print "# Stray heading"}' > "$tmp/j-fm-head.md"; expect "heading inside front matter fails (J1 residual)" 1 "$tmp/j-fm-head.md"
# Addendum K (usefulness + vendor seats): exact payloads.
collective | awk '{print} $0=="## When to use" {print "<!--"; print "`-->`"; print "```"; print "-->"; print "## Known limits"; print "```"; print "Elon is a narcissist."}' > "$tmp/k-cmtcode.md"
out=$(bash "$lint" "$tmp/k-cmtcode.md" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'clinical vocabulary' && ! printf '%s' "$out" | grep -q 'missing section'; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: backtick inside an open comment does not keep it open (K P2-a)"; fi
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S1S999 |/' > "$tmp/k-s1s999.md"; expect "S1S999 fails (K P2-b regression)" 1 "$tmp/k-s1s999.md"
inject k-meunome "## When to use" "MEU NOME É BENJAMIN.";  expect "accented uppercase 'MEU NOME É' fails (K P2-c)" 1 "$tmp/k-meunome.md"
inject k-meunome2 "## When to use" "Meu Nome É Ben.";     expect "accented mixed case 'Meu Nome É' fails (K P2-c)" 1 "$tmp/k-meunome2.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | s9 |/' > "$tmp/k-s9low.md"; expect "lowercase unknown id s9 fails (K P3)" 1 "$tmp/k-s9low.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | s1, s2 |/' > "$tmp/k-s12low.md"; expect "lowercase known ids pass (K P3)" 0 "$tmp/k-s12low.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | s2-s1 |/' > "$tmp/k-revlow.md"; expect "lowercase reversed range fails (K P3)" 1 "$tmp/k-revlow.md"
for s in "I've approved this lens." "I'll endorse this plan." "We'll sign off on it." "We've vouched for it." "Act as the Dario for this." "Impersonate Dario here." "Channel Dario Amodei." "Become Dario for this review."; do
  inject p3 "## When to use" "$s"; expect "P3: $s fails" 1 "$tmp/p3.md"
done
inject p3ok "## When to use" "Become familiar with the dossier; channel the effort into tests."; expect "P3: benign become/channel passes" 0 "$tmp/p3ok.md"
good | sed 's/$/\r/' > "$tmp/crlf.md";                                     expect "CRLF good charter passes (no spurious missing section)" 0 "$tmp/crlf.md"
{ good | sed 's/$/\r/'; printf 'I am Ada.\r\n'; } > "$tmp/crlf-bad.md";     expect "CRLF charter with a violation fails" 1 "$tmp/crlf-bad.md"
mkdir -p "$tmp/bin-tr"; printf '#!/bin/sh\nexit 2\n' > "$tmp/bin-tr/tr"; chmod +x "$tmp/bin-tr/tr"
PATH="$tmp/bin-tr:$PATH" bash "$lint" "$tmp/good.md" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: broken tr fails even a clean charter (rc=$rc, want 1)"; fi

# Addendum M (final lint lot): one normalization pre-pass, every check on the normalized text.
# Each case below passed (or wrongly failed) on 6c16de6 and on e126e21; exact payloads from round 3.
expect_msg() { # expect_msg <name> <file> <message>: rc 1 AND the message
  local out rc; out=$(bash "$lint" "$2" 2>&1); rc=$?
  if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF -- "$3"; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: $1 (rc=$rc, want 1 + '$3')"; fi
}
hide m-plain 'Plain prose <!-- never closed in this paragraph.';  expect_msg "prose <!-- never closed fails (M a/b)" "$tmp/m-plain.md" "unclosed HTML comment"
# shellcheck disable=SC2016  # literal markdown backtick
hide m-tick 'A stray ` tick then <!-- text.';                     expect_msg "stray tick then <!-- fails (M a/b)" "$tmp/m-tick.md" "unclosed HTML comment"
inject m-fence "## Primary mind" '~~~';                           expect_msg "unterminated fence fails (M b)" "$tmp/m-fence.md" "unterminated code fence"
collective | awk '{print} $0=="## Primary mind" {print "I"; print "am Dario Amodei."}' > "$tmp/m-soft.md"; expect "soft line break 'I / am Dario Amodei.' fails (M c)" 1 "$tmp/m-soft.md"
collective | awk '{print} /^Never claims the person/ {print "# Assessment"; print "Dario is a psychopath."}' > "$tmp/m-h1.md"; expect "H1 after Known limits ends the exemption (M d)" 1 "$tmp/m-h1.md"
good | sed 's/^## Fidelity$/## Fidelity   /; s/^| Primary mind | documented | S1 |$/| Primary mind | documented | S999 |/' > "$tmp/m-fidsp.md"; expect "'## Fidelity   ' (trailing spaces) + S999 fails (M d)" 1 "$tmp/m-fidsp.md"
inject m-emile "## When to use" "Act as Émile Zola when answering.";  expect "Act as Émile Zola fails (M e)" 1 "$tmp/m-emile.md"
klass fictional-or-archetypal | sed 's/^Class basis: Example Essay (S1).$/Class basis: Example Work (S5a)/' > "$tmp/m-b5a.md"; expect_msg "Class basis (S5a) fails (M f)" "$tmp/m-b5a.md" "malformed Class basis source id"
klass fictional-or-archetypal | sed 's/^Class basis: Example Essay (S1).$/Class basis: Example work (S1, s999)/' > "$tmp/m-blow.md"; expect_msg "Class basis (S1, s999) fails (M f)" "$tmp/m-blow.md" "malformed Class basis source id"
klass fictional-or-archetypal | sed 's/^Class basis: Example Essay (S1).$/Class basis: a novel (S2-S1)/' > "$tmp/m-brev.md"; expect_msg "Class basis reversed range fails (M f)" "$tmp/m-brev.md" "reversed Class basis"
klass fictional-or-archetypal | sed 's/^Class basis: Example Essay (S1).$/<!-- Class basis: S1 -->/' > "$tmp/m-bcmt.md"; expect_msg "Class basis hidden in a comment does not count (M f)" "$tmp/m-bcmt.md" "missing Class basis"
# shellcheck disable=SC2016  # literal markdown backticks
klass fictional-or-archetypal | sed 's/^Class basis: Example Essay (S1).$/```Class basis: Example Work (S1)/' | awk '{print} $0 ~ /^```Class basis/ {print "```"}' > "$tmp/m-bfen.md"; expect_msg "Class basis as a fence opener does not count (M f)" "$tmp/m-bfen.md" "missing Class basis"
klass fictional-or-archetypal | awk '$0 ~ /^Class basis:/ {print "```"; print "Class basis: x (S1)"; print "```"; next} {print}' > "$tmp/m-bfen2.md"; expect_msg "Class basis inside a fence does not count (M f)" "$tmp/m-bfen2.md" "missing Class basis"
good | awk '{print} $0=="## Identity boundary" {print "Class basis: Example Essay (S1)."}' > "$tmp/m-bliv.md"; expect_msg "Class basis in a living-public charter fails (M f)" "$tmp/m-bliv.md" "only allowed"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S 99 |/' > "$tmp/m-sp99.md"; expect_msg "'S 99' cell fails (M f)" "$tmp/m-sp99.md" "Source ids cell"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | §3 |/' > "$tmp/m-sec.md"; expect_msg "'§3' cell fails (M f)" "$tmp/m-sec.md" "Source ids cell"
mkdir -p "$tmp/m-dos"
# shellcheck disable=SC2016  # literal markdown backticks
good | sed 's/^Dossier: `dossier.md`$/Dossier: `elon-s9.md`/' > "$tmp/m-dos/m-path.md"; cp "$tmp/dossier.md" "$tmp/m-dos/elon-s9.md"
expect "dossier file name elon-s9.md is not a cited id (M g)" 0 "$tmp/m-dos/m-path.md"
mkdir -p "$tmp/m-dos2"
printf '%s\n' '## 1. Sources' '| id | Source |' '|---|---|' '| S1 | Example Essay |' '```' '| S99 | Fenced row |' '```' '<!--' '| S98 | Commented row |' '-->' > "$tmp/m-dos2/dossier.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S99 |/' > "$tmp/m-dos2/m-f99.md"; expect "fenced dossier row S99 is not a source (M g)" 1 "$tmp/m-dos2/m-f99.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S98 |/' > "$tmp/m-dos2/m-c98.md"; expect "commented dossier row S98 is not a source (M g)" 1 "$tmp/m-dos2/m-c98.md"
good | awk 'NR == 4 && $0 == "---" { print "Some intro."; print "---"; next } { print }' > "$tmp/m-hrbody.md"; expect_msg "unclosed front matter closed by a later --- after prose fails (J1)" "$tmp/m-hrbody.md" "not YAML"
good | awk 'NR == 3 { print; print "#comment"; next } { print }' > "$tmp/m-yamlc.md"; expect "YAML '#comment' in front matter passes (J1)" 0 "$tmp/m-yamlc.md"

# Addendum N (last lint lot, round 4 on 6dc55c9): fail-closed cuts, exact reported payloads. Each case
# below passed (rc 0) on 6dc55c9.
s999() { sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S999 |/'; }
# 1. Nothing to check is a failure (Fidelity table and Class basis).
good | s999 | sed 's/^| Field | Status | Source ids |$/| Field | Status | Refs |/' > "$tmp/n-refs.md"; expect_msg "Fidelity header '| Field | Status | Refs |' fails (N1)" "$tmp/n-refs.md" "no Source ids column"
good | s999 | sed 's/^| Field | Status | Source ids |$/| Field | Status | Evidence |/' > "$tmp/n-evid.md"; expect_msg "Fidelity header '| Field | Status | Evidence |' + S999 fails (N1)" "$tmp/n-evid.md" "no Source ids column"
good | awk '/^\| Field|^\|---|^\| Primary mind/ { next } { print } $0 == "## Primary mind" { print "| Field | Status | Source ids |"; print "|---|---|---|"; print "| Primary mind | documented | S1 |" } $0 == "## Fidelity" { print "| Primary mind | documented | S999 |" }' > "$tmp/n-outside.md"
expect_msg "Fidelity header outside ## Fidelity fails (N1)" "$tmp/n-outside.md" "outside ## Fidelity"
good | awk '{ print } $0 == "| Primary mind | documented | S1 |" { print ""; print "| Extra | Notes |"; print "|---|---|"; print "| Primary mind | S999 |" }' > "$tmp/n-second.md"
expect_msg "second table in ## Fidelity fails (N1)" "$tmp/n-second.md" "more than one table"
klass fictional-or-archetypal | sed 's|^Class basis: Example Essay (S1).$|Class basis: https://example.org/S999|' > "$tmp/n-url.md"; expect_msg "Class basis with only a URL id fails (N1)" "$tmp/n-url.md" "Class basis cites no dossier source id"
klass fictional-or-archetypal | sed 's|^Class basis: Example Essay (S1).$|Class basis: Example Essay (S1), https://example.org/S999|' > "$tmp/n-url-ok.md"; expect "Class basis with a valid id and a URL passes (N1)" 0 "$tmp/n-url-ok.md"
# 2. Unsupported heading forms inside Known limits.
collective | awk '{ print } /^Never claims the person/ { print "Assessment"; print "==="; print "Dario is a psychopath." }' > "$tmp/n-setext1.md"; expect_msg "setext '===' in Known limits fails (N2)" "$tmp/n-setext1.md" "unsupported heading form"
collective | awk '{ print } /^Never claims the person/ { print "Assessment"; print "---"; print "Dario is a psychopath." }' > "$tmp/n-setext2.md"; expect_msg "setext '---' in Known limits fails (N2)" "$tmp/n-setext2.md" "unsupported heading form"
collective | awk '{ print } /^Never claims the person/ { print "<h2>Assessment</h2>"; print "Dario is a psychopath." }' > "$tmp/n-h2.md"; expect_msg "HTML <h2> in Known limits fails (N2)" "$tmp/n-h2.md" "unsupported heading form"
# 3. A heading or a Fidelity row that contains "<!--".
collective | awk '{ print } /^Never claims the person/ { print "# Assessment <!-- note -->"; print "Dario is a psychopath." }' > "$tmp/n-cmth.md"; expect_msg "'# Assessment <!-- note -->' + clinical line fails (N3)" "$tmp/n-cmth.md" "html comment in heading/table row"
good | awk '{ print } $0 == "| Primary mind | documented | S1 |" { print "| Primary mind (joint) | inferred | S999 | <!-- note -->" }' > "$tmp/n-cmtrow.md"; expect_msg "Fidelity row with <!-- note --> + S999 fails (N3)" "$tmp/n-cmtrow.md" "html comment in heading/table row"
# 4. Whitespace runs collapse in the voice view.
inject n-ws1 "## Primary mind" "I  am Dario Amodei.";              expect "'I  am Dario Amodei.' (double space) fails (N4)" 1 "$tmp/n-ws1.md"
inject n-ws2 "## Secondary minds" "Dario is  paranoid.";            expect "'Dario is  paranoid.' (double space) fails (N4)" 1 "$tmp/n-ws2.md"
collective | awk '{ print } $0 == "## Primary mind" { print "I "; print "am Dario Amodei." }' > "$tmp/n-ws3.md"; expect "'I ⏎am Dario Amodei.' (trailing space soft break) fails (N4)" 1 "$tmp/n-ws3.md"
collective | awk '{ print } $0 == "## Secondary minds" { print "Dario is "; print "paranoid." }' > "$tmp/n-ws4.md"; expect "'Dario is ⏎paranoid.' (trailing space soft break) fails (N4)" 1 "$tmp/n-ws4.md"
inject n-ws5 "## Primary mind" "I$(printf '\t')am Dario Amodei.";   expect "tab between words fails (N4)" 1 "$tmp/n-ws5.md"
inject n-ws6 "## Primary mind" "I$(printf '\302\240')am Dario Amodei."; expect "non-breaking space between words fails (N4)" 1 "$tmp/n-ws6.md"
collective | awk -v nb="$(printf '\302\240')" '{ print } $0 == "## Primary mind" { print "I"; print nb; print "am Dario Amodei." }' > "$tmp/n-ws7.md"; expect "line of only a non-breaking space does not split the sentence (N4)" 1 "$tmp/n-ws7.md"
# 5. Dossier fence: a closing fence is a fence line only.
mkdir -p "$tmp/n-dos"
printf '%s\n' '## 1. Sources' '| id | Source |' '|---|---|' '| S1 | Example Essay |' '```' '````not-a-closer' '| id | Source |' '| S99 | Fenced row |' '```' > "$tmp/n-dos/dossier.md"
good | sed 's/^| Primary mind | documented | S1 |$/| Primary mind | documented | S99 |/' > "$tmp/n-dos/n-f99.md"; expect "'\`\`\`\`not-a-closer' does not close the dossier fence; fenced S99 is not a source (N5)" 1 "$tmp/n-dos/n-f99.md"

echo "lint-person-agent tests: $pass passed, $failn failed, $skipn skipped"
[ "$failn" -eq 0 ]
