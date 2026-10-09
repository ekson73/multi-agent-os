#!/usr/bin/env bash
# lint-person-agent.sh — deterministic gate for person-agent charters.
# Usage: lint-person-agent.sh <agent.md> [--json]
# Exit: 0 pass · 1 one or more checks failed · 2 usage / unreadable input.
set -uo pipefail

json=0
file=""
for arg in "$@"; do
  case "$arg" in
    --json) json=1 ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) file="$arg" ;;
  esac
done

if [ -z "$file" ] || [ ! -r "$file" ]; then
  echo "usage: lint-person-agent.sh <agent.md> [--json]" >&2
  exit 2
fi

failures=()
fail() { failures+=("$1"); }

# Prose lines: every line outside code fences and outside blockquotes, prefixed with
# "<line>|<section>|". Verbatim quotes live in blockquotes and are checked separately (4).
prose=$(awk '
  /^[[:space:]]*```/ { fence = !fence; next }
  fence { next }
  /^## / { section = substr($0, 4) }
  /^[[:space:]]*>/ { next }
  { print NR "|" section "|" $0 }' "$file")

# 1. Required sections.
for h in "## Identity boundary" "## Primary mind" "## Secondary minds" "## Known limits" "## Fidelity"; do
  grep -qxF "$h" "$file" || fail "missing section: $h"
done

# 2. Fidelity table header.
grep -qE '^\| *Field *\| *Status *\|' "$file" || fail "missing fidelity table (| Field | Status | ...)"

# 3. First-person identity, voice or endorsement — in EVERY prose section (collective charters
#    included). Name-agnostic: any first-person self-identification followed by a capitalized name
#    fails, so aliases of collective members (e.g. "Dario" under "Amodei Siblings") are covered.
first_line() { printf '%s\n' "$prose" | grep -E "$1" | head -1 | cut -d'|' -f1; }
# shellcheck disable=SC1112 # the curly apostrophe (I’m) is intentional
ident='(^|[^A-Za-z])([Ii] am|[Ii]'"'"'m|[Ii]’m|[Mm]y name is|[Ee]u sou|[Mm]eu nome é|[Mm]e chamo|[Ss]ou [oa]) +(o |a |the )?[A-ZÀ-Ý]'
voice='(^|[^A-Za-z])([Aa]s|[Ss]peaking as|[Cc]omo) [A-ZÀ-Ý][[:alpha:]]+(,| here)? (I|eu)([^A-Za-z]|$)'
endorse='(^|[^A-Za-z])(I|[Ww]e|[Ee]u|[Nn]ós) (hereby )?(approve|endorse|authori[sz]e|vouch for|sign off|certify|back|support|aprovo|endosso|autorizo|apoio|assino)([^A-Za-z]|$)'
n=$(first_line "$ident");   [ -z "$n" ] || fail "first-person identity claim (line $n)"
n=$(first_line "$voice");   [ -z "$n" ] || fail "first-person voice as a named person (line $n)"
n=$(first_line "$endorse"); [ -z "$n" ] || fail "first-person approval/endorsement (line $n)"

# 4. Blockquote quotes must carry a source marker (" — <source>"), whatever the quoting style
#    (leading spaces, no space after '>', bold/italic wrapper, straight or curly quotes).
while IFS= read -r line; do
  if printf '%s' "$line" | grep -qE '^[[:space:]]*>[[:space:]]*[*_]*["“]'; then
    printf '%s' "$line" | grep -qE '["”][*_]* +— +[^[:space:]]' || fail "quote without source marker: ${line:0:80}"
  fi
done < "$file"

# 5. Clinical / diagnostic vocabulary outside "## Known limits".
clinical='narcissis|psychopath|sociopath|bipolar|autis|asperger|adhd|(^|[^a-z])ocd([^a-z]|$)|personality disorder|psychotic|psychosis|(^|[^a-z])manic([^a-z]|$)|megaloman|schizo|paranoi|histrionic|borderline personality|diagnosed with|diagnosis of'
n=$(printf '%s\n' "$prose" | awk -F'|' -v re="$clinical" '$2 != "Known limits" && tolower($0) ~ re { print $1; exit }')
[ -z "$n" ] || fail "clinical vocabulary outside Known limits (line $n)"

# 6. Cultural-semiotic inputs (zodiac, numerology, ...) are non-evidential: they may be named only in
#    Known limits, never inside a section that sets traits or behavior.
cultural='zodiac|horoscop|astrolog|numerolog|life path|star sign|signo|aries|taurus|gemini sign|scorpio|sagittarius|capricorn|aquarius|pisces|virgo|libra'
n=$(printf '%s\n' "$prose" | awk -F'|' -v re="$cultural" '$2 != "Known limits" && tolower($0) ~ re { print $1; exit }')
[ -z "$n" ] || fail "cultural input outside Known limits (line $n)"

# 7. Unfilled template placeholders (<Subject>, <exact quote>, <slug>, ...).
n=$(grep -nE '<[A-Za-z][A-Za-z -]*>' "$file" | head -1 | cut -d: -f1)
[ -z "$n" ] || fail "unfilled template placeholder (line $n)"

json_str() { # JSON string escape: backslash, quote, control characters.
  printf '%s' "$1" | awk 'BEGIN { ORS = "" } {
    gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, "\\r")
    if (NR > 1) print "\\n"; print }'
}

if [ "$json" -eq 1 ]; then
  printf '{"file":"%s","passed":%s,"failures":[' "$(json_str "$file")" "$([ ${#failures[@]} -eq 0 ] && echo true || echo false)"
  sep=""
  for f in "${failures[@]+"${failures[@]}"}"; do
    printf '%s"%s"' "$sep" "$(json_str "$f")"
    sep=","
  done
  printf ']}\n'
else
  if [ ${#failures[@]} -eq 0 ]; then
    echo "PASS $file"
  else
    echo "FAIL $file"
    printf '  - %s\n' "${failures[@]}"
  fi
fi

[ ${#failures[@]} -eq 0 ]
