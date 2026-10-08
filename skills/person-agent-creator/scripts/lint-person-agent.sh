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

# 1. Required sections.
for h in "## Identity boundary" "## Primary mind" "## Secondary minds" "## Known limits" "## Fidelity"; do
  grep -qxF "$h" "$file" || fail "missing section: $h"
done

# 2. Fidelity table header.
grep -qE '^\| *Field *\| *Status *\|' "$file" || fail "missing fidelity table (| Field | Status | ...)"

# 3. First-person identity claims. Subject tokens come from the H1 title, before the em dash.
title=$(grep -m1 '^# ' "$file" | sed -e 's/^# //' -e 's/ —.*//')
tokens=$(printf '%s\n' "$title" | tr -c 'A-Za-zÀ-ÿ\n' ' ' | tr ' ' '\n' | awk 'length($0) >= 3 && $0 != "and" && $0 != "The"')
for t in $tokens; do
  if grep -nEi "(^|[^A-Za-z])(I am|I'm|eu sou)[[:space:]]+$t([^A-Za-z]|$)" "$file" >/dev/null; then
    fail "first-person identity claim with subject token: $t"
  fi
  if grep -nEi "(^|[^A-Za-z])as $t, I([^A-Za-z]|$)" "$file" >/dev/null; then
    fail "first-person voice as subject: $t"
  fi
done

# 4. Blockquote quotes must carry a source marker (" — <source>").
while IFS= read -r line; do
  case "$line" in
    '> "'*|'> “'*)
      printf '%s' "$line" | grep -qE '" — .+|” — .+' || fail "quote without source marker: ${line:0:80}"
      ;;
  esac
done < "$file"

# 5. Clinical / diagnostic vocabulary outside "## Known limits".
clinical='narcissis|psychopath|sociopath|bipolar|autis|asperger|adhd|ocd|personality disorder|diagnos'
hits=$(awk -v re="$clinical" '
  /^## / { in_limits = ($0 == "## Known limits") }
  !in_limits && tolower($0) ~ re { print NR": "$0 }' "$file")
[ -z "$hits" ] || fail "clinical vocabulary outside Known limits (line $(printf '%s' "$hits" | head -1 | cut -d: -f1))"

if [ "$json" -eq 1 ]; then
  printf '{"file":"%s","passed":%s,"failures":[' "$file" "$([ ${#failures[@]} -eq 0 ] && echo true || echo false)"
  sep=""
  for f in "${failures[@]+"${failures[@]}"}"; do
    printf '%s"%s"' "$sep" "$(printf '%s' "$f" | sed 's/"/\\"/g')"
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
