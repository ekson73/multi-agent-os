#!/usr/bin/env bash
# lint-person-agent.sh — deterministic floor for person-agent charters.
# Usage: lint-person-agent.sh <agent.md> [--json]
# Exit: 0 pass · 1 one or more checks failed (or an internal tool error) · 2 usage / unreadable input.
#
# Scope: this script checks only what is objectively checkable (structure, placeholders, quote
# source markers, a NON-EXHAUSTIVE list of forbidden words and a bounded list of first-person and
# endorsement patterns). It does NOT validate personification or endorsement semantically: a
# charter that passes can still speak as the person in words this list does not know. That part
# needs an independent review (see SKILL.md, "Merge gate"). Every run says so.
set -uo pipefail

# Byte semantics everywhere: no locale-dependent ranges, same result on macOS and glibc.
export LC_ALL=C

WARNING="WARNING: semantic personification/endorsement is NOT validated by this script; an independent review is required before merge."

json=0
file=""
for arg in "$@"; do
  case "$arg" in
    --json) json=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) file="$arg" ;;
  esac
done

if [ -z "$file" ] || [ ! -r "$file" ]; then
  echo "usage: lint-person-agent.sh <agent.md> [--json]" >&2
  exit 2
fi

failures=()
fail() { failures+=("$1"); }
tmp="$(mktemp -d)" || { echo "lint error: mktemp failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT

# Normalized view, one row per line:
#   NR <TAB> section <TAB> blockquote? <TAB> unsourced-quote? <TAB> lowered text <TAB> original-case text
# The two text columns have every SOURCED quote span replaced by "" (see below); everything else stays.
# Markdown prefixes are stripped (indent, '>' at any depth, list markers, emphasis, backticks).
# Code-fence lines and HTML-comment lines are scanned like any other line, but a "## " heading inside a
# fence or a comment neither changes the current section nor counts as a section (headings file).
# Curly double quotes and guillemets become straight double quotes; curly apostrophes become "'".
#
# A quote span is a pair of double quotes. It is SOURCED when a source marker (" — <x>" or " -- <x>",
# <x> starting with a letter or digit) follows it directly, or when it ends a blockquote line and the
# next blockquote line starts with that marker. Only sourced spans are exempt from the voice checks.
awk -v headings="$tmp/headings" '
  function fence_run(x,   c, n) {          # length of a leading ``` / ~~~ run (>=3), else 0
    c = substr(x, 1, 1)
    if (c != "`" && c != "~") return 0
    n = 0
    while (substr(x, n + 1, 1) == c) n++
    return (n >= 3) ? n : 0
  }
  {
    raw = $0
    u = raw; sub(/^ ? ? ?/, "", u)            # up to three spaces of indent
    infence_start = infence; incomment_start = incomment
    if (!infence) {
      r = fence_run(u)
      if (r) { infence = 1; fch = substr(u, 1, 1); flen = r; isfence = 1 } else isfence = 0
    } else {
      r = fence_run(u); rest = substr(u, r + 1)
      if (r && substr(u, 1, 1) == fch && r >= flen && rest ~ /^[ \t]*$/) { infence = 0; isfence = 1 } else isfence = 0
    }
    if (!infence_start && !isfence) {           # HTML comments only outside code fences
      x = raw
      while (1) {
        if (incomment) { i = index(x, "-->"); if (!i) break; incomment = 0; x = substr(x, i + 3) }
        else           { i = index(x, "<!--"); if (!i) break; incomment = 1; x = substr(x, i + 4) }
      }
    }
    if (!infence_start && !isfence && !incomment_start && raw ~ /^## /) {
      section = substr(raw, 4); h = raw; sub(/[ \t]+$/, "", h); print h > headings
    }
    t = raw
    if (isfence) { sub(/^[ \t]*(`+|~+)/, "", t) }   # keep the info string, drop the fence run
    gsub(/\t/, " ", t)
    sub(/^[ \t]+/, "", t)
    bq = 0
    while (t ~ /^>/) { bq = 1; sub(/^>[ \t]*/, "", t) }
    sub(/^([-*+]|[0-9]+[.)])[ \t]+/, "", t)
    gsub(/[*_`]/, "", t)
    gsub(/\342\200\234|\342\200\235|\302\253|\302\273/, "\"", t)   # curly double quotes, guillemets
    gsub(/\342\200\230|\342\200\231/, "\047", t)                   # curly single quotes
    n++; ROWNR[n] = NR; SEC[n] = section; BQ[n] = bq; TXT[n] = t
  }
  END {
    marker = "^ *(\342\200\224|--) *[A-Za-z0-9]"
    for (k = 1; k <= n; k++) {
      t = TXT[k]; out = ""; unsourced = 0
      while ((p = index(t, "\"")) > 0) {
        rest = substr(t, p + 1); q = index(rest, "\"")
        if (!q) { unsourced = 1; out = out t; t = ""; break }   # unmatched quote character
        span = substr(t, p, q + 1); after = substr(rest, q + 1)
        src = (after ~ marker)
        if (!src && BQ[k] && after ~ /^[ .,;:!?]*$/ && k < n && BQ[k + 1] && TXT[k + 1] ~ marker) src = 1
        out = out substr(t, 1, p - 1) (src ? "\"\"" : span)
        if (!src) unsourced = 1
        t = after
        if (after ~ marker) break   # the rest is the source text (titles may be quoted); still scanned
      }
      out = out t
      print ROWNR[k] "\t" SEC[k] "\t" BQ[k] "\t" (BQ[k] ? unsourced : 0) "\t" tolower(out) "\t" out
    }
  }' "$file" > "$tmp/norm" || fail "lint error: awk normalization failed"
: >> "$tmp/headings" || fail "lint error: cannot write headings file"

# Column files, built once; a failure here is an internal error, never "no match".
cut -f1 "$tmp/norm" > "$tmp/nr"   || fail "lint error: cut failed (line numbers)"
cut -f5 "$tmp/norm" > "$tmp/low"  || fail "lint error: cut failed (lowered text)"
awk -F'\t' '$2 != "Known limits" { print $1 "\t" $5 }' "$tmp/norm" > "$tmp/low_nolimits" \
  || fail "lint error: awk failed (Known limits filter)"

# match <regex> — first matching source line number on the lowered column, or empty. A grep error
# (rc >= 2, e.g. a regex the platform cannot compile) is reported as ERRn and becomes a FAIL.
match() {
  local out rc
  out=$(grep -nE -- "$1" "$tmp/low"); rc=$?
  if [ "$rc" -ge 2 ]; then echo "ERR$rc"; return; fi
  [ -n "$out" ] && sed -n "$(printf '%s' "$out" | head -1 | cut -d: -f1)p" "$tmp/nr"
}
# match_outside_limits <regex> — same, skipping rows whose section is "Known limits".
match_outside_limits() {
  local out rc
  out=$(grep -E -- "$1" "$tmp/low_nolimits"); rc=$?
  if [ "$rc" -ge 2 ]; then echo "ERR$rc"; return; fi
  printf '%s' "$out" | head -1 | cut -f1
}
# report <message> <line-or-ERRn> — runs in the main shell, so a grep error inside the command
# substitution still reaches the failure list.
report() {
  case "$2" in
    "") ;;
    ERR*) fail "lint error: grep rc=${2#ERR} while checking: $1" ;;
    *) fail "$1 (line $2)" ;;
  esac
}

