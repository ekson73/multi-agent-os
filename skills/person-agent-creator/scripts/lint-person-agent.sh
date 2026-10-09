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

# Every check reads a copy with carriage returns removed, so a CRLF charter is linted like an LF one.
src="$tmp/src"
tr -d '\r' < "$file" > "$src" || fail "lint error: tr failed (CR normalization)"

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
    infence_start = infence; incomment_start = incomment; isfence = 0
    # Fences and comments exclude each other, as in a markdown renderer: inside a fence "<!--" is
    # text; inside a comment a fence run is text. A fence opens only at the start of a line, and a
    # backtick fence whose info string contains a backtick is inline code, not a fence.
    if (infence) {
      r = fence_run(u); rest = substr(u, r + 1)
      if (r && substr(u, 1, 1) == fch && r >= flen && rest ~ /^[ \t]*$/) { infence = 0; isfence = 1 }
    } else {
      if (!incomment) {
        r = fence_run(u); rest = substr(u, r + 1)
        if (r && !(substr(u, 1, 1) == "`" && index(rest, "`"))) { infence = 1; fch = substr(u, 1, 1); flen = r; isfence = 1 }
      }
      if (!isfence) {                           # comment markers, outside inline code spans
        x = raw
        while (match(x, /`+/)) {                 # drop each inline code span (a run and its closing run)
          run = substr(x, RSTART, RLENGTH); pre = substr(x, 1, RSTART - 1); post = substr(x, RSTART + RLENGTH)
          j = index(post, run); if (!j) break
          x = pre " " substr(post, j + length(run))
        }
        while (1) {
          if (incomment) { i = index(x, "-->"); if (!i) break; incomment = 0; x = substr(x, i + 3) }
          else           { i = index(x, "<!--"); if (!i) break; incomment = 1; x = substr(x, i + 4) }
        }
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
  }' "$src" > "$tmp/norm" || fail "lint error: awk normalization failed"
: >> "$tmp/headings" || fail "lint error: cannot write headings file"

# Column files, built once; a failure here is an internal error, never "no match".
cut -f1 "$tmp/norm" > "$tmp/nr"   || fail "lint error: cut failed (line numbers)"
cut -f5 "$tmp/norm" > "$tmp/low"  || fail "lint error: cut failed (lowered text)"
awk -F'\t' '$2 != "Known limits" { print $1 "\t" $5 }' "$tmp/norm" > "$tmp/low_nolimits" \
  || fail "lint error: awk failed (Known limits filter)"

# match <regex> — first matching source line number on the lowered column, or empty. A grep error
# (rc >= 2, e.g. a regex the platform cannot compile) is reported as ERRn and becomes a FAIL.
match() {
  local out rc ln nr
  out=$(grep -nE -- "$1" "$tmp/low"); rc=$?
  if [ "$rc" -ge 2 ]; then echo "ERRgrep$rc"; return; fi
  [ -n "$out" ] || return
  ln=${out%%:*}                                    # first match, bash expansion (no head/cut/sed)
  nr=$(awk -v n="$ln" 'NR == n { print; exit }' "$tmp/nr"); rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$nr" ]; then echo "ERRawk$rc"; return; fi
  echo "$nr"
}
# match_outside_limits <regex> [file] — same, skipping rows whose section is "Known limits"
# (default file: every row outside Known limits, as "NR <TAB> lowered text").
match_outside_limits() {
  local out rc first
  out=$(grep -E -- "$1" "${2:-$tmp/low_nolimits}"); rc=$?
  if [ "$rc" -ge 2 ]; then echo "ERRgrep$rc"; return; fi
  [ -n "$out" ] || return
  first=${out%%$'\n'*}
  echo "${first%%$'\t'*}"
}
# report <message> <line-or-ERRn> — runs in the main shell, so a grep error inside the command
# substitution still reaches the failure list.
report() {
  case "$2" in
    "") ;;
    ERR*) fail "lint error: helper failed (${2#ERR}) while checking: $1" ;;
    *) fail "$1 (line $2)" ;;
  esac
}

# 1. Required sections: every "## " heading of references/charter-template.md (read at run time, so the
#    template is the single source of truth), as a heading OUTSIDE code fences and HTML comments in the
#    charter (order is not checked; extra sections are allowed). A missing or unreadable template is
#    an internal error, never "nothing required".
template="$(cd "$(dirname "$0")" && pwd)/../references/charter-template.md" || fail "lint error: cannot resolve template path"
required=$(awk '/^(```|~~~)/ { f = !f; next } !f && /^## / { sub(/[ \t]+$/, ""); print }' "$template" 2>/dev/null); rc=$?
if [ "$rc" -ne 0 ] || [ -z "$required" ]; then
  fail "lint error: cannot read required sections from $template"
else
  while IFS= read -r h; do
    grep -qxF -- "$h" "$tmp/headings"; rc=$?
    [ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
    [ "$rc" -eq 0 ] || fail "missing section: $h"
  done <<< "$required"
fi

# 2. Fidelity table header.
grep -qE '^\| *Field *\| *Status *\|' "$src"; rc=$?
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
n=$(match "${B}(i|we|eu|nós|i'd|we'd|i've|we've|i'll|we'll)( would| will| do| did| have| had)?(, [^,]+,)? (hereby |fully |strongly |officially )?${APPROVE}${E}")
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
    l2 = lo; o2 = oc                           # "act as / pretend to be / roleplay as / impersonate / channel /
                                               #  become [the] <Capitalized name>"
    while (match(l2, /(^|[^a-z])((act|acting|pretend|pretending|role-?play|role-?playing) (as|to be|you are)|impersonate|impersonating|channel|channeling|channelling|become|becoming)( the)? [^ ]+/)) {
      seg = substr(o2, RSTART, RLENGTH); wd = seg; sub(/.* /, "", wd); gsub(/[^A-Za-z]/, "", wd)
      if (wd ~ /^[A-Z]/ && !(tolower(wd) in stop)) { print $1; exit }
      l2 = substr(l2, RSTART + RLENGTH); o2 = substr(o2, RSTART + RLENGTH)
    }
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

# 0. subject_class in the front matter: one of five values. Real-person rules (check 5) apply to
#    living-public, deceased-historical and collective; fictional and non-human subjects may carry
#    labeled clinical vocabulary as literary analysis. Every other check applies to every class.
# The value only counts inside a closed front-matter block: line 1 is "---" and the block ends at the
# FIRST "---" after it. A markdown heading inside that block means the closing line is missing and a
# later "---" (a body rule) closed it, so the block swallowed body sections: that fails.
subject_class=$(awk 'NR == 1 { if ($0 != "---") exit; opened = 1; next }
  $0 == "---" { closed = 1; exit }
  /^#{1,6}([ \t]|$)/ { heading = 1 }
  /^subject_class:/ && v == "" { v = $0; sub(/^subject_class:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); gsub(/"/, "", v) }
  END { if (opened && !closed) print "\002"; else if (heading) print "\003"; else if (closed) print v }' "$src") \
  || fail "lint error: awk subject_class check failed"
case "$subject_class" in
  living-public|deceased-historical|collective|fictional-or-archetypal|non-human-or-abiotic) ;;
  $'\002') fail "front matter has no closing ---" ;;
  $'\003') fail "front matter contains a markdown heading (closing --- missing or misplaced)" ;;
  "") fail "missing subject_class in front matter" ;;
  *) fail "unknown subject_class: $subject_class" ;;
esac

# 5. Clinical / diagnostic vocabulary outside "## Known limits" (NON-EXHAUSTIVE list), for EVERY class:
#    the class is declared by the author, so it never switches the check off. The only extra exemption
#    is a line that carries the class label itself: "Literary analysis:" for fictional-or-archetypal,
#    "Metaphor:" or "As a metaphor," for non-human-or-abiotic. Whether such a labeled line is really about
#    a character or a metaphor (and not about a real person) is semantic: the merge gate decides it.
case "$subject_class" in
  fictional-or-archetypal) label='^literary analysis:' ;;
  non-human-or-abiotic)    label='^(metaphor:|as a metaphor,)' ;;
  *)                       label='' ;;
