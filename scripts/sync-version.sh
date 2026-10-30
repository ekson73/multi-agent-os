#!/usr/bin/env bash
# Sync the version from .claude-plugin/plugin.json (SSOT) into
# README.md, CLAUDE.md, package.json and packaging/opencode-maos/package.json.
#
#   scripts/sync-version.sh          write the version into the files
#   scripts/sync-version.sh --check  only compare; exit 1 on mismatch (CI)
#
# Values are compared, not bytes, so JSON re-encoding never counts as drift.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

MODE="${1:-sync}"
V="$(jq -r '.version' .claude-plugin/plugin.json)"
OC=packaging/opencode-maos/package.json
bad=0

check() { # name actual
  if [ "$2" != "$V" ]; then echo "::error::$1 has '$2', plugin.json has '$V'"; bad=1; fi
}

if [ "$MODE" = "--check" ]; then
  check package.json "$(jq -r '.version' package.json)"
  [ -f "$OC" ] && check "$OC" "$(jq -r '.version' "$OC")"
  check "README.md badge" "$(grep -oE 'Version-[0-9]+\.[0-9]+\.[0-9]+-blue' README.md | head -1 | sed -E 's/Version-(.*)-blue/\1/')"
  for f in README.md CLAUDE.md; do
    grep -qE 'Multi-Agent OS v[0-9]+\.[0-9]+\.[0-9]+' "$f" || check "$f footer" ""
    for got in $(grep -oE 'Multi-Agent OS v[0-9]+\.[0-9]+\.[0-9]+' "$f" | sed 's/.* v//' | sort -u); do
      check "$f footer" "$got"
    done
  done
  if [ "$bad" = 1 ]; then
    echo "Version drift. Fix: run scripts/sync-version.sh on a branch and open a PR (main is PR-only)."
    exit 1
  fi
  echo "OK: all versions = $V"
  exit 0
fi

# sync mode: portable in-place edit (GNU and BSD sed)
sedi() { sed -E "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"; }
sedi "s/Version-[0-9]+\.[0-9]+\.[0-9]+-blue/Version-${V}-blue/g" README.md
sedi "s/Multi-Agent OS v[0-9]+\.[0-9]+\.[0-9]+/Multi-Agent OS v${V}/g" README.md
sedi "s/Multi-Agent OS v[0-9]+\.[0-9]+\.[0-9]+/Multi-Agent OS v${V}/g" CLAUDE.md
for j in package.json "$OC"; do
  [ -f "$j" ] || continue
  jq --arg v "$V" '.version = $v' "$j" > "$j.tmp" && mv "$j.tmp" "$j"
done
echo "Synced to $V"