# 1. Required sections: every "## " section of references/charter-template.md, as a heading OUTSIDE
#    code fences and HTML comments (order is not checked; extra sections are allowed).
for h in "## Identity boundary" "## Primary mind" "## Secondary minds" "## Method (M.O.)" \
         "## Signature questions" "## Positive traits (with behavioral evidence)" \
         "## In their own words (verbatim, sourced)" "## When to use" "## Known limits" \
         "## Revalidation" "## Fidelity"; do
  grep -qxF -- "$h" "$tmp/headings"; rc=$?
  [ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
  [ "$rc" -eq 0 ] || fail "missing section: $h"
done

# 2. Fidelity table header.
grep -qE '^\| *Field *\| *Status *\|' "$file"; rc=$?
[ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
[ "$rc" -eq 0 ] || fail "missing fidelity table (| Field | Status | ...)"

# 3. First person, role-play and endorsement — bounded pattern list (lowered text, sourced quote
#    spans removed, every section, every markdown prefix). Not a semantic check.
B='(^|[^a-z])'
E='([^a-z]|$)'
APPROVE='(approve|approved|endorse|endorsed|authori[sz]e|authori[sz]ed|vouch for|vouched for|sign off|signed off|certify|certified|back|backed|support|supported|aprovo|aprovei|endosso|endossei|autorizo|autorizei|apoio|apoiei|assino|assinei)'
n=$(match "${B}(i am|i'm|my name is|eu sou|meu nome é|me chamo)${E}")
report "first-person identity claim" "$n"
n=$(match "${B}(as|speaking as|como) ([^,.]|(mr|mrs|ms|dr|prof|sr|jr)\\.)+(,| here,?) (i|we|eu|nós)${E}")
report "first-person voice as a named person" "$n"
n=$(match "${B}(i|i'd|eu) (think|believe|feel|would|will|want|acho|penso|creio|acredito|quero|vou)${E}")
report "first-person opinion" "$n"
n=$(match "${B}(i|we|eu|nós|i'd|we'd)( would| will| do| did)?(, [^,]+,)? (hereby |fully |strongly |officially )?${APPROVE}${E}")
report "first-person approval/endorsement" "$n"
n=$(match "${B}we,? the [^,.]+,? (hereby |fully |strongly |officially )?${APPROVE}${E}")
report "first-person approval/endorsement (we the X)" "$n"

# 3b. Second-person role-play: "you are <Name>" / "you're <Name>" in any letter case, or
#     "answer as him/her/them". The word after "you are" (or "you are now") is flagged when it starts
#     with a capital, or when it is lowercase and not a common word (stoplist below), a gerund ("-ing")
#     or a participle/adverb ("-ed", "-ly"). Bounded heuristic; see SKILL.md.
n=$(awk -F'\t' '
  BEGIN { split("a an the not no here there this that it free welcome responsible able unable also only still just now to in on at with for about likely probably sure right wrong", w, " "); for (i in w) stop[w[i]] = 1 }
  {
    lo = $5; oc = $6
    if (lo ~ /(^|[^a-z])answer as (him|her|them)([^a-z]|$)/) { print $1; exit }
    while (match(lo, /(^|[^a-z])you('"'"'re| are)( now)? [^ ]+/)) {
      seg = substr(oc, RSTART, RLENGTH); wd = seg; sub(/.* /, "", wd); gsub(/[^A-Za-z]/, "", wd)
      lw = tolower(wd)
      if (wd != "" && !(lw in stop) && (wd ~ /^[A-Z]/ || lw !~ /(ing|ed|ly)$/)) { print $1; exit }
      lo = substr(lo, RSTART + RLENGTH); oc = substr(oc, RSTART + RLENGTH)
    }
  }' "$tmp/norm") || fail "lint error: awk role-play check failed"
report "second-person role-play instruction" "$n"

# 4. A blockquote line that contains a double-quote span needs a source marker for EACH span (see the
#    normalization note). Checks presence only: whether the source id exists in the dossier is not
#    verified here. Single-quoted text is not treated as a quotation.
n=$(awk -F'\t' '$4 == 1 { print $1; exit }' "$tmp/norm") || fail "lint error: awk quote check failed"
report "quote without source marker" "$n"

# 5. Clinical / diagnostic vocabulary outside "## Known limits" (NON-EXHAUSTIVE list).
n=$(match_outside_limits "${B}(narcissis|psychopath|sociopath|bipolar|autis|asperger|adhd${E}|ocd${E}|personality disorder|psychotic|psychosis|manic${E}|megaloman|schizo|paranoia|paranoid (personality|disorder|schizo)|(is|was|clinically) paranoid${E}|histrionic|borderline personality|diagnosed with|diagnosis of|mentally ill|on the spectrum|obsessive-compulsive|neurodivergent)")
report "clinical vocabulary outside Known limits" "$n"

# 6. Cultural-semiotic inputs (NON-EXHAUSTIVE list) may be named only in Known limits.
n=$(match_outside_limits "${B}(zodiac|horoscop|astrolog|numerolog|tarot|life path|star sign|signo${E}|aries${E}|taurus${E}|gemini sign|cancer sign|leo${E}|virgo${E}|libra${E}|scorpio${E}|sagittarius${E}|capricorn${E}|aquarius${E}|pisces${E})")
report "cultural input outside Known limits" "$n"

# 7. Unfilled template placeholders (<Subject>, <exact quote>, <slug>, ...).
out=$(grep -nE '<[A-Za-z][A-Za-z -]*>' "$file"); rc=$?
[ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
n=$(printf '%s' "$out" | head -1 | cut -d: -f1)
report "unfilled template placeholder" "$n"

json_str() { # JSON string escape: backslash, quote, control characters.
  printf '%s' "$1" | awk 'BEGIN { ORS = "" } {
    gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, "\\r")
    if (NR > 1) print "\\n"; print }'
}

echo "$WARNING" >&2
if [ "$json" -eq 1 ]; then
  printf '{"file":"%s","passed":%s,"semantic_validated":false,"warning":"%s","failures":[' \
    "$(json_str "$file")" "$([ ${#failures[@]} -eq 0 ] && echo true || echo false)" "$(json_str "$WARNING")"
  sep=""
  for f in "${failures[@]+"${failures[@]}"}"; do
    printf '%s"%s"' "$sep" "$(json_str "$f")"
    sep=","
  done
  printf ']}\n'
else
  if [ ${#failures[@]} -eq 0 ]; then
    echo "PASS $file (deterministic floor only)"
  else
    echo "FAIL $file"
    printf '  - %s\n' "${failures[@]}"
  fi
fi

[ ${#failures[@]} -eq 0 ]
