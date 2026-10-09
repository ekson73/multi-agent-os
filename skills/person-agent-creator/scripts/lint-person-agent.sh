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

# ---------------------------------------------------------------------------------------------------
# Normalization pre-pass. Every check below reads its output, never the raw markdown.
#
# Two views of the same text:
#   STRUCTURE (column "struct" = 1): lines outside code fences and HTML comments, fence lines excluded.
#     Only these lines can be a heading, a section boundary, a Class basis line or a Fidelity row.
#   VOICE (file "units"): every line, fences and comments included (an agent reads the raw file, so
#     hidden text still reaches the model). Soft line breaks are joined into units, so "I\nam X" is one
#     sentence. A unit is exempt from the clinical and cultural checks only when every line of it is a
#     structure line in "Known limits"; text inside a comment or a fence is never exempt.
#
# Fail-closed rules: an HTML comment ("<!--") that no "-->" closes, or a code fence that never closes,
# fails the lint (the script does not emulate CommonMark's rules for these cases).
# Headings: up to three spaces, 1-6 '#', a space, the text; trailing spaces and closing '#' run are
# trimmed and the text is compared in lower case. A level-1 or level-2 heading starts a new section, so
# a "# X" after "## Known limits" ends Known limits.
# Letters: Latin-1 accented letters are folded to ASCII (É -> E, é -> e, ç -> c, ...) and the voice text
# is lowered, so case and accents do not change any pattern match (same result under C and C.UTF-8).
#
# norm, one row per line:
#   NR <TAB> section(lowered) <TAB> blockquote? <TAB> unsourced-quote? <TAB> lowered text <TAB>
#   folded original-case text <TAB> struct
# A quote span is a pair of double quotes. It is SOURCED when a source marker (" — <x>" or " -- <x>",
# <x> starting with a letter or digit) follows it directly, or when it ends a blockquote line and the
# next blockquote line starts with that marker. Sourced spans become "" in both text columns.
# units: NR-of-first-line <TAB> exempt <TAB> lowered joined text <TAB> folded original-case joined text
# ---------------------------------------------------------------------------------------------------
awk -v headings="$tmp/headings" -v units="$tmp/units" -v flags="$tmp/flags" '
  BEGIN {
    nf = split("128 A 129 A 130 A 131 A 132 A 133 A 134 A 135 C 136 E 137 E 138 E 139 E 140 I 141 I 142 I 143 I 144 D 145 N 146 O 147 O 148 O 149 O 150 O 152 O 153 U 154 U 155 U 156 U 157 Y 159 ss 160 a 161 a 162 a 163 a 164 a 165 a 166 a 167 c 168 e 169 e 170 e 171 e 172 i 173 i 174 i 175 i 176 d 177 n 178 o 179 o 180 o 181 o 182 o 184 o 185 u 186 u 187 u 188 u 189 y 191 y", ft, " ")
    nfold = 0
    for (i = 1; i < nf; i += 2) { nfold++; FFROM[nfold] = sprintf("\303%c", ft[i] + 0); FTO[nfold] = ft[i + 1] }
  }
  function fold(s,   i) {                     # Latin-1 accented letters -> ASCII, case kept
    if (index(s, "\303")) for (i = 1; i <= nfold; i++) if (index(s, FFROM[i])) gsub(FFROM[i], FTO[i], s)
    return s
  }
  function fence_run(x,   c, n) {          # length of a leading ``` / ~~~ run (>=3), else 0
    c = substr(x, 1, 1)
    if (c != "`" && c != "~") return 0
    n = 0
    while (substr(x, n + 1, 1) == c) n++
    return (n >= 3) ? n : 0
  }
  function heading(x,   n, t) {             # level of an ATX heading (0 if none); text in HTEXT
    t = x; sub(/^ ? ? ?/, "", t)
    n = 0
    while (substr(t, n + 1, 1) == "#") n++
    if (n < 1 || n > 6) return 0
    t = substr(t, n + 1)
    if (t != "" && t !~ /^[ \t]/) return 0
    sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t); sub(/[ \t]+#+$/, "", t); sub(/^#+$/, "", t); sub(/[ \t]+$/, "", t)
    HTEXT = tolower(fold(t))
    return n
  }
  {
    raw = $0
    u = raw; sub(/^ ? ? ?/, "", u)            # up to three spaces of indent
    infence_start = infence; incomment_start = incomment; isfence = 0; touched = 0
    # Fences and comments exclude each other: inside a fence "<!--" is text; inside a comment a fence
    # run is text. A fence opens only at the start of a line, and a backtick fence whose info string
    # contains a backtick is inline code, not a fence.
    if (infence) {
      r = fence_run(u); rest = substr(u, r + 1)
      if (r && substr(u, 1, 1) == fch && r >= flen && rest ~ /^[ \t]*$/) { infence = 0; isfence = 1 }
    } else {
      if (!incomment) {
        r = fence_run(u); rest = substr(u, r + 1)
        if (r && !(substr(u, 1, 1) == "`" && index(rest, "`"))) { infence = 1; fch = substr(u, 1, 1); flen = r; isfence = 1 }
      }
      if (!isfence) {                           # comment markers, left to right
        # Outside a comment an inline code span hides "<!--" (it is code). Inside an open comment the
        # text is raw: a backtick there is not code, so "`-->`" still closes it.
        x = raw
        while (1) {
          if (incomment) { i = index(x, "-->"); if (!i) break; incomment = 0; touched = 1; x = substr(x, i + 3); continue }
          i = index(x, "<!--"); if (!i) break
          if (match(x, /`+/) && RSTART < i) {    # a backtick run before the marker: skip its code span
            run = substr(x, RSTART, RLENGTH); post = substr(x, RSTART + RLENGTH)
            j = index(post, run)
            x = j ? substr(post, j + length(run)) : post   # unmatched run is a literal backtick
            continue
          }
          incomment = 1; touched = 1; x = substr(x, i + 4)
        }
      }
    }
    struct = (!infence_start && !isfence && !incomment_start && !incomment && !touched) ? 1 : 0
    hl = struct ? heading(raw) : 0
    if (hl == 1 || hl == 2) section = HTEXT
    if (hl == 2) print "## " HTEXT > headings
    t = fold(raw)
    if (isfence) { sub(/^[ \t]*(`+|~+)/, "", t) }   # keep the info string, drop the fence run
    gsub(/\t/, " ", t)
    sub(/^[ \t]+/, "", t)
    bq = 0
    while (t ~ /^>/) { bq = 1; sub(/^>[ \t]*/, "", t) }
    li = 0
    if (t ~ /^([-*+]|[0-9]+[.)])[ \t]+/) { li = 1; sub(/^([-*+]|[0-9]+[.)])[ \t]+/, "", t) }
    gsub(/[*_`]/, "", t)
    gsub(/\342\200\234|\342\200\235|\302\253|\302\273/, "\"", t)   # curly double quotes, guillemets
    gsub(/\342\200\230|\342\200\231/, "\047", t)                   # curly single quotes
    n++; ROWNR[n] = NR; SEC[n] = section; BQ[n] = bq; TXT[n] = t; ST[n] = struct
    HD[n] = (hl > 0 || (!struct && heading(raw) > 0)); LI[n] = li; FL[n] = isfence
    TB[n] = (t ~ /^\|/)
  }
  END {
    if (incomment) print "unclosed-comment" > flags
    if (infence) print "unclosed-fence" > flags
    printf "" > flags
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
      OUT[k] = out
      print ROWNR[k] "\t" SEC[k] "\t" BQ[k] "\t" (BQ[k] ? unsourced : 0) "\t" tolower(out) "\t" out "\t" ST[k]
    }
    # Voice units: consecutive lines of one paragraph, joined with a space. A blank line, a heading, a
    # fence line, a table row, a list item, a change of blockquote or of exemption, and a line starting
    # with a class label ("Literary analysis:", "Metaphor:", "As a metaphor,") each end the unit; a
    # labeled line is a unit of its own, so a label never covers the next line.
    open = 0
    for (k = 1; k <= n; k++) {
      lo = tolower(OUT[k]); ex = (ST[k] && SEC[k] == "known limits") ? 1 : 0
      lab = (lo ~ /^(literary analysis:|metaphor:|as a metaphor,)/)
      if (lo ~ /^[ \t]*$/) { if (open) flush(); continue }
      single = (HD[k] || FL[k] || TB[k] || lab)
      if (open && (single || LI[k] || BQ[k] != ubq || ex != uex || ulab)) flush()
      if (!open) { open = 1; unr = ROWNR[k]; uex = ex; ubq = BQ[k]; ulab = lab; ulo = lo; uoc = OUT[k] }
      else { ulo = ulo " " lo; uoc = uoc " " OUT[k] }
      if (single) flush()
    }
    if (open) flush()
  }
  function flush() { print unr "\t" uex "\t" ulo "\t" uoc > units; open = 0 }
' "$src" > "$tmp/norm" || fail "lint error: awk normalization failed"
: >> "$tmp/headings" || fail "lint error: cannot write headings file"
: >> "$tmp/units" || fail "lint error: cannot write units file"
: >> "$tmp/flags" || fail "lint error: cannot write flags file"

grep -qx 'unclosed-comment' "$tmp/flags"; rc=$?
[ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
[ "$rc" -eq 0 ] && fail "unclosed HTML comment (<!-- without -->)"
grep -qx 'unclosed-fence' "$tmp/flags"; rc=$?
[ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
[ "$rc" -eq 0 ] && fail "unterminated code fence"

# Column files, built once; a failure here is an internal error, never "no match".
cut -f1 "$tmp/units" > "$tmp/nr"   || fail "lint error: cut failed (line numbers)"
cut -f3 "$tmp/units" > "$tmp/low"  || fail "lint error: cut failed (lowered text)"
awk -F'\t' '$2 == 0 { print $1 "\t" $3 }' "$tmp/units" > "$tmp/low_nolimits" \
  || fail "lint error: awk failed (Known limits filter)"

# match <regex> — first matching source line number on the lowered voice units, or empty. A grep error
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
# match_outside_limits <regex> [file] — same, on units that are not exempt (Known limits)
# (default file: every non-exempt unit, as "NR <TAB> lowered text").
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
#    template is the single source of truth), as a structure heading in the charter, compared after the
#    same heading normalization (order is not checked; extra sections are allowed). A missing or
#    unreadable template is an internal error, never "nothing required".
if ! { sdir=$(dirname "$0") && sdir=$(cd "$sdir" && pwd); }; then fail "lint error: cannot resolve script directory"; sdir=/nonexistent; fi
template="$sdir/../references/charter-template.md"
required=$(awk '/^(```|~~~)/ { f = !f; next } !f && /^## / { sub(/[ \t]+$/, ""); print tolower($0) }' "$template" 2>/dev/null); rc=$?
if [ "$rc" -ne 0 ] || [ -z "$required" ]; then
  fail "lint error: cannot read required sections from $template"
else
  while IFS= read -r h; do
    grep -qxF -- "$h" "$tmp/headings"; rc=$?
    [ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
    [ "$rc" -eq 0 ] || fail "missing section: $h"
  done <<< "$required"
fi

# 2. Fidelity table header, on a structure line.
n=$(awk -F'\t' '$7 == 1 && $5 ~ /^\| *field *\| *status *\|/ { print $1; exit }' "$tmp/norm") \
  || fail "lint error: awk fidelity header check failed"
[ -n "$n" ] || fail "missing fidelity table (| Field | Status | ...)"

# 3. First person, role-play and endorsement — bounded pattern list (voice units: lowered, accents
#    folded, soft breaks joined, sourced quote spans removed, every section, every markdown prefix).
#    Not a semantic check.
B='(^|[^a-z])'
E='([^a-z]|$)'
APPROVE='(approve|approved|endorse|endorsed|authori[sz]e|authori[sz]ed|vouch for|vouched for|sign off|signed off|certify|certified|back|backed|support|supported|aprovo|aprovei|endosso|endossei|autorizo|autorizei|apoio|apoiei|assino|assinei)'
n=$(match "${B}(i am|i'm|my name is|eu sou|meu nome e|me chamo)${E}")
report "first-person identity claim" "$n"
n=$(match "${B}(as|speaking as|como) ([^,.]|(mr|mrs|ms|dr|prof|sr|jr)\\.)+(,| here,?) (i|we|eu|nos)${E}")
report "first-person voice as a named person" "$n"
n=$(match "${B}(i|i'd|eu) (think|believe|feel|would|will|want|acho|penso|creio|acredito|quero|vou)${E}")
report "first-person opinion" "$n"
n=$(match "${B}(i|we|eu|nos|i'd|we'd|i've|we've|i'll|we'll)( would| will| do| did| have| had)?(, [^,]+,)? (hereby |fully |strongly |officially )?${APPROVE}${E}")
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
    lo = $3; oc = $4
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
  }' "$tmp/units") || fail "lint error: awk role-play check failed"
report "second-person role-play instruction" "$n"

# 4. A blockquote line that contains a double-quote span needs a source marker for EACH span (see the
#    normalization note). Checks presence only: whether the source id exists in the dossier is not
#    verified here. Single-quoted text is not treated as a quotation.
n=$(awk -F'\t' '$4 == 1 { print $1; exit }' "$tmp/norm") || fail "lint error: awk quote check failed"
report "quote without source marker" "$n"

# 0. subject_class in the front matter: one of five values. The value only counts inside a closed
#    front-matter block: line 1 is "---" and the block ends at the FIRST "---" after it. Every line of
#    the block must look like YAML (a "key:", an indented continuation, a "- item", a "#comment" without
#    a space, or empty); a markdown heading ("# Title") or plain text means the closing line is missing
#    or misplaced and the block swallowed body lines, so it fails.
subject_class=$(awk 'NR == 1 { if ($0 != "---") exit; opened = 1; next }
  $0 == "---" { closed = 1; exit }
  /^#+([ \t]|$)/ { heading = 1; next }   # no {m,n}: mawk cannot compile it
  !/^$/ && !/^[A-Za-z_][A-Za-z0-9_-]*[ \t]*:/ && !/^[ \t]/ && !/^- / && !/^#/ { prose = 1 }
  /^subject_class:/ && v == "" { v = $0; sub(/^subject_class:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); gsub(/"/, "", v) }
  END { if (opened && !closed) print "\002"; else if (heading) print "\003"; else if (prose) print "\004"; else if (closed) print v }' "$src") \
  || fail "lint error: awk subject_class check failed"
case "$subject_class" in
  living-public|deceased-historical|collective|fictional-or-archetypal|non-human-or-abiotic) ;;
  $'\002') fail "front matter has no closing ---" ;;
  $'\003') fail "front matter contains a markdown heading (closing --- missing or misplaced)" ;;
  $'\004') fail "front matter contains a line that is not YAML (closing --- missing or misplaced)" ;;
  "") fail "missing subject_class in front matter" ;;
  *) fail "unknown subject_class: $subject_class" ;;