esac
awk -F'\t' -v label="$label" 'label == "" || $2 !~ label' "$tmp/low_nolimits" > "$tmp/low_clinical" \
  || fail "lint error: awk failed (class label filter)"
n=$(match_outside_limits "${B}(narcissis|psychopath|sociopath|bipolar|autis|asperger|adhd${E}|ocd${E}|personality disorder|psychotic|psychosis|manic${E}|megaloman|schizo|paranoia|paranoid (personality|disorder|schizo)|(is|was|clinically) paranoid${E}|[a-z]+'s paranoid${E}|histrionic|borderline personality|diagnosed with|diagnosis of|mentally ill|on the spectrum|obsessive-compulsive|neurodivergent)" "$tmp/low_clinical")
report "clinical vocabulary outside Known limits" "$n"

# 5b. Class basis: a fictional-or-archetypal or non-human-or-abiotic charter states, on a line starting
#     with "Class basis:", why it is in that class (the work and its creator, or the metaphor) with at
#     least one dossier source id. The id is checked against the dossier with the other ids (check 8).
class_basis=""
case "$subject_class" in
  fictional-or-archetypal|non-human-or-abiotic)
    class_basis=$(awk -F'\t' 'tolower($6) ~ /^class basis:/ { v = $6; sub(/^[^:]*:[ \t]*/, "", v); print v; exit }' "$tmp/norm") \
      || fail "lint error: awk class basis check failed"
    if [ -z "$class_basis" ]; then fail "missing Class basis line for subject_class $subject_class"
    else
      case "$class_basis" in *S[0-9]*) ;; *) fail "Class basis cites no dossier source id (S<n>)" ;; esac
    fi ;;
