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

# Normalized view, one row per line: NR <TAB> section <TAB> blockquote? <TAB> text <TAB> lowered text
# with sourced quote spans removed. Markdown prefixes are stripped (indent, '>' at any depth, list
# markers, emphasis, backticks) and fence content is kept, so a sentence cannot hide behind them.
# Curly quotes and guillemets become straight double quotes; curly apostrophes become "'".
awk '
  /^[ \t]*(```|~~~)/ { next }
  /^## / { section = substr($0, 4) }
  {
    t = $0
    gsub(/\t/, " ", t)
    sub(/^[ \t]+/, "", t)
    bq = 0
    while (t ~ /^>/) { bq = 1; sub(/^>[ \t]*/, "", t) }
    sub(/^([-*+]|[0-9]+[.)])[ \t]+/, "", t)
    gsub(/[*_`]/, "", t)
    gsub(/\342\200\234|\342\200\235|\302\253|\302\273/, "\"", t)   # curly double quotes, guillemets
    gsub(/\342\200\230|\342\200\231/, "\047", t)                   # curly single quotes
    s = t
    if (s ~ /"[^"]*" *(\342\200\224|--) *[A-Za-z0-9]/) gsub(/"[^"]*"/, "\"\"", s)
    print NR "\t" section "\t" bq "\t" t "\t" tolower(s)
  }' "$file" > "$tmp/norm" || { fail "lint error: awk normalization failed"; }

# match <regex> <column> [grep-flags] — first matching line number, or empty. A grep error
# (rc >= 2, e.g. a regex the platform cannot compile) is a FAIL, never "no match".
match() {
  local re="$1" col="$2" out rc
  out=$(cut -f"$col" "$tmp/norm" | grep -nE -- "$re")
  rc=$?
  if [ "$rc" -ge 2 ]; then echo "ERR$rc"; return; fi
  [ -n "$out" ] && cut -f1 "$tmp/norm" | sed -n "$(printf '%s' "$out" | head -1 | cut -d: -f1)p"
}
# match_outside_limits <regex> — same, skipping rows whose section is "Known limits".
match_outside_limits() {
  local re="$1" out rc
  out=$(awk -F'\t' '$2 != "Known limits" { print $1 "\t" $5 }' "$tmp/norm" | grep -E -- "$re")
  rc=$?
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

# 1. Required sections.
for h in "## Identity boundary" "## Primary mind" "## Secondary minds" "## Known limits" "## Fidelity"; do
  grep -qxF -- "$h" "$file"; rc=$?
  [ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
  [ "$rc" -eq 0 ] || fail "missing section: $h"
done

# 2. Fidelity table header.
grep -qE '^\| *Field *\| *Status *\|' "$file"; rc=$?
[ "$rc" -le 1 ] || fail "lint error: grep rc=$rc"
[ "$rc" -eq 0 ] || fail "missing fidelity table (| Field | Status | ...)"

# 3. First person, role-play and endorsement — bounded pattern list (lowercased text, sourced
#    quote spans removed, every section and every markdown prefix). Not a semantic check.
B='(^|[^a-z])'
E='([^a-z]|$)'
n=$(match "${B}(i am|i'm|my name is|eu sou|meu nome é|me chamo)${E}" 5)
report "first-person identity claim" "$n"
n=$(match "${B}(as|speaking as|como) [^,.]+(,| here,?) (i|we|eu|nós)${E}" 5)
report "first-person voice as a named person" "$n"
n=$(match "${B}i (think|believe|feel|would|will|want)${E}" 5)
report "first-person opinion" "$n"
n=$(match "${B}(i|we|eu|nós)(, [^,]+,)? (hereby |fully |strongly |officially )?(approve|endorse|authori[sz]e|vouch for|sign off|certify|back|support|aprovo|endosso|autorizo|apoio|assino)${E}" 5)
report "first-person approval/endorsement" "$n"
n=$(match '(^|[^A-Za-z])[Yy]ou are (now )?[A-Z]|answer as (him|her|them)' 4)
report "second-person role-play instruction" "$n"

# 4. A blockquote line that contains a quotation needs a source marker (" — <source>" or " -- "),
#    on the same line or on the next blockquote line. Checks presence only: whether the source id
#    exists in the dossier is not verified here.
n=$(awk -F'\t' '
  function sourced(x) { return x ~ /(\342\200\224|--) *[A-Za-z0-9]/ }
  { bq[NR] = $3; txt[NR] = $4; ln[NR] = $1 }
  END {
    for (i = 1; i <= NR; i++)
      if (bq[i] == 1 && txt[i] ~ /"/ && !sourced(txt[i]) && !(bq[i+1] == 1 && txt[i+1] ~ /^(\342\200\224|--) *[A-Za-z0-9]/)) {
        print ln[i]; exit
      }
  }' "$tmp/norm") || fail "lint error: awk quote check failed"
report "quote without source marker" "$n"

# 5. Clinical / diagnostic vocabulary outside "## Known limits" (NON-EXHAUSTIVE list).
n=$(match_outside_limits "${B}(narcissis|psychopath|sociopath|bipolar|autis|asperger|adhd${E}|ocd${E}|personality disorder|psychotic|psychosis|manic${E}|megaloman|schizo|paranoi|histrionic|borderline personality|diagnosed with|diagnosis of|mentally ill|on the spectrum|obsessive-compulsive|neurodivergent)")
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