esac

# 5. Clinical / diagnostic vocabulary outside "## Known limits" (NON-EXHAUSTIVE list), for EVERY class:
#    the class is declared by the author, so it never switches the check off. The only extra exemption
#    is a unit that starts with the class label itself: "Literary analysis:" for fictional-or-archetypal,
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

# Source-id scanner, shared by check 5b and check 8. An id starts after a character that is not a
# letter, digit, '_', '.', '/' or '-' (so a file name such as "elon-s9.md" is not an id). Output, one per
# line: a number, "bad:<token>" (suffix, glued ids, or lowercase in strict mode) or "rev:<range>".
# Ranges expand only up to the highest dossier id, so a huge span cannot loop forever.
# shellcheck disable=SC2016  # awk program, not a shell expansion
SCAN='{ s = " " $0
  while (match(s, /[^A-Za-z0-9_.\/-][Ss][0-9]+ *(-|\342\200\223) *[Ss]?[0-9]+[A-Za-z0-9]*|[^A-Za-z0-9_.\/-][Ss][0-9]+[A-Za-z0-9]*/)) {
    t = substr(s, RSTART + 1, RLENGTH - 1); s = substr(s, RSTART + RLENGTH)
    if (strict && t ~ /s/) { gsub(/ /, "", t); print "bad:" t; continue }
    t = toupper(t)
    if (t !~ /^S[0-9]+ *(-|\342\200\223) *S?[0-9]+$/ && t !~ /^S[0-9]+$/) { gsub(/ /, "", t); print "bad:" t; continue }
    gsub(/\342\200\223/, "-", t); gsub(/[ S]/, "", t)
    if (index(t, "-")) {
      split(t, r, "-"); a = r[1] + 0; b = r[2] + 0
      if (a > b) { print "rev:S" a "-S" b; continue }
      for (i = a; i <= b && i <= max; i++) print i
      if (b > max) print b
    } else print t + 0
  } }'