esac

# 6. Cultural-semiotic inputs (NON-EXHAUSTIVE list) may be named only in Known limits.
n=$(match_outside_limits "${B}(zodiac|horoscop|astrolog|numerolog|tarot|life path|star sign|signo${E}|aries${E}|taurus${E}|gemini sign|cancer sign|leo${E}|virgo${E}|libra${E}|scorpio${E}|sagittarius${E}|capricorn${E}|aquarius${E}|pisces${E})")
report "cultural input outside Known limits" "$n"

# 7. Unfilled template placeholders (<Subject>, <exact quote>, <slug>, ...).
out=$(grep -nE '<[A-Za-z][A-Za-z -]*>' "$src"); rc=$?
[ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
n=""; [ -n "$out" ] && n=${out%%:*}
report "unfilled template placeholder" "$n"

# 8. Source ids. Every id cited in the Fidelity table (S1, S2, ... and ranges S1-S7 / S1–S7) must be
#    a source row ("| Sn |") of the dossier named on the "Dossier: `<path>`" line. The path is looked
#    up from the charter's directory upwards. Checks existence of the id, not what the source says.
# shellcheck disable=SC2016  # backticks are literal markdown, not expansions
dossier_line=$(grep -m1 -E '^Dossier: `[^`]+`' "$src"); rc=$?
[ "$rc" -le 1 ] || fail "lint error: grep rc=$rc (dossier pointer)"
dossier_rel=""
if [ -n "$dossier_line" ]; then dossier_rel=${dossier_line#Dossier: \`}; dossier_rel=${dossier_rel%%\`*}; fi
if [ -z "$dossier_rel" ]; then
  fail "missing dossier pointer (Dossier: \`<path>\`)"
else
  dossier=""; d="$(cd "$(dirname "$file")" && pwd)" || fail "lint error: cannot resolve charter directory"
  while [ -n "$d" ]; do
    if [ -f "$d/$dossier_rel" ]; then dossier="$d/$dossier_rel"; break; fi
    [ "$d" = "/" ] && break
    d="$(dirname "$d")" || { fail "lint error: dirname failed"; break; }
  done
  if [ -z "$dossier" ]; then
    fail "dossier not found: $dossier_rel"
  else
    known=$(awk -F'|' '/^\| *S[0-9]+ *\|/ { x = $2; gsub(/[ S]/, "", x); print x }' "$dossier") \
      || fail "lint error: awk dossier id check failed"
    max=0; for k in $known; do [ "$k" -gt "$max" ] && max=$k; done
    # Ranges are expanded only up to the highest dossier id, so a huge span cannot loop forever;
    # a reversed range or an id with a suffix (S1a) is reported, never silently skipped.
    cited=$(awk -F'\t' '$2 == "Fidelity" { print $6 }' "$tmp/norm" | awk -v max="$max" '
      { s = $0
        while (match(s, /S[0-9]+ *(-|\342\200\223) *S?[0-9]+[A-Za-z]*|S[0-9]+[A-Za-z]*/)) {
          t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
          if (t ~ /[A-RT-Za-z]/) { gsub(/ /, "", t); print "bad:" t; continue }
          gsub(/\342\200\223/, "-", t); gsub(/[ S]/, "", t)
          if (index(t, "-")) {
            split(t, r, "-"); a = r[1] + 0; b = r[2] + 0
            if (a > b) { print "rev:S" a "-S" b; continue }
            for (i = a; i <= b && i <= max; i++) print i
            if (b > max) print b
          } else print t + 0
        } }') || fail "lint error: awk cited id check failed"
    # Class basis ids (check 5b) are checked against the same list.
    if [ -n "$class_basis" ]; then
      basis_ids=$(printf '%s\n' "$class_basis" | awk '{ s = $0; while (match(s, /S[0-9]+/)) { print substr(s, RSTART + 1, RLENGTH - 1) + 0; s = substr(s, RSTART + RLENGTH) } }') \
        || fail "lint error: awk class basis id check failed"
      for id in $basis_ids; do
        printf '%s\n' "$known" | grep -qx -- "$id"; rc=$?
        [ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
        [ "$rc" -eq 0 ] || { fail "Class basis source id S$id is not in the dossier source list"; break; }
      done
    fi
    for id in $cited; do
      case "$id" in
        bad:*) fail "malformed source id: ${id#bad:}"; break ;;
        rev:*) fail "reversed source id range: ${id#rev:}"; break ;;
      esac
      printf '%s\n' "$known" | grep -qx -- "$id"; rc=$?
      [ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
      [ "$rc" -eq 0 ] || { fail "source id S$id is not in the dossier source list"; break; }
    done
  fi
fi

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