# 5b. Class basis: only a fictional-or-archetypal or non-human-or-abiotic charter carries a structure
#     line starting with "Class basis:" (outside fences and comments), stating why it is in that class
#     with at least one dossier source id written strictly as S<digits> (a list or S<a>-S<b> ranges).
#     Any other id form (S5a, s999, glued ids) fails; ids are checked against the dossier in check 8.
#     A Class basis line in any other class fails (the template line must be deleted there).
class_basis=$(awk -F'\t' '$7 == 1 && $5 ~ /^class basis:/ { v = $6; sub(/^[^:]*:[ \t]*/, "", v); print v; exit }' "$tmp/norm") \
  || fail "lint error: awk class basis check failed"
case "$subject_class" in
  fictional-or-archetypal|non-human-or-abiotic)
    if [ -z "$class_basis" ]; then fail "missing Class basis line for subject_class $subject_class"
    else
      case "$class_basis" in *S[0-9]*) ;; *) fail "Class basis cites no dossier source id (S<n>)" ;; esac
    fi ;;
  *) [ -z "$class_basis" ] || fail "Class basis line is only allowed for fictional-or-archetypal and non-human-or-abiotic" ;;
esac

# 6. Cultural-semiotic inputs (NON-EXHAUSTIVE list) may be named only in Known limits.
n=$(match_outside_limits "${B}(zodiac|horoscop|astrolog|numerolog|tarot|life path|star sign|signo${E}|aries${E}|taurus${E}|gemini sign|cancer sign|leo${E}|virgo${E}|libra${E}|scorpio${E}|sagittarius${E}|capricorn${E}|aquarius${E}|pisces${E})")
report "cultural input outside Known limits" "$n"

# 7. Unfilled template placeholders (<Subject>, <exact quote>, <slug>, ...).
out=$(grep -nE '<[A-Za-z][A-Za-z -]*>' "$src"); rc=$?
[ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
n=""; [ -n "$out" ] && n=${out%%:*}
report "unfilled template placeholder" "$n"

# 8. Source ids. Every id in the "Source ids" column of the Fidelity table (structure rows of the
#    Fidelity section; S1, S2, ... and ranges S1-S7 / S1–S7) must be an id of the dossier named on the
#    "Dossier: `<path>`" line. Dossier ids are read ONLY from the rows of its source table (the table
#    whose header starts with "| id |"), outside code fences and HTML comments. The path is looked up
#    from the charter's directory upwards. Checks existence of the id, not what the source says.
# shellcheck disable=SC2016  # backticks are literal markdown, not expansions
dossier_line=$(grep -m1 -E '^Dossier: `[^`]+`' "$src"); rc=$?
[ "$rc" -le 1 ] || fail "lint error: grep rc=$rc (dossier pointer)"
dossier_rel=""
if [ -n "$dossier_line" ]; then dossier_rel=${dossier_line#Dossier: \`}; dossier_rel=${dossier_rel%%\`*}; fi
if [ -z "$dossier_rel" ]; then
  fail "missing dossier pointer (Dossier: \`<path>\`)"
else
  dossier=""
  if ! { d=$(dirname "$file") && d=$(cd "$d" && pwd); }; then fail "lint error: cannot resolve charter directory"; d=""; fi
  while [ -n "$d" ]; do
    if [ -f "$d/$dossier_rel" ]; then dossier="$d/$dossier_rel"; break; fi
    [ "$d" = "/" ] && break
    d="$(dirname "$d")" || { fail "lint error: dirname failed"; break; }
  done
  if [ -z "$dossier" ]; then
    fail "dossier not found: $dossier_rel"
  else
    known=$(tr -d '\r' < "$dossier" | awk '
      function fence_run(x,   c, n) { c = substr(x, 1, 1); if (c != "`" && c != "~") return 0
        n = 0; while (substr(x, n + 1, 1) == c) n++; return (n >= 3) ? n : 0 }
      { u = $0; sub(/^ ? ? ?/, "", u); r = fence_run(u)
        if (infence) { if (r && substr(u, 1, 1) == fch && r >= flen) infence = 0; next }
        if (!incomment && r) { infence = 1; fch = substr(u, 1, 1); flen = r; intable = 0; next }
        x = $0; was = incomment; hit = 0
        while (1) {
          if (incomment) { i = index(x, "-->"); if (!i) break; incomment = 0; hit = 1; x = substr(x, i + 3); continue }
          i = index(x, "<!--"); if (!i) break; incomment = 1; hit = 1; x = substr(x, i + 4)
        }
        if (was || hit || incomment) { intable = 0; next }
        if (tolower($0) ~ /^\| *id *\|/) { intable = 1; next }
        if (!intable) next
        if ($0 !~ /^\|/) { intable = 0; next }
        split($0, c, "|"); x = c[2]; gsub(/[ \t]/, "", x)
        if (x ~ /^S[0-9]+$/) print substr(x, 2) + 0
      }') || fail "lint error: awk dossier id check failed"
    max=0; for k in $known; do [ "$k" -gt "$max" ] && max=$k; done
    # Source-id cells of the Fidelity table: the column whose header contains "source".
    cells=$(awk -F'\t' '$7 == 1 && $2 == "fidelity" && $5 ~ /^\|/ { print $6 }' "$tmp/norm" | awk -F'|' '
      col == 0 && tolower($0) ~ /field/ { for (i = 2; i < NF; i++) if (tolower($i) ~ /source/) col = i; next }
      $0 ~ /^\|[ \t:|-]*$/ { next }
      col { print $col }') || fail "lint error: awk fidelity cell check failed"
    # A Source ids cell holds ids, ranges and separators (",", ";", spaces) only: "S 99" or "§3" fails.
    junk=$(printf '%s\n' "$cells" | awk '{ r = $0; gsub(/[Ss][0-9]+[A-Za-z0-9]*( *(-|\342\200\223) *[Ss]?[0-9]+[A-Za-z0-9]*)?/, "", r)
      gsub(/[ \t,;]/, "", r); if (r != "") { c = $0; gsub(/^[ \t]+|[ \t]+$/, "", c); print c; exit } }') \
      || fail "lint error: awk source id cell check failed"
    [ -z "$junk" ] || fail "Source ids cell is not a list of S<n> ids: $junk"
    cited=$(printf '%s\n' "$cells" | awk -v max="$max" -v strict=0 "$SCAN") || fail "lint error: awk cited id check failed"
    # Class basis ids (check 5b), strict: uppercase S<digits> only.
    if [ -n "$class_basis" ]; then
      basis_ids=$(printf '%s\n' "$class_basis" | awk -v max="$max" -v strict=1 "$SCAN") \
        || fail "lint error: awk class basis id check failed"
      for id in $basis_ids; do
        case "$id" in
          bad:*) fail "malformed Class basis source id: ${id#bad:}"; break ;;
          rev:*) fail "reversed Class basis source id range: ${id#rev:}"; break ;;
        esac
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
  # Every escaped string is built first and its status checked: a broken helper is an internal error
  # (exit 1, message on stderr), never a JSON document that says "passed": true.
  if ! { jfile=$(json_str "$file") && jwarn=$(json_str "$WARNING"); }; then echo "lint error: json_str failed" >&2; exit 1; fi
  jfails=""; sep=""
  for f in "${failures[@]+"${failures[@]}"}"; do
    jf=$(json_str "$f") || { echo "lint error: json_str failed" >&2; exit 1; }
    jfails="$jfails$sep\"$jf\""; sep=","
  done
  printf '{"file":"%s","passed":%s,"semantic_validated":false,"warning":"%s","failures":[%s]}\n' \
    "$jfile" "$([ ${#failures[@]} -eq 0 ] && echo true || echo false)" "$jwarn" "$jfails"
else
  if [ ${#failures[@]} -eq 0 ]; then
    echo "PASS $file (deterministic floor only)"
  else
    echo "FAIL $file"
    printf '  - %s\n' "${failures[@]}"
  fi
fi

[ ${#failures[@]} -eq 0 ]
